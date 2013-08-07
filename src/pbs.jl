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

    pbsdir = joinpath(pwd(),"PBS")
    mkpath(pbsdir)

    qsub_cmd = `echo $home/$(exename) $(exeflags)` |> `qsub -N JULIA -j oe -o $pbsdir -t 1-$np`
    out,qsub_proc = readsfrom(qsub_cmd)
    if !success(qsub_proc)
        error("batch queue not available (could not run qsub)")
    end
    id = chomp(split(readline(out),'.')[1])
    if endswith(id, "[]")
        id = id[1:end-2]
    end
    println("job id is $id")
    print("waiting for job to start");
    io_objs = cell(np)
    configs = cell(np)
    for i=1:np
        # wait for each output stream file to get created
        fname = "$pbsdir/JULIA.o$id-$i"
        while !isfile(fname)
            print(".")
            sleep(0.5)
        end
        # Hack to get Base to get the host:port, the Julia process has already started.
        io_objs[i] = `tail -f $fname`
        configs[i] = merge(config, {:job => id, :task => i})
    end

    (:cmd, collect(zip(io_objs, configs)))
end

function manage_pbs_worker(id::Integer, config::Dict, op::Symbol)
    if op == :interrupt
        job = config[:job]
        task = config[:task]
        if !success(`qdel $job -t $task`)
            println("Error sending a Ctrl-C to julia worker $id on PBS (job: $job, task: $task)")
        end
    end
end

addprocs_pbs(np::Integer) = addprocs(np, cman=PBSManager())
