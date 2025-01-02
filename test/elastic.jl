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
