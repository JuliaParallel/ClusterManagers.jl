export PBSManager, SGEManager, QRSHManager, addprocs_pbs, addprocs_sge, addprocs_qrsh

struct PBSManager <: ClusterManager
    np::Integer
    queue
    wd
end

struct SGEManager <: ClusterManager
    np::Integer
    queue
    wd
end

struct QRSHManager <: ClusterManager
    np::Integer
    queue
    wd
end

function launch(manager::Union{PBSManager, SGEManager, QRSHManager},
        params::Dict, instances_arr::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]
        wd = manager.wd
        isPBS = isa(manager, PBSManager)

        np = manager.np
        queue = manager.queue

        jobname = `julia-$(getpid())`

        if isa(manager, QRSHManager)
          cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())`
          qrsh_cmd = `qrsh $queue -V -N $jobname -wd $wd -now n "$cmd"`

          stream_proc = [open(qrsh_cmd) for i in 1:np]

          for i in 1:np
              config = WorkerConfig()
              config.io, io_proc = stream_proc[i]
              config.userdata = Dict{Symbol, Any}(:task => i, 
                                                  :process => io_proc)
              push!(instances_arr, config)
              notify(c)
          end

        else  # PBS & SGE
            cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())`
            qsub_cmd = pipeline(`echo $(Base.shell_escape(cmd))` , (isPBS ?
                    `qsub -N $jobname -wd $wd -j oe -k o -t 1-$np $queue` :
                    `qsub -N $jobname -wd $wd -terse -j y -R y -t 1-$np -V $queue`))

            out = open(qsub_cmd)
            if !success(out)
              throw(error()) # qsub already gives a message
            end

            id = chomp(split(readline(out),'.')[1])
            if endswith(id, "[]")
                id = id[1:end-2]
            end

            filenames(i) = "$wd/julia-$(getpid()).o$id-$i","$wd/julia-$(getpid())-$i.o$id","$wd/julia-$(getpid()).o$id.$i"

            println("Job $id in queue.")
            for i=1:np
                # wait for each output stream file to get created
                fnames = filenames(i)
                j = 0
                while (j=findfirst(x->isfile(x),fnames))==nothing
                    sleep(1.0)
                end
                fname = fnames[j]

                # Hack to get Base to get the host:port, the Julia process has already started.
                cmd = `tail -f $fname`

                config = WorkerConfig()

                config.io = open(detach(cmd))

                config.userdata = Dict{Symbol, Any}(:job=>id, :task=>i, :iofile=>fname)
                push!(instances_arr, config)
                notify(c)
            end
            println("Running.")
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
    close(config.io)

    if isa(manager, QRSHManager)
      kill(config.userdata[:process],15)
      return
    end

    if isfile(config.userdata[:iofile])
        rm(config.userdata[:iofile])
    end
end

addprocs_pbs(np::Integer; qsub_flags=``, wd=ENV["HOME"], kwargs...) = addprocs(PBSManager(np, qsub_flags, wd); kwargs...)

addprocs_sge(np::Integer; qsub_flags=``, wd=ENV["HOME"], kwargs...) = addprocs(SGEManager(np, qsub_flags, wd); kwargs...)

addprocs_qrsh(np::Integer; qsub_flags=``, wd=ENV["HOME"], kwargs...) = addprocs(QRSHManager(np, qsub_flags, wd); kwargs...)
