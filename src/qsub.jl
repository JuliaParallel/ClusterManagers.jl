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
            queue = ``
        else
            this_queue = manager.queue
            queue = `-q $this_queue`
        end


        if params[:qsub_env] == ""
            qsub_env = ``
        else
            evar = params[:qsub_env]
            qsub_env = `-v $evar`
        end

	# 64bit Julia pre-allocates 10G virtual memory
	if WORD_SIZE == 64
		vmem=`-l h_vmem=10.1G`
	end

        np = manager.np

        jobname = `julia-$(getpid())`

        cmd = `cd $dir && $exename $exeflags --worker`
        qsub_cmd = pipeline(`echo $(Base.shell_escape(cmd))` , (isPBS ? `qsub -N $jobname -j oe -k o -t 1-$np $queue $qsub_env` : `qsub -N $jobname -terse -j y -t 1-$np $vmem $queue $qsub_env`))
        out,qsub_proc = open(qsub_cmd)
        if !success(qsub_proc)
            println("batch queue not available (could not run qsub)")
            return
        end
        id = chomp(split(readline(out),'.')[1])
        if endswith(id, "[]")
            id = id[1:end-2]
        end

        filename(i) = isPBS ? "$home/julia-$(getpid())-$i.o$id" : "$home/julia-$(getpid()).o$id.$i"
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

addprocs_pbs(np::Integer; queue::AbstractString="",qsub_env::AbstractString="") = addprocs(PBSManager(np, queue),qsub_env=qsub_env)
addprocs_sge(np::Integer; queue::AbstractString="",qsub_env::AbstractString="") = addprocs(SGEManager(np, queue),qsub_env=qsub_env)
