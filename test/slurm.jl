@testset "Slurm" begin
    mktempdir() do tmpdir
        cd(tmpdir) do
            outfile = joinpath(tmpdir, "my_slurm_job.out")
            p = addprocs_slurm(1; o=outfile)
            @test nprocs() == 2
            @test workers() == p
            @test fetch(@spawnat :any myid()) == p[1]
            @test remotecall_fetch(+,p[1],1,1) == 2
            rmprocs(p)
            @test nprocs() == 1
            @test workers() == [1]
            
            # Check that `outfile` exists:
            @test isfile(outfile)
            # Check that `outfile` is not empty:
            outfile_contents = read(outfile, String)
            @test length(strip(outfile_contents)) > 5

            println(Base.stderr, "# BEGIN: contents of my_slurm_job.out")
            println(Base.stderr, outfile_contents)
            println(Base.stderr, "# END: contents of my_slurm_job.out")

            # No need to manually delete the `outfile` file.
            # The entire `tmpdir` will automatically be removed when the `mktempdir() do ...` block ends.
            # rm(outfile)
        end
    end
end
