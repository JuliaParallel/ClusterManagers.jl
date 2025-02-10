module ClusterManagers

using Distributed
using Sockets
using Pkg

import LSFClusterManager
import SlurmClusterManager

export launch, manage, kill, init_worker, connect
import Distributed: launch, manage, kill, init_worker, connect

# Bring some other names into scope, just for convenience:
using Distributed: addprocs

worker_cookie() = begin Distributed.init_multi(); cluster_cookie() end
worker_arg() = `--worker=$(worker_cookie())`


# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")

include("auto_detect.jl")
include("scyld.jl")
include("condor.jl")
include("slurm.jl")
include("affinity.jl")
include("elastic.jl")

end
