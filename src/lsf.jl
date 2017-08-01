export LSFManager, addprocs_lsf

struct LSFManager <: ClusterManager
    np::Integer
    bsub_flags::Cmd
end

function launch(manager::LSFManager, params::Dict, launched::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        np = manager.np

        jobname = `julia-$(getpid())`

        cmd = `$exename $exeflags $(worker_arg())`
        bsub_cmd = `bsub -I $(manager.bsub_flags) -cwd $dir -J $jobname "$cmd"`

        stream_proc = [open(bsub_cmd) for i in 1:np]

        for i in 1:np
            config = WorkerConfig()
            config.io = stream_proc[i]
            push!(launched, config)
            notify(c)
        end
 
    catch e
        println("Error launching workers")
        println(e)
    end
end

manage(manager::LSFManager, id::Int64, config::WorkerConfig, op::Symbol) = nothing

kill(manager::LSFManager, id::Int64, config::WorkerConfig) = kill(config.io)

addprocs_lsf(np::Integer, bsub_flags::Cmd=``; params...) =
        addprocs(LSFManager(np, bsub_flags); params...)
