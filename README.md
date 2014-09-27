## ClusterManagers - Support for different clustering technologies

Currently support exists for :

- Sun Grid Engine
- Scyld
- HTCondor

### To write a custom cluster manager:

The ``ClusterManager`` interface provides a
way to specify a means to launch and manage worker processes. 

Thus, a custom cluster manager would need to :

- be a subtype of the abstract ``ClusterManager``
- implement ``launch``, a method responsible for launching new workers
- implement ``manage``, which is called at various events during a worker's lifetime

As an example let us see how ScyldManager is implemented:

    immutable ScyldManager <: ClusterManager
    end

    function launch(manager::ScyldManager, np::Integer, config::Dict, resp_arr::Array, c::Condition)
        ...
    end

    function manage(manager::ScyldManager, id::Integer, config::Dict, op::Symbol)
        ...
    end

    
The ``launch`` method takes the following arguments:

    ``manager::ScyldManager`` - used to dispatch the call to the appropriate implementation 
    
    ``np::Integer`` - number of workers to be launched
    
    ``config::Dict`` - all the keyword arguments provided as part of the ``addprocs`` call
    
    ``resp_arr::Array`` - the array to append one or more worker information tuples to
    
    ``c::Condition`` - the condition variable to be notified as and when workers are launched
    
                       
The ``launch`` method is called asynchronously in a separate task. The termination of this task 
signals that all requested workers have been launched. Hence the ``launch`` function MUST exit as soon 
as all the requested workers have been launched.

Arrays of worker information tuples that are appended to ``resp_arr`` can take any one of 
the following forms:

```
    (io::IO, config::Dict)
    
    (io::IO, host::String, config::Dict)
    
    (io::IO, host::String, port::Integer, config::Dict)
    
    (host::String, port::Integer, config::Dict)
```

where:

- ``io::IO`` is the output stream of the worker.

- ``host::String`` and ``port::Integer`` are the host:port to connect to. If not provided
  they are read from the ``io`` stream provided.
  
- ``config::Dict`` is the configuration dictionary for the worker. The ``launch``
  function can add/modify any data that may be required for managing 
  the worker.
  

The ``manage`` method takes the following arguments:

- ``manager::ClusterManager`` - used to dispatch the call to the appropriate implementation

- ``id::Integer`` - The julia process id

- ``config::Dict`` - configuration dictionary for the worker. The data may have been modified 
                   by the ``launch`` method
               
- ``op::Symbol`` - The ``manage`` method is called at different times during the worker's lifetime.
                ``op`` is one of ``:register``, ``:deregister``, ``:interrupt`` or ``:finalize``
                ``manage`` is called with ``:register`` and ``:deregister`` when a worker is 
                added / removed from the julia worker pool. With ``:interrupt`` when 
                ``interrupt(workers)`` is called. The cluster manager should signal the appropriate 
                worker with an interrupt signal. With ``:finalize`` for cleanup purposes.
