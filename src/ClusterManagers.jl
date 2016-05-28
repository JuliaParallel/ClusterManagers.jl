module ClusterManagers

export launch, manage, kill, init_worker, connect
import Base: launch, manage, kill, init_worker, connect

if VERSION >= v"0.5.0-dev+4047"
    worker_arg = `--worker $(Base.cluster_cookie())`
else
    worker_arg = `--worker`
end

# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")
include("scyld.jl")
include("condor.jl")
include("slurm.jl")
include("affinity.jl")

end
