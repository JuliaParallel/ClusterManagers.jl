# ClusterManager for Slurm

export SlurmManager, addprocs_slurm

import Logging.@warn

struct SlurmManager <: ClusterManager
    np::Integer
    retry_delays
end

struct SlurmException <: Exception
    msg
end

function launch(manager::SlurmManager, params::Dict, instances_arr::Array,
                c::Condition)
    let
        msg = "The Slurm functionality in the `ClusterManagers.jl` package is deprecated " *
              "(including `ClusterManagers.addprocs_slurm` and `ClusterManagers.SlurmManager`). " *
              "It will be removed from ClusterManagers.jl in a future release. " *
              "We recommend migrating to the " *
              "[https://github.com/JuliaParallel/SlurmClusterManager.jl](https://github.com/JuliaParallel/SlurmClusterManager.jl) " *
              "package instead."
        Base.depwarn(msg, :SlurmManager; force = true)
    end
    try
        exehome = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]

        stdkeys = keys(Distributed.default_addprocs_params())

        p = filter(x->(!(x[1] in stdkeys) && x[1] != :job_file_loc), params)

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

        # Check for given output file name
        jobname = "julia-$(getpid())"
        has_output_name = ("-o" in srunargs) | ("--output" in srunargs)
        if has_output_name
            loc = findfirst(x-> x == "-o" || x == "--output", srunargs)
            job_output_name = srunargs[loc+1]
            job_output_template = joinpath(job_file_loc, job_output_name)
            srunargs[loc+1] = job_output_template
        else
            job_output_name = "$(jobname)-$(trunc(Int, Base.time() * 10))"
            make_job_output_path(task_num) = joinpath(job_file_loc, "$(job_output_name)-$(task_num).out")
            job_output_template = make_job_output_path("%4t")
            push!(srunargs, "-o", job_output_template)
        end

        np = manager.np
        srun_cmd = `srun -J $jobname -n $np -D $exehome $(srunargs) $exename $exeflags $(worker_arg())`

        @info "Starting SLURM job $jobname: $srun_cmd"
        srun_proc = open(srun_cmd)

        slurm_spec_regex = r"([\w]+):([\d]+)#(\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3})"
        could_not_connect_regex = r"could not connect"
        exiting_regex = r"exiting."
        retry_delays = manager.retry_delays

        t_start = time()
        t_waited = round(Int, time() - t_start)
        for i = 0:np - 1
            slurm_spec_match::Union{RegexMatch,Nothing} = nothing
            worker_errors = String[]
            if has_output_name
                fn = job_output_template
            else
                fn = make_job_output_path(lpad(i, 4, "0"))
            end
            for retry_delay in push!(collect(retry_delays), 0)
                t_waited = round(Int, time() - t_start)

                # Wait for output log to be created and populated, then parse

                if isfile(fn)
                    if filesize(fn) > 0
                        open(fn) do f
                            # Due to error and warning messages, the specification
                            # may not appear on the file's first line
                            for line in eachline(f)
                                re_match = match(slurm_spec_regex, line)
                                if !isnothing(re_match)
                                    slurm_spec_match = re_match
                                end
                                for expr in [could_not_connect_regex, exiting_regex]
                                    if !isnothing(match(expr, line))
                                        slurm_spec_match = nothing
                                        push!(worker_errors, line)
                                    end
                                end
                            end
                        end
                    end
                    if !isempty(worker_errors) || !isnothing(slurm_spec_match)
                        break   # break if error or specification found
                    else
                        @info "Worker $i (after $t_waited s): Output file found, but no connection details yet"
                    end
                else
                    @info "Worker $i (after $t_waited s): No output file \"$fn\" yet"
                end

                # Sleep for some time to limit resource usage while waiting for the job to start
                sleep(retry_delay)
            end

            if !isempty(worker_errors)
                throw(SlurmException("Worker $i failed after $t_waited s: $(join(worker_errors, " "))"))
            elseif isnothing(slurm_spec_match)
                throw(SlurmException("Timeout after $t_waited s while waiting for worker $i to get ready."))
            end

            config = WorkerConfig()
            config.port = parse(Int, slurm_spec_match[2])
            config.host = strip(slurm_spec_match[3])
            @info "Worker $i ready after $t_waited s on host $(config.host), port $(config.port)"
            # Keep a reference to the proc, so it's properly closed once
            # the last worker exits.
            config.userdata = srun_proc
            push!(instances_arr, config)
            notify(c)
        end
    catch e
        @error "Error launching Slurm job"
        rethrow(e)
    end
end

function manage(manager::SlurmManager, id::Integer, config::WorkerConfig,
                op::Symbol)
    # This function needs to exist, but so far we don't do anything
end

SlurmManager(np::Integer) = SlurmManager(np, ExponentialBackOff(n=10, first_delay=1,
                                                                max_delay=512, factor=2))

"""
Launch `np` workers on a cluster managed by slurm. `retry_delays` is a vector of
numbers specifying in seconds how long to repeatedly wait for a worker to start.
Defaults to an exponential backoff.

# Examples

```
addprocs_slurm(100; retry_delays=Iterators.repeated(0.1))
```
"""
addprocs_slurm(np::Integer;
               retry_delays=ExponentialBackOff(n=10, first_delay=1,
                                               max_delay=512, factor=2),
               kwargs...) = addprocs(SlurmManager(np, retry_delays); kwargs...)
