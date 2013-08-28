module ClusterManagers

# PBS doesn't have the same semantics as SGE wrt to file accumulate,
# a different solution will have to be found
include("qsub.jl")
include("scyld.jl")

end
