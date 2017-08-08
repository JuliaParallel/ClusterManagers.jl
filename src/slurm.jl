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

        stdkeys = keys(Base.Distributed.default_addprocs_params())
        p = filter((x,y) -> !(x in stdkeys), params)

        srunargs = []
        for k in keys(p)
            if length(string(k)) == 1
                push!(srunargs, "-$k")
                val = p[k]
                if length(val) > 0
                    push!(srunargs, "$(p[k])")
                end
            else
                k2 = replace(string(k), "_", "-")
                val = p[k]
                if length(val) > 0
                    push!(srunargs, "--$(k2)=$(p[k])")
                else
                    push!(srunargs, "--$(k2)")
                end
            end
        end

        # cleanup old files
        map(rm, filter(t -> ismatch(r"job.*\.out", t), readdir(exehome)))

        np = manager.np
        jobname = "julia-$(getpid())"
        srun_cmd = `srun -J $jobname -n $np -o "job%4t.out" -D $exehome $(srunargs) $exename $exeflags -e 'Base.start_worker(readline())'`
        srun_stdin, srun_proc = open(srun_cmd, "w")
        println(srun_stdin, Base.Distributed.cluster_cookie())
        for i = 0:np - 1
            print("connecting to worker $(i + 1) out of $np\r")
            local w=[]
            fn = "$exehome/job$(lpad(i, 4, "0")).out"
            t0 = time()
            while true
                if time() > t0 + 60 + np
                    warn("dropping worker: file not created in $(60 + np) seconds")
                    break
                end
                sleep(0.001)
                if isfile(fn) && filesize(fn) > 0
                    w = open(fn) do f
                        return split(split(readline(f), ":")[2], "#")
                    end
                    break
                end
            end
            if length(w) > 0
                config = WorkerConfig()
                config.port = parse(Int, w[1])
                config.host = strip(w[2])
                # Keep a reference to the proc, so it's properly closed once
                # the last worker exits.
                config.userdata = srun_proc
                push!(instances_arr, config)
                notify(c)
            end
        end
    catch e
        println("Error launching Slurm job:")
        rethrow(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig,
                op::Symbol)
    # This function needs to exist, but so far we don't do anything
end

addprocs_slurm(np::Integer; kwargs...) = addprocs(SlurmManager(np);
                                                  kwargs...)
