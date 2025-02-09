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

    @testset "show(io, ::ElasticManager)" begin
        str = sprint(show, em)
        lines = strip.(split(strip(str), '\n'))
        @test lines[1] == "ElasticManager:"
        @test lines[2] == "Active workers : []"
        @test lines[3] == "Number of workers to be added  : 0"
        @test lines[4] == "Terminated workers : [ 2]"
        @test lines[5] == "Worker connect command :"
    end
end
