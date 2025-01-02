@testset "SGEManager (addprocs_sge via qsub)" begin
    p = addprocs_sge(1, queue=``)
    @test nprocs() == 2
    @test workers() == p
    @test fetch(@spawnat :any myid()) == p[1]
    @test remotecall_fetch(+,p[1],1,1) == 2
    rmprocs(p)
    @test nprocs() == 1
    @test workers() == [1]
end
