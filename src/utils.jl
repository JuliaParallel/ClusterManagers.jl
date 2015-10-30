
export describepids 

@doc """
Make a function that filters out strings matching the hostname of process 1.\n
""" ->
function makefiltermaster()
    master_node = strip(remotecall_fetch(readall, 1, `hostname`), '\n')
    function filtermaster(x)
        x != master_node
    end
    filtermaster
end

@doc """
Return a dictionary topo describing the computing resources Julia currently has access to.\n
pids should be a list of the pids of interest
Optional argument filterfn::Function removes processes whose hostname is rejected by the filter.
length(topo) gives the number of unique nodes.\n
keys(topo) gives the id of a single process on each compute node.\n
values(topo) gives the ids of all processes running on each compute node.
""" ->
function describepids(pids; filterfn=(x)->true)

    # facts about the machines the processes run on
    machines = [strip(remotecall_fetch(readall, w, `hostname`), '\n') for w in pids]
    machine_names = sort!(collect(Set(machines)))
    machine_names = filter(filterfn, machine_names)
    num_machines = length(machine_names)

    # nominate a representative process for each machine, and define who it represents
    representative = zeros(Int64, num_machines)
    constituency = Dict()
    for (i,name) in enumerate(machine_names)
        constituency[i] = Int64[]
        for (j,machine) in enumerate(machines)
            if name==machine
                push!(constituency[i], pids[j])
                representative[i] = pids[j]
            end
        end
    end

    # assemble the groups of processes keyed by their representatives
    topo = Dict()
    for (i,p) in enumerate(representative)
        topo[p] = constituency[i]
    end

    topo
end


@doc """
Return information about the resources (pids) available to us grouped by the machine they are running on.\n
keyword argument: remote=0 (default) specifies remote machines; remote=1 the local machine; remote=2 all machines.\n 
length(topo) gives the number of unique nodes.\n
keys(topo) gives the id of a single process on each compute node.\n
values(topo) gives the ids of all processes running on each compute node.
""" ->
function describepids(; remote=0)
    pids = procs()
    if remote==0
        filterfn = makefiltermaster()
    elseif remote==1
        filtertrue = makefiltermaster()
        filterfn = (x)->!filtertrue(x)
    elseif remote==2
        filterfn=(x)->true
    end
    describepids(pids; filterfn=filterfn)
end

