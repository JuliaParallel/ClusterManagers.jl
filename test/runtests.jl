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
	@info ""
	include("slurm.jl")
else
    @warn "sbatch was not found - Slurm tests will be skipped" Sys.which("sbatch")
    @test_skip false
end

if is_lsf_installed()



end
    
if lsf_is_installed()
	@info ""
	include("lsf.jl")
else
    @warn "sbatch was not found - Slurm tests will be skipped" Sys.which("sbatch")
    @test_skip false
end

if slurm_is_installed()
	@info ""
	include("slurm.jl")
else
    @warn "sbatch was not found - Slurm tests will be skipped" Sys.which("sbatch")
    @test_skip false
end





if is_sge_installed()
  @testset "SGEManager" begin
    p = addprocs_sge(1, queue=``)
    @test nprocs() == 2
    @test workers() == p
    @test fetch(@spawnat :any myid()) == p[1]
    @test remotecall_fetch(+,p[1],1,1) == 2
    rmprocs(p)
    @test nprocs() == 1
    @test workers() == [1]
  end
end
