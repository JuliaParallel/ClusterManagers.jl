## ClusterManagers - Support for different clustering technologies

Currently support exists for :

- Sun Grid Engine - via `addprocs_sge(np::Integer)` or `addprocs(SGEManager(np))`
                    and `addprocs_pbs(np::Integer)` or `addprocs(PBSManager(np))`

- Scyld - `addprocs_scyld(np::Integer)` or `addprocs(ScyldManager(np))`
- HTCondor - `addprocs_htc(np::Integer)` or `addprocs(HTCManager(np))`


### To write a custom cluster manager:

See section http://docs.julialang.org/en/latest/manual/parallel-computing/#clustermanagers
