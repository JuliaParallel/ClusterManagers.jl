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

function parse_host_port(stream, port_host_regex = r"julia_worker:([0-9]+)#([0-9.]+)")
    bytestr = readline(stream)
    conn_info_match = match(port_host_regex, bytestr)
    if !isnothing(conn_info_match)
        host = conn_info_match.captures[2]
        port = parse(Int, conn_info_match.captures[1])
        @debug("lsf worker listening", connect_info=bytestr, host, port)

        return true, bytestr, host, port
    end
    return false, bytestr, nothing, nothing
end

function lsf_bpeek(manager::LSFManager, jobid, iarray)
    stream = Base.BufferStream()
    mark(stream)    # so that we can reset to beginning after ensuring process started

    streamer_cmd = `$(manager.ssh_cmd) $(manager.bpeek_cmd) $(manager.bpeek_flags) $(jobid)\[$iarray\]`
    retry_delays = manager.retry_delays
    streamer_proc = run(pipeline(streamer_cmd; stdout=stream, stderr=stream); wait=false)

    # Try once before retry loop in case user supplied an empty retry_delays iterator
    worker_started, bytestr, host, port = parse_host_port(stream)
    worker_started && return stream, host, port

    for retry_delay in retry_delays
        # isempty is for the case when -f flag is not used to handle the case when
        # the << output from ... >> message is printed but the julia worker has not
        # yet printed the ip and port nr
        if isempty(bytestr) || occursin("Not yet started", bytestr)
            # bpeek process would have stopped
            # stream starts spewing out empty strings after this (in julia != 1.6)
            # instead of trying to handle that we just close it and open a new stream
            wait(streamer_proc)
            close(stream)
            stream = Base.BufferStream()

            # Try bpeeking again after the retry delay
            sleep(retry_delay)
            streamer_proc = run(pipeline(streamer_cmd; stdout=stream, stderr=stream); wait=false)
        elseif occursin("<< output from stdout >>", bytestr) || occursin("<< output from stderr >>", bytestr)
            # ignore this bpeek output decoration and continue to read the next line
            mark(stream)
        else
            # unknown response from worker process
            close(stream)
            throw(LSFException(bytestr))
        end

        worker_started, bytestr, host, port = parse_host_port(stream)
        worker_started && break
    end

    if !worker_started
        close(stream)
        throw(LSFException(bytestr))
    end

    # process started, reset to marked position and hand over to Distributed module
    reset(stream)

    return stream, host, port
end

function lsf_launch_and_monitor(manager::LSFManager, launched, c, jobid, iarray)
    config = WorkerConfig()
    io, host, port = lsf_bpeek(manager, jobid, iarray)
    config.io = io
    config.host = host
    config.port = port
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
