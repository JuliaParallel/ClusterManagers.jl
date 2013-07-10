export addprocs_scyld, ScyldManager

immutable ScyldManager <: ClusterManager
    launch_cb::Function

    ScyldManager() = new(launch_scyld_workers)
end


function launch_scyld_workers(np::Integer, config::Dict)
    home = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    
    beomap_cmd = `beomap --no-local --np $np`
    out,beomap_proc = readsfrom(beomap_cmd)
    wait(beomap_proc)
    if !success(beomap_proc)
        error("node availability inaccessible (could not run beomap)")
    end
    nodes = split(chomp(readline(out)),':')
    outs = cell(np)
    for (i,node) in enumerate(nodes)
        cmd = `bpsh $node sh -l -c "cd $home && $(exename) $(exeflags)"`
        cmd.detach = true
        outs[i],_ = readsfrom(cmd)
        outs[i].line_buffered = true
    end
    (:io_only, outs)
end


addprocs_scyld(np::Integer) = addprocs(np, cman=ScyldManager()) 

