export addprocs_scyld, ScyldManager

immutable ScyldManager <: ClusterManager
end

function launch(manager::ScyldManager, np::Integer, config::Dict, instances_arr::Array, c::Condition)
    try 
        home = config[:dir]
        exename = config[:exename]
        exeflags = config[:exeflags]

        beomap_cmd = `bpsh -1 beomap --no-local --np $np`
        out,beomap_proc = open(beomap_cmd)
        wait(beomap_proc)
        if !success(beomap_proc)
            error("node availability inaccessible (could not run beomap)")
        end
        nodes = split(chomp(readline(out)),':')
        io_objs = cell(np)
        configs = cell(np)
        for (i,node) in enumerate(nodes)
            cmd = `bpsh $node sh -l -c "cd $home && $(exename) $(exeflags)"`
            cmd.detach = true
            configs[i] = merge(config, {:node => node})
            io_objs[i],_ = open(cmd)
            io_objs[i].line_buffered = true
        end
        
        push!(instances_arr, collect(zip(io_objs, configs)))
        notify(c)
   catch e
        println("Error launching beomap")
        println(e)
   end
end

function manage(manager::ScyldManager, id::Integer, config::Dict, op::Symbol)
    if op == :interrupt
        if haskey(config, :ospid)
            node = config[:node]
            if !success(`bpsh $node kill -2 $(config[:ospid])`)
                println("Error sending Ctrl-C to julia worker $id on node $node")
            end
        else
            # This state can happen immediately after an addprocs
            println("Worker $id cannot be presently interrupted.")
        end
    elseif op == :register
        config[:ospid] = remotecall_fetch(id, getpid)
    end
end

addprocs_scyld(np::Integer) = addprocs(np, manager=ScyldManager()) 
