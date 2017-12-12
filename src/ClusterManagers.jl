VERSION >= v"0.4.0-dev+6521" && __precompile__(true)

module ClusterManagers

using Compat

export launch, manage, kill, init_worker, connect
import Base: launch, manage, kill, init_worker, connect

worker_arg = `--worker`

function __init__()
    global worker_arg
    worker_arg = `--worker=$(Base.cluster_cookie())`
end

# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")
include("scyld.jl")
include("condor.jl")
include("slurm.jl")
include("affinity.jl")
include("elastic.jl")

end
