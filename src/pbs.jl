export addprocs_pbs, PBSManager

immutable PBSManager <: ClusterManager
    launch::Function
    manage::Function

    PBSManager() = new(launch_pbs_workers, manage_pbs_worker)
end

function launch_pbs_workers(cman::PBSManager, np::Integer, config::Dict)
    home = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]

    jobname = "julia-$(getpid())"
    qsub_cmd = `echo $home/$(exename) $(exeflags)` |> `qsub -N $jobname -j oe -k o -t 1-$np`
    out,qsub_proc = readsfrom(qsub_cmd)
    if !success(qsub_proc)
        error("batch queue not available (could not run qsub)")
    end
    id = chomp(split(readline(out),'.')[1])
    if endswith(id, "[]")
        id = id[1:end-2]
    end
    print("job id is $id, waiting for job to start ")
    io_objs = cell(np)
    configs = cell(np)
    for i=1:np
        # wait for each output stream file to get created
        fname = "$(ENV["HOME"])/$jobname-$i.o$id"
        while !isfile(fname)
            print(".")
            sleep(0.5)
        end
        cmd = `tail -f $fname`
        cmd.detach = true
        io_objs[i],proc = readsfrom(cmd)
        io_objs[i].line_buffered = true
        configs[i] = merge(config, {:job => id, :task => i, :iofile => fname, :process => proc})
    end
    println("")
    (:io_only, collect(zip(io_objs, configs)))
end

function manage_pbs_worker(id::Integer, config::Dict, op::Symbol)
    if op == :interrupt
        job = config[:job]
        task = config[:task]
        if !success(`qdel $job -t $task`)
            println("Error sending a Ctrl-C to julia worker $id on PBS (job: $job, task: $task)")
        end
    elseif op == :finalize
        kill(config[:process])
        if isfile(config[:iofile])
            rm(config[:iofile])
        end
    end
end

addprocs_pbs(np::Integer) = addprocs(np, cman=PBSManager())
