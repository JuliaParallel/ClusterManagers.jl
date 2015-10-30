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
        p = delete!(p, :topology)

        capture_stdout = get(p, :capture_stdout, true)
        p = delete!(p, :capture_stdout)

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

        stdout_ios = Channel(typemax(Int))
        port = 0
        if capture_stdout
            # Start a listener for capturing stdout's from the workers
            (port, server) = listenany(11000)
            @schedule begin
                nw = np
                while nw > 0
                    sock = accept(server)
                    put!(stdout_ios, sock)
                    nw = nw - 1
                end
            end
        end

        # cleanup old files
        map(rm, filter(t -> ismatch(r"job.*\.out", t), readdir(exehome)))

        np = manager.np
        jobname = "julia-$(getpid())"
        srun_cmd = `srun -J $jobname -n $np -o "job%4t.out" -D $exehome $(srunargs) $exename $exeflags`
        if capture_stdout
            host = getipaddr().host
            exec_cmds = "c=connect(IPv4(host), port);Base.wait_connected(c);redirect_stdout(c);redirect_stderr(c);Base.start_worker(c)"
            srun_cmd = `$srun_cmd $exec_cmds`
        else
            srun_cmd = `$srun_cmd --worker`
        end
        out, srun_proc = open(srun_cmd)

        for i = 0:np - 1
            config = WorkerConfig()
            # Keep a reference to the proc, so it's properly closed once
            # the last worker exits.
            config.userdata = srun_proc
            if capture_stdout
                config.io = take!(stdout_ios)
            else
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
                        config.io = open(fn)
                        w = open(fn) do f
                            return split(split(readline(f), ":")[2], "#")
                        end
                        break
                    end
                end
                if length(w) > 0
                    config.port = parse(Int, w[1])
                    config.host = strip(w[2])
                else
                    continue
                end
            end
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

addprocs_slurm(np::Integer; kwargs...) = addprocs(SlurmManager(np);
                                                  kwargs...)
