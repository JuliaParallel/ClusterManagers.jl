# ClusterManager for HTCondor

export HTCManager, addprocs_htc

immutable HTCManager <: ClusterManager
    launch::Function
    manage::Function

    HTCManager() = new(launch_htc_workers, manage_htc_worker)
end

function condor_script(portnum::Integer, np::Integer, config::Dict)
    exehome = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    home = ENV["HOME"]
    hostname = ENV["HOSTNAME"]
    jobname = "julia-$(getpid())"
    tdir = "$home/.julia-htc"
    run(`mkdir -p $tdir`)

    scriptf = open("$tdir/$jobname.sh", "w")
    println(scriptf, "#!/bin/sh")
    println(scriptf, "$exehome/$exename --worker | /usr/bin/telnet $hostname $portnum")
    close(scriptf)

    subf = open("$tdir/$jobname.sub", "w")
    println(subf, "executable = /bin/bash")
    println(subf, "arguments = ./$jobname.sh")
    println(subf, "universe = vanilla")
    println(subf, "should_transfer_files = yes")
    println(subf, "transfer_input_files = $tdir/$jobname.sh")
    println(subf, "Notification = Error")
    for i = 1:np
        println(subf, "output = $tdir/$jobname-$i.o")
        println(subf, "error= $tdir/$jobname-$i.e")
        println(subf, "queue")
    end
    close(subf)

    "$tdir/$jobname.sub"
end

function launch_htc_workers(cman::HTCManager, np::Integer, config::Dict)
    portnum = rand(8000:9000)
    server = listen(portnum)

    script = condor_script(portnum, np, config) 
    out,proc = open(`condor_submit $script`)
    if !success(proc)
        error("batch queue not available (could not run condor_submit)")
    end
    print(readline(out))
    print("Waiting for $np workers: ")

    io_objs = cell(np)
    configs = cell(np)
    for i=1:np
         conn = accept(server)
         io_objs[i] = conn
         configs[i] = merge(config, {:conn => conn, :server => server})
         print("$i ")
    end
    println(".")

    (:io_only, collect(zip(io_objs, configs)))
end

function manage_htc_worker(id::Integer, config::Dict, op::Symbol)
    if op == :finalize
        close(config[:conn])
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
