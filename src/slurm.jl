# ClusterManager for Slurm

export SlurmManager, addprocs_slurm

import Logging.@warn

struct SlurmManager <: ClusterManager
    np::Integer
end

function launch(manager::SlurmManager, params::Dict, instances_arr::Array,
                c::Condition)
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        stdkeys = keys(Distributed.default_addprocs_params())

	println(stdkeys)
        p = filter(x->(!(x[1] in stdkeys) && x[1] != :job_file_loc), params)
	println(p)



        srunargs = []
        for k in keys(p)
            if length(string(k)) == 1
                push!(srunargs, "-$k")
                val = p[k]
                if length(val) > 0
                    push!(srunargs, "$(p[k])")
                end
            else
                k2 = replace(string(k), "_"=>"-")
                val = p[k]
                if length(val) > 0
                    push!(srunargs, "--$(k2)=$(p[k])")
                else
                    push!(srunargs, "--$(k2)")
                end
            end
        end

        # Get job file location from parameter dictionary.
        job_file_loc = joinpath(exehome, get(params, :job_file_loc, "."))

        # Make directory if not already made.
        if !isdir(job_file_loc)
            mkdir(job_file_loc)
        end

        println("removing old files")
        # cleanup old files
	map(f->rm(joinpath(job_file_loc, f)), filter(t -> occursin(r"job(.*?).out", t), readdir(job_file_loc)))
        println("removing old Setting up srun commands")

        np = manager.np
        jobname = "julia-$(getpid())"
        job_output_name = "$(jobname)-$(trunc(Int, Base.time() * 10))"
        make_job_output_path(task_num) = joinpath(job_file_loc, "$(job_output_name)-$(task_num).out")
        job_output_template = make_job_output_path("%4t")
        srun_cmd = `srun -J $jobname -n $np -o "$(job_output_template)" -D $exehome $(srunargs) $exename $exeflags $(worker_arg())`
        srun_proc = open(srun_cmd)
        slurm_spec_regex = r"([\w]+):([\d]+)#(\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3})"
        for i = 0:np - 1
            println("connecting to worker $(i + 1) out of $np")
            local slurm_spec_match = nothing
            fn = make_job_output_path(lpad(i, 4, "0"))
            t0 = time()
            while true
                if isfile(fn) && filesize(fn) > 0
                    slurm_spec_match = open(fn) do f
                        for line in eachline(f)
                            re_match = match(slurm_spec_regex, line)
                            if re_match !== nothing
                                return re_match
                            end
                        end
                    end
                    if slurm_spec_match !== nothing
                        break
                    end
                end
            end
            config = WorkerConfig()
            config.port = parse(Int, slurm_spec_match[2])
            config.host = strip(slurm_spec_match[3])
            # Keep a reference to the proc, so it's properly closed once
            # the last worker exits.
            config.userdata = srun_proc
            push!(instances_arr, config)
            notify(c)
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

addprocs_slurm(np::Integer; kwargs...) = addprocs(SlurmManager(np); kwargs...)
