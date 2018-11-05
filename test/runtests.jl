# only package loading for now
using ClusterManagers
using Distributed
using Test

@testset "AffinityManager" begin
    manager = addprocs(LocalAffinityManager(np = 2, mode = COMPACT, affinities = Int[]))
    addprocs(manager)
    rmprocs(manager)

    manager = addprocs(LocalAffinityManager(np = 2, mode = BALANCED, affinities = Int[]))
    addprocs(manager)
    rmprocs(manager)
end
