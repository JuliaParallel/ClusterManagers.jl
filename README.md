## ClusterManagers - Support for different clustering technologies

Currently support exists for :

- Sun Grid Engine - via `addprocs_sge(np::Integer, queue="")` or `addprocs(SGEManager(np, queue))`
                    and `addprocs_pbs(np::Integer, queue="")` or `addprocs(PBSManager(np, queue))`

- Scyld - `addprocs_scyld(np::Integer)` or `addprocs(ScyldManager(np))`
- HTCondor - `addprocs_htc(np::Integer)` or `addprocs(HTCManager(np))`


### To write a custom cluster manager:

See section http://docs.julialang.org/en/latest/manual/parallel-computing/#clustermanagers
