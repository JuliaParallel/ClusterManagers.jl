# Hacked from the PBS/SGE managers

export HTCManager, addprocs_htc

immutable HTCManager <: ClusterManager
    launch::Function
    manage::Function

    HTCManager() = new(launch_htc_workers, manage_htc_worker)
end

function launch_htc_workers(cman::HTCManager, np::Integer, config::Dict)
    exehome = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    home = ENV["HOME"]

    jobname = "julia-$(getpid())"

    # Write condor submission script
    subf = open("$home/$jobname.sub", "w")
    println(subf, "executable = $exehome/$exename")
    println(subf, "arguments = --worker")
    println(subf, "universe = vanilla")
    for i = 1:np
        println(subf, "output = $home/$jobname-$i.o")
        println(subf, "error= $home/$jobname-$i.e")
        println(subf, "queue")
    end
    close(subf)

    qsub_cmd = `condor_submit $home/$jobname.sub`
    out,qsub_proc = readsfrom(qsub_cmd)
    if !success(qsub_proc)
        error("batch queue not available (could not run qsub)")
    end
    id = chomp(split(readline(out),'.')[1])
    if endswith(id, "[]")
        id = id[1:end-2]
    end
    filename(i) = "$home/$jobname-$i.o"
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
        configs[i] = merge(config, {:job => id, :task => i, :iofile => fname, :process => io_proc})
    end
    println("")
    (:io_only, collect(zip(io_objs, configs)))
end

function manage_htc_worker(id::Integer, config::Dict, op::Symbol)
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

addprocs_htc(np::Integer) = addprocs(np, cman=HTCManager())
