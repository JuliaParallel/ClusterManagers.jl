import Distributed

struct ExistingProcessManager <: Distributed.ClusterManager
    wconfigs::Vector{Distributed.WorkerConfig}
end

function ExistingProcessManager(hosts_and_ports::Vector{Tuple{String, Int}})
    num_workers = length(hosts_and_ports)
    wconfigs = Vector{Distributed.WorkerConfig}(undef, num_workers)
    for i = 1:num_workers
        host_and_port = hosts_and_ports[i]::Tuple{String, Int}
        wconfig = Distributed.WorkerConfig()
        wconfig.host = host_and_port[1]::String
        wconfig.port = host_and_port[2]::Int
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
