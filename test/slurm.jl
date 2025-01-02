@testset "Slurm" begin
    mktempdir() do tmpdir
        cd(tmpdir) do
            out_file = joinpath(tmpdir, "my_slurm_job.out")
            p = addprocs_slurm(1; o=out_file)
            @test nprocs() == 2
            @test workers() == p
            @test fetch(@spawnat :any myid()) == p[1]
            @test remotecall_fetch(+,p[1],1,1) == 2
            rmprocs(p)
            @test nprocs() == 1
            @test workers() == [1]
            
            # Check that the `out_file` file exists:
            @test isfile(out_file)
            # Check that the `out_file` is not empty:
            @test length(strip(read(out_file, String))) > 5
            rm(out_file)
        end
    end
end
