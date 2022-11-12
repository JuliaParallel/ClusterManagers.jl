#!/bin/env julia

# Arguments:
# --connect-to=host:port
# --interface=interface
# -e ??

import Distributed
import Distributed: LPROC
using Sockets
Distributed.init_multi()
close(stdin) # workers will not use it

cookie = ARGS[end]
Distributed.init_worker(cookie)

function start_worker()
    interface = IPv4(LPROC.bind_addr)
    if LPROC.bind_port == 0
        port_hint = 9000 + (getpid() % 1000)
        (port, sock) = listenany(interface, UInt16(port_hint))
        LPROC.bind_port = port
    else
        sock = listen(interface, LPROC.bind_port)
    end

    Base.errormonitor(@async while isopen(sock)
        client = accept(sock)
        Distributed.process_messages(client, client, true)
    end)

    Sockets.nagle(sock, false)
    Sockets.quickack(sock, true)
    return interface, port
end

interface, worker_port = start_worker()

# Connect to primary and send it our network address
# TODO: Parse from cmd-line
let master = connect(addr, port)
    send_worker_info(master, interface, worker_port)
    close(master)
end

try
    # To prevent hanging processes on remote machines, newly launched workers exit if the
    # master process does not connect in time.
    Distributed.check_master_connect()
    while true; wait(); end
catch err
    print(stderr, "unhandled exception on $(myid()): $(err)\nexiting.\n")
end

close(sock)
exit(0)
