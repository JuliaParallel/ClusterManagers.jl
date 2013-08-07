## ClusterManagers - Support for different clustering technologies

Currently support exists for :

- Sun Grid Engine
- Scyld

### To write a custom cluster manager:

- Extend ClusterManager and expose ```launch``` and ```manage```

    ```
        immutable ScyldManager <: ClusterManager
            launch::Function
            manage::Function

            ScyldManager() = new(launch_scyld_workers, manage_scyld_worker)
        end
    ```

- Implement the callbacks
    ```
            function launch_scyld_workers(cman::ScyldManager, np::Integer, config::Dict)
                ...
            end

            function manage_scyld_worker(id::Integer, config::Dict, op::Symbol)
                ...
            end
    ```

    ``config`` parameter in the callback is a Dict with the following keys - :dir, :exename, :exeflags, :tunnel, :sshflags

    The callback can use these fields to launch the instances appropriately.

    The callback should return a Tuple consisting of the response type and an array of tuples containing instance information and configuration

    i.e. one of

    - ```(:io_only, [(io1, config1), (io2, config2), ...])```
    
    - ```(:io_host, [(io1, host1, config1), (io2, host2, config2), ...])```
    
    - ```(:io_host_port, [(io1, host1, port1, config1), (io2, host2, port2, config2), ...])```
    
    - ```(:host_port, [(host1, port1, config1), (host2, port2, config2), ...])```
    
    - ```(:cmd, [(cmd1, config1), (cmd2, config2), ...])```

    ```io``` above is an IO object wrapping of STDOUT of the launched worker process. 
   
    ```config``` is a dictionary containing the configuration of the worker process.

    ```cmd``` is a command object to be executed, which will launch the julia worker process.
    
    ```host``` and ```port``` can be specified to override the host/port of the worker process 
    bound to. For example, when the launched worker is behind a NATed firewall.
    
