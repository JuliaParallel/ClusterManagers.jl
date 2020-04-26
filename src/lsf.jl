export LSFManager, addprocs_lsf

struct LSFManager <: ClusterManager
    np::Integer
    bsub_flags::Cmd
    ssh_cmd::Cmd
    retry_delays
end

struct LSFException <: Exception
    msg
end

function bpeek(manager, jobid, iarray)
    old_stderr = stderr
    rd,_ = redirect_stderr()
    try
        io = open(`$(manager.ssh_cmd) bpeek $(jobid)\[$iarray\]`)
        success(io) || throw(LSFException(String(readavailable(rd))))
        return io
    finally
        redirect_stderr(old_stderr)
    end
end

function launch(manager::LSFManager, params::Dict, launched::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        np = manager.np

        jobname = `julia-$(getpid())`

        cmd = `$exename $exeflags $(worker_arg())`
        bsub_cmd = `$(manager.ssh_cmd) bsub $(manager.bsub_flags) -cwd $dir -J $(jobname)\[1-$np\] "$cmd"`

        line = open(readline, bsub_cmd)
        m = match(r"Job <([0-9]+)> is submitted", line)
        jobid = m.captures[1]

        port_host_regex = r"julia_worker:([0-9]+)#([0-9.]+)"
        @sync for i in 1:np
            @async begin
                config = WorkerConfig()

                io = retry(()->bpeek(manager, jobid, i),
                           delays=manager.retry_delays,
                           check=(s,e)->occursin("Not yet started", e.msg))()
                for line in eachline(io)
                    m = match(port_host_regex, line)
                    isnothing(m) && continue
                    config.host = m.captures[2]
                    config.port = parse(Int, m.captures[1])
                    break
                end
                config.userdata = `$jobid\[$i\]`

                push!(launched, config)
                notify(c)
@info i
            end
        end
 
    catch e
        println("Error launching workers")
        println(e)
    end
end

manage(manager::LSFManager, id::Int64, config::WorkerConfig, op::Symbol) = nothing

kill(manager::LSFManager, id::Int64, config::WorkerConfig) = remote_do(exit, id)

"""
    addprocs_lsf(np::Integer;
                 bsub_flags::Cmd=``,
                 ssh_cmd::Cmd=``,
                 retry_delays=ExponentialBackOff(n=10,
                                                 first_delay=1, max_delay=512,
                                                 factor=2),
                 params...) =

Launch `np` workers on a cluster managed by IBM's Platform Load Sharing
Facility.  `bsub_flags` can be used to pass flags to `bsub` that are specific
to your cluster or workflow needs.  `ssh_cmd` can be used to launch workers
from other than the cluster head node (e.g. your personal workstation).
`retry_delays` is a vector of numbers specifying in seconds how long to
repeatedly wait for a worker to start.

# Examples

```
addprocs_lsf(1000; ssh_cmd=`ssh login`)
```
"""
addprocs_lsf(np::Integer;
             bsub_flags::Cmd=``,
             ssh_cmd::Cmd=``,
             retry_delays=ExponentialBackOff(n=10,
                                             first_delay=1, max_delay=512,
                                             factor=2),
             params...) =
        addprocs(LSFManager(np, bsub_flags, ssh_cmd, retry_delays); params...)
