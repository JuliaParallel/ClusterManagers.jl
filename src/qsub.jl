export PBSManager, SGEManager, QRSHManager, addprocs_pbs, addprocs_sge, addprocs_qrsh

immutable PBSManager <: ClusterManager
    np::Integer
    queue::AbstractString
end

immutable SGEManager <: ClusterManager
    np::Integer
    queue::AbstractString
end

immutable QRSHManager <: ClusterManager
    np::Integer
    queue::AbstractString
end

function launch(manager::Union{PBSManager, SGEManager, QRSHManager},
        params::Dict, instances_arr::Array, c::Condition)
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

        if params[:tmem] == ""
            tmem= `-l tmem=1.9G`        # Required by CS Cluster  - 1.9G best throughput
        else 
            tmemvar = params[:tmem]
            tmem = `-l tmem=$tmemvar`
        end

        if params[:h_vmem] == ""
            h_vmem= `-l h_vmem=1.9G`    # Required by CS Cluster - 1.9G best throughput
        else 
            h_vmemvar = params[:h_vmem]
            h_vmem = `-l h_vmem=$h_vmemvar`
        end

        if params[:h_rt] == ""
            h_rt= ``                    # Not actually required.... but should be specified
        else 
            h_rtvar = params[:h_rt]
            h_rt = `-l h_rt=$h_rtvar`
        end

        np = manager.np

        jobname = `julia-$(getpid())`

        if isa(manager, QRSHManager)
          cmd = `cd $dir && $exename $exeflags $worker_arg`
          qrsh_cmd = `qrsh $queue $qsub_env -V -N $jobname -now n "$cmd"`

          stream_proc = [open(qrsh_cmd) for i in 1:np]

          for i in 1:np
              config = WorkerConfig()
              config.io, io_proc = stream_proc[i]
              config.userdata = Dict{Symbol, Any}(:task => i, :process => io_proc)
              push!(instances_arr, config)
              notify(c)
          end
 
        else  # PBS & SGE
            cmd = `cd $dir && $exename $exeflags $worker_arg`
            qsub_cmd = pipeline(`echo $(Base.shell_escape(cmd))` , (isPBS ?
                    `qsub -N $jobname -j oe -k o -t 1-$np $queue $qsub_env` :
                    `qsub -N $jobname -terse -j y -t 1-$np $h_vmem $tmem $h_rt -V $queue $qsub_env`))
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

                config.userdata = Dict{Symbol, Any}(:job=>id, :task=>i, :iofile=>fname, :process=>io_proc)
                push!(instances_arr, config)
                notify(c)
            end
            println("")
        end

    catch e
        println("Error launching workers")
        println(e)
    end
end

function manage(manager::Union{PBSManager, SGEManager, QRSHManager},
        id::Int64, config::WorkerConfig, op::Symbol)
end

function kill(manager::Union{PBSManager, SGEManager, QRSHManager}, id::Int64, config::WorkerConfig)
    remotecall(exit,id)
    close(get(config.io))

    kill(get(config.userdata)[:process],15)

    isa(manager, QRSHManager) && return

    if isfile(get(config.userdata)[:iofile])
        rm(get(config.userdata)[:iofile])
    end
end

addprocs_pbs(np::Integer; queue::AbstractString="", qsub_env::AbstractString="") =
        addprocs(PBSManager(np, queue),qsub_env=qsub_env)

addprocs_sge(np::Integer; queue::AbstractString="", qsub_env::AbstractString="",
                tmem::AbstractString="1.9G", h_vmem::AbstractString="1.9G",h_rt::AbstractString="") =
        addprocs(SGEManager(np, queue),qsub_env=qsub_env,tmem=tmem,h_vmem=h_vmem,h_rt=h_rt)

addprocs_qrsh(np::Integer; queue::AbstractString="", qsub_env::AbstractString="") =
        addprocs(QRSHManager(np, queue),qsub_env=qsub_env)
