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


@static if Sys.iswindows()
    windows_which(command) = `powershell.exe -Command Get-Command $command`
    is_lsf_installed() = success(windows_which("bsub.exe"))
else
    is_lsf_installed() = success(`which bsub`)
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
