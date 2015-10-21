export PBSManager, SGEManager, addprocs_pbs, addprocs_sge

immutable PBSManager <: ClusterManager
    np::Integer
    queue::AbstractString
end

immutable SGEManager <: ClusterManager
    np::Integer
    queue::AbstractString
end


function launch(manager::Union{PBSManager, SGEManager}, params::Dict, instances_arr::Array, c::Condition)
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

        qsub_options = length(queue) > 0 ? [jobname queue] : jobname
    
        cmd = `cd $dir && $exename $exeflags --worker`
        qsub_cmd = pipeline(`echo $(Base.shell_escape(cmd))` , (isPBS ? `qsub -N $qsub_options -j oe -k o -t 1-$np` : `qsub -N $qsub_options -terse -j y -t 1-$np`))
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

            config = WorkerConfig()

            config.io, io_proc = open(detach(cmd))

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

function manage(manager::Union{PBSManager, SGEManager}, id::Int64, config::WorkerConfig, op::Symbol)

end

function kill(manager::Union{PBSManager, SGEManager}, id::Int64, config::WorkerConfig)

    remotecall(id,exit)
    close(get(config.io))

    kill(get(config.userdata)[:process],15)  

    if isfile(get(config.userdata)[:iofile])
        rm(get(config.userdata)[:iofile])
    end

end

addprocs_pbs(np::Integer, queue="") = addprocs(PBSManager(np, queue))
addprocs_sge(np::Integer, queue="") = addprocs(SGEManager(np, queue))
