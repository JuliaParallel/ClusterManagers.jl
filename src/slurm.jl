# ClusterManager for Slurm

export SlurmManager, addprocs_slurm

immutable SlurmManager <: ClusterManager
    np::Integer
end

function launch(manager::SlurmManager, params::Dict, instances_arr::Array,
                c::Condition)
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]
        p = copy(params)
        p = delete!(p, :dir)
        p = delete!(p, :exename)
        p = delete!(p, :exeflags)
        srunargs = []
        for k in keys(p)
            if length(string(k)) == 1
                push!(srunargs, "-$k")
                push!(srunargs, "$(p[k])")
            else
                push!(srunargs,"--$(k)=$(p[k])")
            end
        end
        np = manager.np
        jobname = "julia-$(getpid())"
        srun_cmd = `srun -J $jobname -n $np -D $exehome $(srunargs) $exename $exeflags --worker`
        srun_cmd.detach = true
        out, _ = open(srun_cmd)
        for i = 1:np
            w = split(split(readline(out), ":")[2], "#")
            config = WorkerConfig()
            config.port = int(w[1])
            config.host = strip(w[2])
            push!(instances_arr, config)
            notify(c)
        end
    catch e
        println("Error launching Slurm job:")
        println(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig,
                op::Symbol)
    # This function needs to exist, but so far we don't do anything
end

addprocs_slurm(np::Integer; kwargs...) = addprocs(SlurmManager(np);
                                                  kwargs...)
