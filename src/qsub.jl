export PBSManager, SGEManager, addprocs_pbs, addprocs_sge

immutable PBSManager <: ClusterManager
    launch::Function
    manage::Function

    PBSManager() = new(launch_qsub_workers, manage_qsub_worker)
end

immutable SGEManager <: ClusterManager
    launch::Function
    manage::Function

    SGEManager() = new(launch_qsub_workers, manage_qsub_worker)
end

function launch_qsub_workers(cman::Union(PBSManager, SGEManager), np::Integer, config::Dict)
    exehome = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    home = ENV["HOME"]
    isPBS = isa(cman, PBSManager)

    jobname = "julia-$(getpid())"
    qsub_cmd = `echo $exehome/$exename $exeflags` |> (isPBS ? `qsub -N $jobname -j oe -k o -t 1-$np` : `qsub -N $jobname -terse -j y -t 1-$np`)
    out,qsub_proc = readsfrom(qsub_cmd)
    if !success(qsub_proc)
        error("batch queue not available (could not run qsub)")
    end
    id = chomp(split(readline(out),'.')[1])
    if endswith(id, "[]")
        id = id[1:end-2]
    end
    filename(i) = isPBS ? "$home/$jobname-$i.o$id" : "$home/$jobname.o$id.$i"
    print("job id is $id, waiting for job to start ")
    io_objs = cell(np)
    configs = cell(np)
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
        io_objs[i],io_proc = readsfrom(cmd)
        io_objs[i].line_buffered = true
        configs[i] = merge(config, {:job => id, :task => i, :iofile => fname, :process => proc})
    end
    println("")
    (:io_only, collect(zip(io_objs, configs)))
end

function manage_qsub_worker(id::Integer, config::Dict, op::Symbol)
    if op == :finalize
        kill(config[:process])
        if isfile(config[:iofile])
            rm(config[:iofile])
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

addprocs_pbs(np::Integer) = addprocs(np, cman=PBSManager())
addprocs_sge(np::Integer) = addprocs(np, cman=SGEManager())
