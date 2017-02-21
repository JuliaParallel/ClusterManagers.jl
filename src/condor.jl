# ClusterManager for HTCondor

export HTCManager, addprocs_htc

immutable HTCManager <: ClusterManager
    np::Integer
end

function condor_script(portnum::Integer, np::Integer, params::Dict)
    dir = params[:dir]
    exename = params[:exename]
    exeflags = params[:exeflags]
    home = ENV["HOME"]
    hostname = ENV["HOSTNAME"]
    jobname = "julia-$(getpid())"
    tdir = "$home/.julia-htc"
    run(`mkdir -p $tdir`)

    scriptf = open("$tdir/$jobname.sh", "w")
    println(scriptf, "#!/bin/sh")
    println(scriptf, "cd $(Base.shell_escape(dir))")
    println(scriptf, "$(Base.shell_escape(exename)) $(Base.shell_escape(worker_arg)) \$1 | /usr/bin/telnet $(Base.shell_escape(hostname)) $portnum")
    close(scriptf)

    subf = open("$tdir/$jobname.sub", "w")
    println(subf, "executable = /bin/bash")
    println(subf, "universe = vanilla")
    println(subf, "should_transfer_files = yes")
    println(subf, "transfer_input_files = $tdir/$jobname.sh")
    println(subf, "Notification = Error")
    for i = 1:np
        println(subf, "output = $tdir/$jobname-$i.o")
        println(subf, "error= $tdir/$jobname-$i.e")
        println(subf, "arguments = ./$jobname.sh $(i-1)")
        println(subf, "queue")
    end
    close(subf)

    "$tdir/$jobname.sub"
end

function launch(manager::HTCManager, params::Dict, instances_arr::Array, c::Condition)
    try
        portnum = rand(8000:9000)
        server = listen(portnum)
        np = manager.np
        jobdata = Dict()

        script = condor_script(portnum, np, params)
        out,proc = open(`condor_submit $script`)
        if !success(proc)
            println("batch queue not available (could not run condor_submit)")
            return
        end
        outstring = readstring(out)
        println(split(outstring,"\n")[1])
        m = match(r"submitted to cluster (\d+)\.",outstring)
        if m != nothing
            jobdata[:id] = parse(m[1])
        end

        print("Waiting for $np workers: ")

        for i=1:np
            conn = accept(server)
            config = WorkerConfig()

            config.io = conn
            config.userdata = copy(jobdata)

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

function kill(manager::HTCManager, pid::Int64, config::WorkerConfig)
    if !isnull(config.userdata)
        jobdata = get(config.userdata)
        job_id = "$(jobdata[:id]).$(jobdata[:proc])"
        if !success(`condor_rm $job_id`)
            println("Error removing condor job $job_id")
        end
    end
end

function manage(manager::HTCManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :finalize
        if !isnull(config.io)
            close(get(config.io))
        end
    elseif op == :register
        if !isnull(config.userdata)
            remoteargs = remotecall_fetch(getfield,id,Base,:ARGS)
            if length(remoteargs)==1
                get(config.userdata)[:proc] = parse(remoteargs[1])
            end
        end
    elseif op == :interrupt
        kill(manager,id,config)
    end
end

addprocs_htc(np::Integer) = addprocs(HTCManager(np))
