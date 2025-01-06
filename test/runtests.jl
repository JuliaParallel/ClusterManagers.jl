import ClusterManagers
import Test

import Distributed

# Bring some names into scope, just for convenience:
using Distributed: addprocs, rmprocs
using Distributed: workers, nworkers
using Distributed: procs, nprocs
using Distributed: remotecall_fetch, @spawnat
using Test: @testset, @test, @test_skip
# ElasticManager:
using ClusterManagers: ElasticManager
# Slurm:
using ClusterManagers: addprocs_slurm, SlurmManager
# SGE:
using ClusterManagers: addprocs_sge, SGEManager

const test_args = lowercase.(strip.(ARGS))

@info "" test_args

slurm_is_installed() = !isnothing(Sys.which("sbatch"))
qsub_is_installed() = !isnothing(Sys.which("qsub"))

@testset "ClusterManagers.jl" begin
    include("elastic.jl")

    if slurm_is_installed()
        @info "Running the Slurm tests..." Sys.which("sbatch")
        include("slurm.jl")
    else
        if "slurm" in test_args
            @error "ERROR: The Slurm tests were explicitly requested in ARGS, but sbatch was not found, so the Slurm tests cannot be run" Sys.which("sbatch") test_args
            @test false
        else
            @warn "sbatch was not found - Slurm tests will be skipped" Sys.which("sbatch")
            @test_skip false
        end
    end

    if qsub_is_installed()
        @info "Running the SGE (via qsub) tests..." Sys.which("qsub")
        include("slurm.jl")
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
