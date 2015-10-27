module ClusterManagers

export launch, manage, kill, init_worker, connect 
import Base: launch, manage, kill, init_worker, connect
# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")
include("scyld.jl")
include("condor.jl")
include("slurm.jl")
include("affinity.jl")

end
