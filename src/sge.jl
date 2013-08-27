export addprocs_sge, SGEManager

immutable SGEManager <: ClusterManager
    launch::Function
    manage::Function

    SGEManager() = new(launch_sge_workers, manage_sge_worker)
end

function launch_sge_workers(cman::SGEManager, np::Integer, config::Dict)
    home = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]

    sgedir = joinpath(pwd(),"SGE")
    mkpath(sgedir)

    qsub_cmd = `echo $home/$(exename) $(exeflags)` |> `qsub -N JULIA -terse -cwd -j y -o $sgedir -t 1-$np`
    out,qsub_proc = readsfrom(qsub_cmd)
    if !success(qsub_proc)
        error("batch queue not available (could not run qsub)")
    end
    id = chomp(split(readline(out),'.')[1])
    println("job id is $id")
    print("waiting for job to start");
    io_objs = cell(np)
    configs = cell(np)
    for i=1:np
        # wait for each output stream file to get created
        fname = "$sgedir/JULIA.o$id.$i"
        while !isfile(fname)
            print(".")
            sleep(0.5)
        end
        # Hack to get Base to get the host:port, the Julia process has already started.
        cmd = `tail -f $fname`
        cmd.detach = true
        io_objs[i],proc = readsfrom(cmd)
        io_objs[i].line_buffered = true
        configs[i] = merge(config, {:job => id, :task => i, :process => proc})
    end

    (:io_only, collect(zip(io_objs, configs)))
end

function manage_sge_worker(id::Integer, config::Dict, op::Symbol)
    if op == :interrupt
        job = config[:job]
        task = config[:task]
        if !success(`qdel $job -t $task`)
            println("Error sending a Ctrl-C to julia worker $id on SGE (job: $job, task: $task)")
        end
    elseif op == :finalize
        kill(config[:process])
    end
end

addprocs_sge(np::Integer) = addprocs(np, cman=SGEManager())
