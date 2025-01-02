import ClusterManagers
import Test

import Distributed

# Bring some names into scope, just for convenience
using Distributed: remotecall_fetch
using Test: @testset, @test, @test_skip

slurm_is_installed() = !isnothing(Sys.which("sbatch"))
lsf_is_installed() = !isnothing(Sys.which("bsub"))
qsub_is_installed() = !isnothing(Sys.which("qsub"))

include("elastic.jl")

if slurm_is_installed()
    @info "Running the Slurm tests..." Sys.which("sbatch")
    include("slurm.jl")
else
    @warn "sbatch was not found - Slurm tests will be skipped" Sys.which("sbatch")
    @test_skip false
end

if lsf_is_installed()
    @info "Running the LSF tests..." Sys.which("bsub")
    include("lsf.jl")
else
    @warn "bsub was not found - LSF tests will be skipped" Sys.which("bsub")
    @test_skip false
end

if qsub_is_installed()
    @info "Running the SGE tests..." Sys.which("qsub")
    include("slurm.jl")
else
    @warn "qsub was not found - SGE tests will be skipped" Sys.which("qsub")
    @test_skip false
end
