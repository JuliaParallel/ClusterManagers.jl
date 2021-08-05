export LSFManager, addprocs_lsf

struct LSFManager <: ClusterManager
    np::Integer
    bsub_flags::Cmd
    bpeek_flags::Cmd
    ssh_cmd::Cmd
    bsub_cmd::Cmd
    bpeek_cmd::Cmd
    retry_delays
    throttle::Integer
end

struct LSFException <: Exception
    msg
end

function lsf_bpeek(manager::LSFManager, jobid, iarray)
    port_host_regex = r"julia_worker:([0-9]+)#([0-9.]+)"
    stream = Base.BufferStream()
    mark(stream)    # so that we can reset to beginning after ensuring process started

    streamer_cmd = pipeline(`$(manager.ssh_cmd) $(manager.bpeek_cmd) $(manager.bpeek_flags) $(jobid)\[$iarray\]`; stdout=stream, stderr=stream)
    backoff = manager.retry_delays
    delay, backoff_state = iterate(backoff)
    streamer_proc = run(streamer_cmd; wait=false)
    worker_started = false

    while !worker_started
        bytestr = readline(stream)
        if !isnothing(match(port_host_regex, bytestr))
            # process started, reset to marked position and hand over to Distributed module
            reset(stream)
            worker_started = true
        else
            if occursin("Not yet started", bytestr)
                # reset to marked position, bpeek process would have stopped
                wait(streamer_proc)
                mark(stream)

                # retry with backoff if within retry limit
                if backoff_state[1] == 0
                    close(stream)
                    throw(LSFException(bytestr))
                end
                sleep(delay)
                delay, backoff_state = iterate(backoff, backoff_state)
                streamer_proc = run(streamer_cmd; wait=false)
            else
                # unknown response from worker process
                close(stream)
                throw(LSFException(bytestr))
            end
        end
    end

    return stream
end

function lsf_launch_and_monitor(manager::LSFManager, launched, c, jobid, iarray)
    config = WorkerConfig()
    config.io = lsf_bpeek(manager, jobid, iarray)
    config.userdata = `$jobid\[$iarray\]`

    push!(launched, config)
    notify(c)
end

function launch(manager::LSFManager, params::Dict, launched::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        np = manager.np

        jobname = `julia-$(getpid())`

        cmd = `$exename $exeflags $(worker_arg())`
        bsub_cmd = `$(manager.ssh_cmd) $(manager.bsub_cmd) $(manager.bsub_flags) -cwd $dir -J $(jobname)\[1-$np\] "$cmd"`

        line = open(readline, bsub_cmd)
        m = match(r"Job <([0-9]+)> is submitted", line)
        jobid = m.captures[1]

        asyncmap((i)->lsf_launch_and_monitor(manager, launched, c, jobid, i),
                 1:np;
                 ntasks=manager.throttle)
 
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
                 bpeek_flags::Cmd=`-f`,
                 ssh_cmd::Cmd=``,
                 bsub_cmd::Cmd=`bsub`,
                 bpeek_cmd::Cmd=`bpeek`,
                 retry_delays=ExponentialBackOff(n=10,
                                                 first_delay=1, max_delay=512,
                                                 factor=2),
                 throttle::Integer=np,
                 params...) =

Launch `np` workers on a cluster managed by IBM's Platform Load Sharing
Facility.  `bsub_flags` can be used to pass flags to `bsub` that are specific
to your cluster or workflow needs.  `ssh_cmd` can be used to launch workers
from other than the cluster head node (e.g. your personal workstation).
`retry_delays` is a vector of numbers specifying in seconds how long to
repeatedly wait for a worker to start.  `throttle` specifies how many workers
to launch at once. Having `-f` in bpeek flags (which is the default) will let
stdout of workers to be displayed on master too.

# Examples

```
addprocs_lsf(1000; ssh_cmd=`ssh login`, throttle=10)
```
"""
addprocs_lsf(np::Integer;
             bsub_flags::Cmd=``,
             bpeek_flags::Cmd=`-f`,
             ssh_cmd::Cmd=``,
             bsub_cmd::Cmd=`bsub`,
             bpeek_cmd::Cmd=`bpeek`,
             retry_delays=ExponentialBackOff(n=10,
                                             first_delay=1, max_delay=512,
                                             factor=2),
             throttle::Integer=np,
             params...) =
        addprocs(LSFManager(np, bsub_flags, bpeek_flags, ssh_cmd, bsub_cmd, bpeek_cmd, retry_delays, throttle); params...)
