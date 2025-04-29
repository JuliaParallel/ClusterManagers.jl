module ClusterManagers

using Distributed
using Sockets
using Pkg

export launch, manage, kill, init_worker, connect
import Distributed: launch, manage, kill, init_worker, connect

worker_cookie() = begin Distributed.init_multi(); cluster_cookie() end
worker_arg() = `--worker=$(worker_cookie())`


# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")
include("scyld.jl")
include("condor.jl")
include("affinity.jl")

end
