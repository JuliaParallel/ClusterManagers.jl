export PBSManager, SGEManager, addprocs_pbs, addprocs_sge

immutable PBSManager <: ClusterManager
end

immutable SGEManager <: ClusterManager
end

<<<<<<< HEAD
function launch_qsub_workers(cman::Union(PBSManager, SGEManager), np::Integer, config::Dict)
    exehome = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    home = ENV["HOME"]
    isPBS = isa(cman, PBSManager)
    queue = haskey(config,:queue) ? string("-j ", config[:qeueu]) : ""

    jobname = "julia-$(getpid())"
    qsub_cmd = `echo "cd $(pwd()) && $exehome/$exename $exeflags"` |> (isPBS ? `qsub -N $jobname $queue -j oe -k o -t 1-$np` : `qsub -N $jobname $queue -terse -j y -t 1-$np`)
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
=======
function launch(manager::Union(PBSManager, SGEManager), np::Integer, config::Dict, instances_arr::Array, c::Condition)
    try
        exehome = config[:dir]
        exename = config[:exename]
        exeflags = config[:exeflags]
        home = ENV["HOME"]
        isPBS = isa(manager, PBSManager)

        jobname = "julia-$(getpid())"
        qsub_cmd = `echo "cd $(pwd()) && $exehome/$exename $exeflags"` |> (isPBS ? `qsub -N $jobname -j oe -k o -t 1-$np` : `qsub -N $jobname -terse -j y -t 1-$np`)
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
            io_objs[i],io_proc = open(cmd)
            io_objs[i].line_buffered = true
            configs[i] = merge(config, {:job => id, :task => i, :iofile => fname, :process => io_proc})
>>>>>>> 8a476dc8b999a73f8fefaa9c457b7455bd6adc81
        end
        println("")
        
        push!(instances_arr, collect(zip(io_objs, configs)))
        notify(c)
    catch e
        println("Error launching qsub")
        println(e)
    end
end

function manage(manager::Union(PBSManager, SGEManager), id::Integer, config::Dict, op::Symbol)
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

addprocs_pbs(np::Integer) = addprocs(np, manager=PBSManager())
addprocs_sge(np::Integer) = addprocs(np, manager=SGEManager())
