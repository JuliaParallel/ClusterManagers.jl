import ClusterManagers
import Test

import Distributed

# Bring some names into scope, just for convenience
using Distributed: rmprocs, remotecall_fetch, workers, @spawnat
using Test: @testset, @test, @test_skip

# Slurm:
using ClusterManagers: addprocs_slurm, SlurmManager
# 

const test_args = lowercase.(strip.(ARGS))

@info "" test_args

slurm_is_installed() = !isnothing(Sys.which("sbatch"))
lsf_is_installed() = !isnothing(Sys.which("bsub"))
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
    
    if lsf_is_installed()
        @info "Running the LSF tests..." Sys.which("bsub")
        include("lsf.jl")
    else
        if "lsf" in test_args
            @error "ERROR: The LSF tests were explicitly requested in ARGS, but bsub was not found, so the LSF tests cannot be run" Sys.which("bsub") test_args
            @test false
        else
            @warn "bsub was not found - LSF tests will be skipped" Sys.which("bsub")
            @test_skip false
        end
    end
    
    if qsub_is_installed()
        @info "Running the SGE tests..." Sys.which("qsub")
        include("slurm.jl")
    else
        if "slurm" in test_args
            @error "ERROR: The SGE tests were explicitly requested in ARGS, but qsub was not found, so the SGE tests cannot be run" Sys.which("qsub") test_args
            @test false
        else
            @warn "qsub was not found - SGE tests will be skipped" Sys.which("qsub")
            @test_skip false
        end
    end

end # @testset
