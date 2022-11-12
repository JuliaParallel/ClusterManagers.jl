module ClusterManagers

using Distributed
using Sockets
using Pkg

export launch, manage, kill, init_worker, connect
import Distributed: launch, manage, kill, init_worker, connect

function __init__()
    Distributed.init_multi()
end

const worker_jl = joinpath(dirname(pathof(ClusterManagers)), "worker.jl")
function worker_arg(master; cookie=cluster_cookie())
    `$(worker_jl) --connect-to=$master $cookie`
end

function listen_for_workers(N)
    interface = IPv4(LPROC.bind_addr)
    if LPROC.bind_port == 0
        port_hint = 9000 + (getpid() % 1000)
        (port, sock) = listenany(interface, UInt16(port_hint))
        LPROC.bind_port = port
    else
        sock = listen(interface, LPROC.bind_port)
    end

    nworkers = 0
    workers = Vector{Any}[]
    while isopen(sock)
        client = accept(sock)
        nbytes = read(client, Int)
        addr = read(client, nbytes)
        port = read(client, Int)
        push!(workers, (addr, port))
        close(client)
        nworkers += 1
        if nworkers >= N
            close(sock)
        end
    end
    return workers
end


# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
# include("qsub.jl")
# include("scyld.jl")
# include("condor.jl")
# include("slurm.jl")
# include("affinity.jl")
# include("elastic.jl")
# include("lsf.jl")

end
