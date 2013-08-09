export addprocs_scyld, ScyldManager

immutable ScyldManager <: ClusterManager
    launch::Function
    manage::Function

    ScyldManager() = new(launch_scyld_workers, manage_scyld_worker)
end

function launch_scyld_workers(cman::ScyldManager, np::Integer, config::Dict)
    home = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    
    beomap_cmd = `bpsh -1 beomap --no-local --np $np`
    out,beomap_proc = readsfrom(beomap_cmd)
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
        io_objs[i],_ = readsfrom(cmd)
        io_objs[i].line_buffered = true
    end
    (:io_only, collect(zip(io_objs, configs)))
end

function manage_scyld_worker(id::Integer, config::Dict, op::Symbol)
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

addprocs_scyld(np::Integer) = addprocs(np, cman=ScyldManager()) 
