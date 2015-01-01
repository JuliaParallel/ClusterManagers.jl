export PBSManager, SGEManager, addprocs_pbs, addprocs_sge

immutable PBSManager <: ClusterManager
    np::Integer
    queue::String
end

immutable SGEManager <: ClusterManager
    np::Integer
    queue::String
end


function launch(manager::Union(PBSManager, SGEManager), params::Dict, instances_arr::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]
        home = ENV["HOME"]
        isPBS = isa(manager, PBSManager)
        if manager.queue == ""
            queue = ""
        else
            queue = "-q " * manager.queue
        end
        np = manager.np

        jobname = "julia-$(getpid())"
        cmd = `cd $dir && $exename $exeflags`
        qsub_cmd = `echo $(Base.shell_escape(cmd))` |> (isPBS ? `qsub -N $jobname $queue -j oe -k o -t 1-$np` : `qsub -N $jobname $queue -terse -j y -t 1-$np`)
        out,qsub_proc = open(qsub_cmd)
        if !success(qsub_proc)
            println("batch queue not available (could not run qsub)")
            return
        end
        id = chomp(split(readline(out),'.')[1])
        if endswith(id, "[]")
            id = id[1:end-2]
        end
        filename(i) = isPBS ? "$home/$jobname-$i.o$id" : "$home/$jobname.o$id.$i"
        print("job id is $id, waiting for job to start ")
        for i=1:np
            # wait for each output stream file to get created
            fname = filename(i)
            while !isfile(fname)
                print(".")
                sleep(1.0)
            end
            # Hack to get Base to get the host:port, the Julia process has already started.
            cmd = `tail -f $fname`
            cmd.detach = true

            config = WorkerConfig()

            config.io, io_proc = open(cmd)
            config.line_buffered = true

            config.userdata = Dict{Symbol, Any}(:job => id, :task => i, :iofile => fname, :process => io_proc)
            push!(instances_arr, config)
            notify(c)
        end
        println("")

    catch e
        println("Error launching qsub")
        println(e)
    end
end

function manage(manager::Union(PBSManager, SGEManager), id::Integer, config::WorkerConfig, op::Symbol)
    if op == :finalize
        kill(config.userdata[:process])
        if isfile(config.userdata[:iofile])
            rm(config.userdata[:iofile])
        end
#     elseif op == :interrupt
#         job = config[:job]
#         task = config[:task]
#         # this does not currently work
#         if !success(`qsig -s 2 -t $task $job`)
#             println("Error sending a Ctrl-C to julia worker $id (job: $job, task: $task)")
#         end
    end
end

addprocs_pbs(np::Integer, queue="") = addprocs(PBSManager(np, queue))
addprocs_sge(np::Integer, queue="") = addprocs(SGEManager(np, queue))
