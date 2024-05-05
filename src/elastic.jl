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
    manage_callback
    printing_kwargs

    function ElasticManager(;
        addr=IPv4("127.0.0.1"), port=9009, cookie=nothing,
        topology=:all_to_all, manage_callback=elastic_no_op_callback(), printing_kwargs=()
    )
        Distributed.init_multi()
        cookie !== nothing && cluster_cookie(cookie)

        # Automatically check for the IP address of the local machine
        if addr == :auto
            try
                addr = Sockets.getipaddr(IPv4)
            catch
                error("Failed to automatically get host's IP address. Please specify `addr=` explicitly.")
            end
        end
        
        l_sock = listen(addr, port)

        lman = new(Dict{Int, WorkerConfig}(), Channel{TCPSocket}(typemax(Int)), Set{Int}(), topology, getsockname(l_sock), manage_callback, printing_kwargs)

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

elastic_no_op_callback(::ElasticManager, ::Integer, ::Symbol) = nothing

function process_worker_conn(mgr::ElasticManager, s::TCPSocket)
    @debug "ElasticManager got new worker connection"
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
        @debug "ElasticManager.launch new worker"
        wc=WorkerConfig()
        wc.io = take!(mgr.pending)
        push!(launched, wc)
    end

    notify(c)
end

function manage(mgr::ElasticManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :register
        @debug "ElasticManager registering process id $id"
        mgr.active[id] = config
        mgr.manage_callback(mgr, id, op)
    elseif  op == :deregister
        @debug "ElasticManager deregistering process id $id"
        mgr.manage_callback(mgr, id, op)
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

    println(iob, "  Worker connect command : ")
    print(iob, "    ", get_connect_cmd(mgr; mgr.printing_kwargs...))
    
    print(io, String(take!(iob)))
end

# Same as Distributed.worker_timeout, but that doesn't seem to be public API:
elastic_worker_default_timeout() = parse(Float64, get(ENV, "JULIA_WORKER_TIMEOUT", "60.0"))

# Does not return. If executing from a REPL try
# @async elastic_worker(.....)
# addr, port that a ElasticManager on the master processes is listening on.
function elastic_worker(
    cookie::AbstractString, addr::AbstractString="127.0.0.1", port::Integer = 9009;
    stdout_to_master::Bool = true,
    Base.@nospecialize(worker_timeout::Real = elastic_worker_default_timeout())
)
    @debug "ElasticManager.elastic_worker(cookie, $addr, $port; stdout_to_master=$stdout_to_master, worker_timeout=$worker_timeout)"
    ENV["JULIA_WORKER_TIMEOUT"] = "$worker_timeout"
    c = connect(addr, port)
    write(c, rpad(cookie, HDR_COOKIE_LEN)[1:HDR_COOKIE_LEN])
    stdout_to_master && redirect_stdout(c)
    start_worker(c, cookie)
end

function get_connect_cmd(em::ElasticManager; absolute_exename=true, same_project=true)
    
    ip = string(em.sockname[1])
    port = convert(Int,em.sockname[2])
    cookie = cluster_cookie()
    exename = absolute_exename ? joinpath(Sys.BINDIR, Base.julia_exename()) : "julia"
    project = same_project ? ("--project=$(Pkg.API.Context().env.project_file)",) : ()
    
    join([
        exename,
        project...,
        "-e 'using ClusterManagers; ClusterManagers.elastic_worker(\"$cookie\",\"$ip\",$port)'"
    ]," ")
    
end
