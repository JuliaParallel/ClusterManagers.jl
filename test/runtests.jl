using Test
using ClusterManagers
using Distributed

@testset "ElasticManager" begin
    TIMEOUT = 10.

    em = ElasticManager(addr=:auto, port=0)

    # launch worker
    run(`sh -c $(ClusterManagers.get_connect_cmd(em))`, wait=false)

    # wait at most TIMEOUT seconds for it to connect
    @test :ok == timedwait(TIMEOUT) do
        length(em.active) == 1
    end

    wait(rmprocs(workers()))
end

if "slurm" in ARGS
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
end

@static if Sys.iswindows()
    windows_which(command) = `powershell.exe -Command Get-Command $command`
    is_lsf_installed() = success(windows_which("bsub.exe"))
    is_sge_installed() = success(windows_which("qsub.exe"))
else
    is_lsf_installed() = success(`which bsub`)
    is_sge_installed() = success(`which qsub`)
end

if is_lsf_installed()

@testset "LSFManager" begin
    p = addprocs_lsf(1, bsub_flags=`-P scicompsoft`)
    @test nprocs() == 2
    @test workers() == p
    @test fetch(@spawnat :any myid()) == p[1]
    @test remotecall_fetch(+,p[1],1,1) == 2
    rmprocs(p)
    @test nprocs() == 1
    @test workers() == [1]
end

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
