## ClusterManagers - Support for different clustering technologies

Currently support exists for :

- Sun Grid Engine

- Scyld

To write a custom cluster manager:

- Extend ClusterManager and expose ```launch_cb```

    ```
        immutable ScyldManager <: ClusterManager
            launch_cb::Function

            ScyldManager() = new(launch_scyld_workers)
        end
    ```

- Implement the callback
    ```
            function launch_scyld_workers(np::Integer, config::Dict)
                ...
            end
    ```

    ``config`` parameter in the callback is a Dict with the following keys - :dir, :exename, :exeflags, :tunnel, :sshflags, :cman 
    
    
    The callback can use these fields to launch the instances appropriately.

    The callback should return a Tuple consisting of the response type and an array of instance information

    i.e. one of

    - ```(:io_only, [io1, io2,..]) ```
    
    - ```(:io_host, [(io1, host1), (io2, host2), ...])  ```
    
    - ```(:io_host_port, [(io1, host1, port1), (io2, host2, port2), ...])  ```
    
    - ```(:host_port, [(host1, port1), (host2, port2), ...])  ```
    
    - ```(:cmd, [cmd1, cmd2, ...])  ```

    ```io``` above is an IO object wrapping of STDOUT of the launched worker processes. 
    ```cmd``` is a command object to be executed, which will launch the julia worker process
    ```host``` and ```port``` can be specified to override the host/port of the worker process 
    bound to. For example, when the launched worker is behind a NATed firewall.
    
