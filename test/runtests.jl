import ClusterManagers
import Test

import Distributed

# Bring some names into scope, just for convenience:
using Distributed: addprocs, rmprocs
using Distributed: workers, nworkers
using Distributed: procs, nprocs
using Distributed: remotecall_fetch, @spawnat
using Test: @testset, @test, @test_skip

# SGE:
using ClusterManagers: addprocs_sge, SGEManager

const test_args = lowercase.(strip.(ARGS))

@info "" test_args

qsub_is_installed() = !isnothing(Sys.which("qsub"))

@testset "ClusterManagers.jl" begin
    if qsub_is_installed()
        @info "Running the SGE (via qsub) tests..." Sys.which("qsub")
        include("sge_qsub.jl")
    else
        if "sge_qsub" in test_args
            @error "ERROR: The SGE tests were explicitly requested in ARGS, but qsub was not found, so the SGE tests cannot be run" Sys.which("qsub") test_args
            @test false
        else
            @warn "qsub was not found - SGE tests will be skipped" Sys.which("qsub")
            @test_skip false
        end
    end

end # @testset
