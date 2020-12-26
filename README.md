# ClusterManagers

Support for different job queue systems commonly used on compute clusters.

## Currently supported job queue systems

| Job queue system | Command to add processors |
| ---------------- | ------------------------- |
| Load Sharing Facility (LSF) | `addprocs_lsf(np::Integer; bsub_flags=``, ssh_cmd=``)` or `addprocs(LSFManager(np, bsub_flags, ssh_cmd, retry_delays, throttle))` |
| Sun Grid Engine  | `addprocs_sge(np::Integer, qsub_flags="")` or `addprocs(SGEManager(np, qsub_flags))` |
| SGE via qrsh | `addprocs_qrsh(np::Integer, qsub_flags="")` or `addprocs(QRSHManager(np, qsub_flags))` |
| PBS              | `addprocs_pbs(np::Integer, qsub_flags="")` or `addprocs(PBSManager(np, qsub_flags))` |
| Scyld | `addprocs_scyld(np::Integer)` or `addprocs(ScyldManager(np))` |
| HTCondor | `addprocs_htc(np::Integer)` or `addprocs(HTCManager(np))` |
| Slurm | `addprocs_slurm(np::Integer; kwargs...)` or `addprocs(SlurmManager(np); kwargs...)` |
| Local manager with CPU affinity setting | `addprocs(LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities=[]); kwargs...)` |

You can also write your own custom cluster manager; see the instructions in the [Julia manual](https://docs.julialang.org/en/v1/manual/distributed-computing/#ClusterManagers)

### Slurm: a simple example

```julia
using ClusterManagers

# Arguments to the Slurm srun(1) command can be given as keyword
# arguments to addprocs.  The argument name and value is translated to
# a srun(1) command line argument as follows:
# 1) If the length of the argument is 1 => "-arg value",
#    e.g. t="0:1:0" => "-t 0:1:0"
# 2) If the length of the argument is > 1 => "--arg=value"
#    e.g. time="0:1:0" => "--time=0:1:0"
# 3) If the value is the empty string, it becomes a flag value,
#    e.g. exclusive="" => "--exclusive"
# 4) If the argument contains "_", they are replaced with "-",
#    e.g. mem_per_cpu=100 => "--mem-per-cpu=100"
addprocs(SlurmManager(2), partition="debug", t="00:5:00")

hosts = []
pids = []
for i in workers()
	host, pid = fetch(@spawnat i (gethostname(), getpid()))
	push!(hosts, host)
	push!(pids, pid)
end

# The Slurm resource allocation is released when all the workers have
# exited
for i in workers()
	rmprocs(i)
end
```

### SGE - a simple interactive example

```julia
julia> using ClusterManagers

julia> ClusterManagers.addprocs_sge(5; qsub_flags=`-q queue_name`)
job id is 961, waiting for job to start .
5-element Array{Any,1}:
2
3
4
5
6

julia> @parallel for i=1:5
       run(`hostname`)
       end

julia>  From worker 2:  compute-6
        From worker 4:  compute-6
        From worker 5:  compute-6
        From worker 6:  compute-6
        From worker 3:  compute-6
```

Some clusters require the user to specify a list of required resources. 
For example, it may be necessary to specify how much memory will be needed by the job - see this [issue](https://github.com/JuliaLang/julia/issues/10390).
The keyword `queue` can be used to specify these and other options.
Additionally the keyword `wd` can be used to specify the working directory (which defaults to `ENV["HOME"]`).

```julia
julia> using Distributed, ClusterManagers

julia> addprocs_sge(5;queue=`-q queue_name -l h_vmem=4G,tmem=4G`, wd=mktempdir())
Job 5672349 in queue.
Running.
5-element Array{Int64,1}:
 2
 3
 4
 5
 6

julia> pmap(x->run(`hostname`),workers());

julia>  From worker 26: lum-7-2.local
        From worker 23: pace-6-10.local
        From worker 22: chong-207-10.local
        From worker 24: pace-6-11.local
        From worker 25: cheech-207-16.local

julia> rmprocs(workers())
Task (done)
```

### SGE via qrsh

`SGEManager` uses SGE's `qsub` command to launch workers, which communicate the
TCP/IP host:port info back to the master via the filesystem.  On filesystems
that are tuned to make heavy use of caching to increase throughput, launching
Julia workers can frequently timeout waiting for the standard output files to appear.
In this case, it's better to use the `QRSHManager`, which uses SGE's `qrsh`
command to bypass the filesystem and captures STDOUT directly.

### Load Sharing Facility (LSF)

`LSFManager` supports IBM's scheduler.  See the `addprocs_lsf` docstring
for more information.

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

On Linux and Mac, you can set `addr=:auto` to automatically use the host's private IP address on the local network, which will allow other workers on this network to connect. You can also use `port=0` to let the OS choose a random free port for you (some systems may not support this). Once created, printing the `ElasticManager` object prints the command which you can run on workers to connect them to the master, e.g.:

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
