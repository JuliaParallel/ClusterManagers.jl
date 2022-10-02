# ClusterManager for HTCondor

export HTCManager, addprocs_htc

struct HTCManager <: ClusterManager
    np::Integer
end

function condor_script(portnum::Integer, np::Integer, params::Dict)
    dir = params[:dir]
    exename = params[:exename]
    exeflags = params[:exeflags]
    extrajdl = get(params, :extrajdl, [])
    extraenv = get(params, :extraenv, [])
    extrainputs = get(params, :extrainputs, [])
    telnetexe = get(params, :telnetexe, "/usr/bin/telnet")
    home = ENV["HOME"]
    hostname = ENV["HOSTNAME"]
    jobname = "julia-$(getpid())"
    tdir = "$home/.julia-htc"
    run(`mkdir -p $tdir`)

    scriptf = open("$tdir/$jobname.sh", "w")
    println(scriptf, "#!/bin/sh")
    for line in extraenv
        println(scriptf, line)
    end
    println(scriptf, "cd $(Base.shell_escape(dir))")
    println(scriptf, "$(Base.shell_escape(exename)) $(Base.shell_escape(exeflags)) \
            -e 'using Distributed; start_worker($(repr(worker_cookie())))' \
            | $telnetexe $(Base.shell_escape(hostname)) $portnum")
    close(scriptf)

    input_files = ["$tdir/$jobname.sh"]
    append!(input_files, extrainputs)
    subf = open("$tdir/$jobname.sub", "w")
    println(subf, "executable = /bin/bash")
    println(subf, "arguments = ./$jobname.sh")
    println(subf, "universe = vanilla")
    println(subf, "should_transfer_files = yes")
    println(subf, "transfer_input_files = $(join(input_files, ','))")
    println(subf, "Notification = Error")
    for line in extrajdl
        println(subf, line)
    end
    for i = 1:np
        println(subf, "output = $tdir/$jobname-$i.o")
        println(subf, "error= $tdir/$jobname-$i.e")
        println(subf, "queue")
    end
    close(subf)

    "$tdir/$jobname.sub"
end

function launch(manager::HTCManager, params::Dict, instances_arr::Array, c::Condition)
    try
        portnum = rand(8000:9000)
        portnum, server = listenany(ip"0.0.0.0", portnum)
        np = manager.np

        script = condor_script(portnum, np, params)
        cmd = `condor_submit $script`
        if !success(cmd)
            println("batch queue not available (could not run condor_submit)")
            return
        end
        print("Waiting for $np workers: ")

        for i=1:np
            conn = accept(server)
            config = WorkerConfig()

            config.io = conn

            push!(instances_arr, config)
            notify(c)
            print("$i ")
        end
        println(".")

   catch e
        println("Error launching condor")
        println(e)
   end
end

function manage(manager::HTCManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :finalize
        if !isnothing(config.io)
            close(get(config.io))
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

addprocs_htc(np::Integer) = addprocs(HTCManager(np))
