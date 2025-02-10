# ClusterManagers.jl

The `ClusterManagers.jl` package implements code for different job queue systems commonly used on compute clusters.

> [!WARNING]
> This package is not currently being actively maintained or tested.
>
> We are in the process of splitting this package up into multiple smaller packages, with a separate package for each job queue systems.
>
> We are seeking maintainers for these new packages. If you are an active user of any of the job queue systems listed below and are interested in being a maintainer, please open a GitHub issue - say that you are interested in being a maintainer, and specify which job queue system you use.

## Available job queue systems

The following managers are implemented in this package (the `ClusterManagers.jl` package):

| Job queue system | Command to add processors |
| ---------------- | ------------------------- |
| Local manager with CPU affinity setting | `addprocs(LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities=[]); kwargs...)` |

### Implemented in external packages

| Job queue system | External package | Command to add processors |
| ---------------- | ---------------- | ------------------------- |
| Slurm | [SlurmClusterManager.jl](https://github.com/JuliaParallel/SlurmClusterManager.jl) | `addprocs(SlurmManager(); kwargs...)` |
| Load Sharing Facility (LSF) | [LSFClusterManager.jl](https://github.com/JuliaParallel/LSFClusterManager.jl) | `addprocs_lsf(np::Integer; bsub_flags=``, ssh_cmd=``)` or `addprocs(LSFManager(np, bsub_flags, ssh_cmd, retry_delays, throttle))` |
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

- Linux only feature.
- Requires the Linux `taskset` command to be installed.
- Usage : `addprocs(LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities=[]); kwargs...)`.

where

- `np` is the number of workers to be started.
- `affinities`, if specified, is a list of CPU IDs. As many workers as entries in `affinities` are launched. Each worker is pinned
to the specified CPU ID.
- `mode` (used only when `affinities` is not specified, can be either `COMPACT` or `BALANCED`) - `COMPACT` results in the requested number
of workers pinned to cores in increasing order, For example, worker1 => CPU0, worker2 => CPU1 and so on. `BALANCED` tries to spread
the workers. Useful when we have multiple CPU sockets, with each socket having multiple cores. A `BALANCED` mode results in workers
spread across CPU sockets. Default is `BALANCED`.

### Using `ElasticManager` (dynamically adding workers to a cluster)

The `ElasticManager` is useful in scenarios where we want to dynamically add workers to a cluster.
It achieves this by listening on a known port on the master. The launched workers connect to this
port and publish their own host/port information for other workers to connect to.

On the master, you need to instantiate an instance of `ElasticManager`. The constructors defined are:

```julia
ElasticManager(;addr=IPv4("127.0.0.1"), port=9009, cookie=nothing, topology=:all_to_all, printing_kwargs=())
ElasticManager(port) = ElasticManager(;port=port)
ElasticManager(addr, port) = ElasticManager(;addr=addr, port=port)
ElasticManager(addr, port, cookie) = ElasticManager(;addr=addr, port=port, cookie=cookie)
```

You can set `addr=:auto` to automatically use the host's private IP address on the local network, which will allow other workers on this network to connect. You can also use `port=0` to let the OS choose a random free port for you (some systems may not support this). Once created, printing the `ElasticManager` object prints the command which you can run on workers to connect them to the master, e.g.:

```julia
julia> em = ElasticManager(addr=:auto, port=0)
ElasticManager:
  Active workers : []
  Number of workers to be added  : 0
  Terminated workers : []
  Worker connect command :
    /home/user/bin/julia --project=/home/user/myproject/Project.toml -e 'using ClusterManagers; ClusterManagers.elastic_worker("4cOSyaYpgSl6BC0C","127.0.1.1",36275)'
```

By default, the printed command uses the absolute path to the current Julia executable and activates the same project as the current session. You can change either of these defaults by passing `printing_kwargs=(absolute_exename=false, same_project=false))` to the first form of the `ElasticManager` constructor.

Once workers are connected, you can print the `em` object again to see them added to the list of active workers.

### Sun Grid Engine (SGE)

See [`docs/sge.md`](docs/sge.md)
