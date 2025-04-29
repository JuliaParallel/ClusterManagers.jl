# ClusterManagers.jl

The `ClusterManagers.jl` package implements code for different job queue systems commonly used on compute clusters.

> [!WARNING]
> This package is not currently being actively maintained or tested.
>
> We are in the process of splitting this package up into multiple smaller packages, with a separate package for each job queue systems.
>
> We are seeking maintainers for these new packages. If you are an active user of any of the job queue systems listed below and are interested in being a maintainer, please open a GitHub issue - say that you are interested in being a maintainer, and specify which job queue system you use.

## Available job queue systems

### In this package

The following managers are implemented in this package (the `ClusterManagers.jl` package):

| Job queue system | Command to add processors |
| ---------------- | ------------------------- |
| Local manager with CPU affinity setting | `addprocs(LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities=[]); kwargs...)` |

### Implemented in external packages

| Job queue system | External package | Command to add processors |
| ---------------- | ---------------- | ------------------------- |
| Slurm | [SlurmClusterManager.jl](https://github.com/JuliaParallel/SlurmClusterManager.jl) | `addprocs(SlurmManager(); kwargs...)` |
| Load Sharing Facility (LSF) | [LSFClusterManager.jl](https://github.com/JuliaParallel/LSFClusterManager.jl) | `addprocs_lsf(np::Integer; bsub_flags=``, ssh_cmd=``)` or `addprocs(LSFManager(np, bsub_flags, ssh_cmd, retry_delays, throttle))` |
| ElasticManager | [ElasticClusterManager.jl](https://github.com/JuliaParallel/ElasticClusterManager.jl) | `addprocs(ElasticManager(...); kwargs...)` |
| Kubernetes (K8s) | [K8sClusterManagers.jl](https://github.com/beacon-biosignals/K8sClusterManagers.jl) | `addprocs(K8sClusterManager(np; kwargs...))` |
| Azure scale-sets | [AzManagers.jl](https://github.com/ChevronETC/AzManagers.jl) | `addprocs(vmtemplate, n; kwargs...)` |

### Not currently being actively maintained

> [!WARNING]
> The following managers are not currently being actively maintained or tested.
>
> We are seeking maintainers for the following managers. If you are an active user of any of the following job queue systems listed and are interested in being a maintainer, please open a GitHub issue - say that you are interested in being a maintainer, and specify which job queue system you use.
>

| Job queue system | Command to add processors |
| ---------------- | ------------------------- |
| Sun Grid Engine (SGE) via `qsub` | `addprocs_sge(np::Integer; qsub_flags=``)` or `addprocs(SGEManager(np, qsub_flags))` |
| Sun Grid Engine (SGE) via `qrsh` | `addprocs_qrsh(np::Integer; qsub_flags=``)` or `addprocs(QRSHManager(np, qsub_flags))` |
| PBS (Portable Batch System) | `addprocs_pbs(np::Integer; qsub_flags=``)` or `addprocs(PBSManager(np, qsub_flags))` |
| Scyld | `addprocs_scyld(np::Integer)` or `addprocs(ScyldManager(np))` |
| HTCondor | `addprocs_htc(np::Integer)` or `addprocs(HTCManager(np))` |

### Custom managers

You can also write your own custom cluster manager; see the instructions in the [Julia manual](https://docs.julialang.org/en/v1/manual/distributed-computing/#ClusterManagers).

## Notes on specific managers

### Slurm: please see [SlurmClusterManager.jl](https://github.com/JuliaParallel/SlurmClusterManager.jl)

For Slurm, please see the [SlurmClusterManager.jl](https://github.com/JuliaParallel/SlurmClusterManager.jl) package.

### Using `LocalAffinityManager` (for pinning local workers to specific cores)

See [`docs/local_affinity.md`](docs/local_affinity.md)

### Using `ElasticManager` (dynamically adding workers to a cluster)

For `ElasticManager`, please see the [ElasticClusterManager.jl](https://github.com/JuliaParallel/ElasticClusterManager.jl) package.

### Sun Grid Engine (SGE)

See [`docs/sge.md`](docs/sge.md)
