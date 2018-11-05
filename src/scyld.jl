export addprocs_scyld, ScyldManager

struct ScyldManager <: ClusterManager
    np::Integer
end

function launch(manager::ScyldManager, params::Dict, instances_arr::Array, c::Condition)
    try
        dir = params[:dir]
        exename = params[:exename]
        exeflags = params[:exeflags]
        np = manager.np

        beomap_cmd = `bpsh -1 beomap --no-local --np $np`
        out,beomap_proc = open(beomap_cmd)
        wait(beomap_proc)
        if !success(beomap_proc)
            error("node availability inaccessible (could not run beomap)")
        end
        nodes = split(chomp(readline(out)),':')
        for (i,node) in enumerate(nodes)
            cmd = `cd $dir '&&' $exename $exeflags $(worker_arg())`
            cmd = detach(`bpsh $node sh -l -c $(Base.shell_escape(cmd))`)
            config = WorkerConfig()

            config.io,_ = open(cmd)
            config.io.line_buffered = true
            config.userdata = Dict{Symbol, Any}()
            config.userdata[:node] = node

            push!(instances_arr, config)
            notify(c)
        end
   catch e
        println("Error launching beomap")
        println(e)
   end
end

function manage(manager::ScyldManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :interrupt
        if !isnull(config.ospid)
            node = config.userdata[:node]
            if !success(`bpsh $node kill -2 $(get(config.ospid))`)
                println("Error sending Ctrl-C to julia worker $id on node $node")
            end
        else
            # This state can happen immediately after an addprocs
            println("Worker $id cannot be presently interrupted.")
        end
    end
end

addprocs_scyld(np::Integer) = addprocs(ScyldManager(np))
