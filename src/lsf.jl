export LSFManager, addprocs_lsf

struct LSFManager <: ClusterManager
    np::Integer
    bsub_flags::Cmd
    ssh_cmd::Cmd
end

function launch(manager::LSFManager, params::Dict, launched::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        np = manager.np

        jobname = `julia-$(getpid())`

        cmd = `$exename $exeflags $(worker_arg())`
        bsub_cmd = `$(manager.ssh_cmd) bsub -I $(manager.bsub_flags) -cwd $dir -J $jobname "$cmd"`

        stream_proc = [open(bsub_cmd) for i in 1:np]

        for i in 1:np
            config = WorkerConfig()
            config.io = stream_proc[i]

            line = readline(config.io)
            m = match(r"Job <([0-9]+)> is submitted", line)
            config.userdata = m.captures[1]

            push!(launched, config)
            notify(c)
        end
 
    catch e
        println("Error launching workers")
        println(e)
    end
end

manage(manager::LSFManager, id::Int64, config::WorkerConfig, op::Symbol) = nothing

function kill(manager::LSFManager, id::Int64, config::WorkerConfig)
    if manager.ssh_cmd==``
        kill(config.io)
    else
        run(`$(manager.ssh_cmd) bkill $(config.userdata)`)
    end
end

"""
    addprocs_lsf(np::Integer; bsub_flags::Cmd=``, ssh_cmd::Cmd=``, params...)

Launch workers on a cluster managed by IBM's Platform Load Sharing Facility.
`np` specifies the number of workers, `bsub_flags` can be used to pass flags
to `bsub` that are specific to your cluster or workflow needs, and `ssh_cmd` can
be used to launch workers from other than the cluster head node (e.g. your personal
workstation).

# Examples

```
addprocs_lsf(1000; ssh_cmd=`ssh login`)
```
"""
addprocs_lsf(np::Integer; bsub_flags::Cmd=``, ssh_cmd::Cmd=``, params...) =
        addprocs(LSFManager(np, bsub_flags, ssh_cmd); params...)
