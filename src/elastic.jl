# The master process listens on a well-known port
# Launched workers connect to the master and redirect their STDOUTs to the same
# Workers can join and leave the cluster on demand.

export ElasticManager, elastic_worker

const HDR_COOKIE_LEN = Distributed.HDR_COOKIE_LEN

struct ElasticManager <: ClusterManager
    active::Dict{Int, WorkerConfig}        # active workers
    pending::Channel{TCPSocket}          # to be added workers
    terminated::Set{Int}             # terminated worker ids
    topology::Symbol
    sockname

    function ElasticManager(;addr=IPv4("127.0.0.1"), port=9009, cookie=nothing, topology=:all_to_all)
        Distributed.init_multi()
        cookie !== nothing && cluster_cookie(cookie)

        l_sock = listen(addr, port)

        lman = new(Dict{Int, WorkerConfig}(), Channel{TCPSocket}(typemax(Int)), Set{Int}(), topology, getsockname(l_sock))

        @async begin
            while true
                let s = accept(l_sock)
                    @async process_worker_conn(lman, s)
                end
            end
        end

        @async process_pending_connections(lman)

        lman
    end
end

ElasticManager(port) = ElasticManager(;port=port)
ElasticManager(addr, port) = ElasticManager(;addr=addr, port=port)
ElasticManager(addr, port, cookie) = ElasticManager(;addr=addr, port=port, cookie=cookie)


function process_worker_conn(mgr::ElasticManager, s::TCPSocket)
    # Socket is the worker's STDOUT
    wc = WorkerConfig()
    wc.io = s

    # Validate cookie
    cookie = read(s, HDR_COOKIE_LEN)
    if length(cookie) < HDR_COOKIE_LEN
        error("Cookie read failed. Connection closed by peer.")
    end
    self_cookie = cluster_cookie()
    for i in 1:HDR_COOKIE_LEN
        if UInt8(self_cookie[i]) != cookie[i]
            println(i, " ", self_cookie[i], " ", cookie[i])
            error("Invalid cookie sent by remote worker.")
        end
    end

    put!(mgr.pending, s)
end

function process_pending_connections(mgr::ElasticManager)
    while true
        wait(mgr.pending)
        try
            addprocs(mgr; topology=mgr.topology)
        catch e
            showerror(stderr, e)
            Base.show_backtrace(stderr, Base.catch_backtrace())
        end
    end
end

function launch(mgr::ElasticManager, params::Dict, launched::Array, c::Condition)
    # The workers have already been started.
    while isready(mgr.pending)
        wc=WorkerConfig()
        wc.io = take!(mgr.pending)
        push!(launched, wc)
    end

    notify(c)
end

function manage(mgr::ElasticManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :register
        mgr.active[id] = config
    elseif  op == :deregister
        delete!(mgr.active, id)
        push!(mgr.terminated, id)
    end
end

function Base.show(io::IO, mgr::ElasticManager)
    iob = IOBuffer()

    println(iob, "ElasticManager:")
    print(iob, "  Active workers : [ ")
    for id in sort(collect(keys(mgr.active)))
        print(iob, id, ",")
    end
    seek(iob, position(iob)-1)
    println(iob, "]")

    println(iob, "  Number of workers to be added  : ", Base.n_avail(mgr.pending))

    print(iob, "  Terminated workers : [ ")
    for id in sort(collect(mgr.terminated))
        print(iob, id, ",")
    end
    seek(iob, position(iob)-1)
    println(iob, "]")

    print(io, String(take!(iob)))
end

# Does not return. If executing from a REPL try
# @async connect_to_cluster(.....)
# addr, port that a ElasticManager on the master processes is listening on.
function elastic_worker(cookie, addr="127.0.0.1", port=9009; stdout_to_master=true)
    c = connect(addr, port)
    write(c, rpad(cookie, HDR_COOKIE_LEN)[1:HDR_COOKIE_LEN])
    stdout_to_master && redirect_stdout(c)
    start_worker(c, cookie)
end
