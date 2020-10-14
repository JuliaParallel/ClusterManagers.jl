import Distributed

export ExistingProcessManager, addprocs_existing

struct ExistingProcessManager <: Distributed.ClusterManager
    wconfigs::Vector{Distributed.WorkerConfig}
end

function ExistingProcessManager(hosts_and_ports::Vector{Tuple{String, Int}})
    num_workers = length(hosts_and_ports)
    wconfigs = Vector{Distributed.WorkerConfig}(undef, num_workers)
    for i = 1:num_workers
        host_and_port = hosts_and_ports[i]
        host = host_and_port[1]
        port = host_and_port[2]
        wconfig = Distributed.WorkerConfig()
        wconfig.host = host
        wconfig.port = port
        wconfigs[i] = wconfig
    end
    return ExistingProcessManager(wconfigs)
end

function Distributed.launch(manager::ExistingProcessManager,
                            params::Dict,
                            launched::Array,
                            launch_ntfy::Condition)
    while !isempty(manager.wconfigs)
        wconfig = pop!(manager.wconfigs)
        push!(launched, wconfig)
        notify(launch_ntfy)
    end
    return nothing
end

function Distributed.manage(manager::ExistingProcessManager,
                            id::Integer,
                            config::Distributed.WorkerConfig,
                            op::Symbol)
    return nothing
end

addprocs_existing(workers; kwargs...) = Distributed.addprocs(ExistingProcessManager(workers); kwargs...)
