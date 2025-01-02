using ClusterManagers: addprocs_slurm, SlurmManager

@testset "Slurm" begin
    out_file = "my_slurm_job.out"
    p = addprocs_slurm(1; o=out_file)
    @test nprocs() == 2
    @test workers() == p
    @test fetch(@spawnat :any myid()) == p[1]
    @test remotecall_fetch(+,p[1],1,1) == 2
    rmprocs(p)
    @test nprocs() == 1
    @test workers() == [1]
    
    # Check output file creation
    @test isfile(out_file)
    rm(out_file)
end
