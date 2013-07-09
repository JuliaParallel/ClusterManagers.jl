export addprocs_sge, SGEManager

immutable SGEManager <: ClusterManager
    launch_cb::Function

    SGEManager() = new(launch_sge_workers)
end

function launch_sge_workers(np::Integer, config::Dict) 
    home = config[:dir]
    exename = config[:exename]
    exeflags = config[:exeflags]
    
    sgedir = joinpath(pwd(),"SGE")
    run(`mkdir -p $sgedir`)
    
    qsub_cmd = `echo $home/$(exename) $(exeflags)` |> `qsub -N JULIA -terse -cwd -j y -o $sgedir -t 1:$np`
    out,qsub_proc = readsfrom(qsub_cmd)
    if !success(qsub_proc)
        error("batch queue not available (could not run qsub)")
    end
    id = chomp(split(readline(out),'.')[1])
    println("job id is $id")
    print("waiting for job to start");
    outs = cell(n)
    for i=1:n
        # wait for each output stream file to get created
        fname = "$sgedir/JULIA.o$(id).$(i)"
        while !(isfile(fname))
            print(".");
            sleep(0.5)
        end
        # Hack to get Base to get the host:port, the Julia process has already started.
        outs[i] = `tail -f $fname`
    end

    (:cmd, outs)
end


addprocs_sge(np::Integer) = addprocs(np, cman=SGEManager()) 
