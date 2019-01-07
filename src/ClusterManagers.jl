module ClusterManagers

using Distributed
using Sockets

export launch, manage, kill, init_worker, connect
import Distributed: launch, manage, kill, init_worker, connect

worker_arg() = `--worker=$(Distributed.init_multi(); cluster_cookie())`


# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")
include("scyld.jl")
include("condor.jl")
include("slurm.jl")
include("affinity.jl")
include("elastic.jl")
include("lsf.jl")

end
