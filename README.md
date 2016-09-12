# ClusterManagers

Support for different job queue systems commonly used on compute clusters.

## Currently supported job queue systems

| Job queue system | Command to add processors |
| ---------------- | ------------------------- |
| Sun Grid Engine  | `addprocs_sge(np::Integer, queue="")` or `addprocs(SGEManager(np, queue))` |
| PBS              | `addprocs_pbs(np::Integer, queue="")` or `addprocs(PBSManager(np, queue))` |
| Scyld | `addprocs_scyld(np::Integer)` or `addprocs(ScyldManager(np))` |
| HTCondor | `addprocs_htc(np::Integer)` or `addprocs(HTCManager(np))` |
| Slurm | `addprocs_slurm(np::Integer; kwargs...)` or `addprocs(SlurmManager(np); kwargs...)` |
| Local manager with CPU affinity setting | `addprocs(LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities=[]); kwargs...)` |

You can also write your own custom cluster manager; see the instructions in the [Julia manual](http://docs.julialang.org/en/latest/manual/parallel-computing/#clustermanagers)

### Slurm: a simple example

```jl
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

```jl
julia> using ClusterManagers

julia> ClusterManagers.addprocs_sge(5)
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

### SGE - an example with resource list

Some clusters require to specify a list of required resources. Required memory has been an [issue for example.](https://github.com/JuliaLang/julia/issues/10390)

```jl
julia> using ClusterManagers

julia> addprocs_sge(5,res_list="h_vmem=4G,tmem=4G")
job id is 9827051, waiting for job to start ........
5-element Array{Int64,1}:
 22
 23
 24
 25
 26

julia> pmap(x->run(`hostname`),workers());

julia>  From worker 26: lum-7-2.local
        From worker 23: pace-6-10.local
        From worker 22: chong-207-10.local
        From worker 24: pace-6-11.local
        From worker 25: cheech-207-16.local
```

### Using `LocalAffinityManager` (for pinning local workers to specific cores)

- Linux only feature
- Requires the Linux `taskset` command to be installed
- Usage : `addprocs(LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities=[]); kwargs...)`

where

- `np` is the number of workers to be started
- `affinities` if specified, is a list of CPU IDs. As many workers as entries in `affinities` are launched. Each worker is pinned
to the specified CPU ID.
- `mode` (used only when `affinities` is not specified, can be either `COMPACT` or `BALANCED`) - `COMPACT` results in the requested number
of workers pinned to cores in increasing order, For example, worker1 => CPU0, worker2 => CPU1 and so on. `BALANCED` tries to spread
the workers. Useful when we have multiple CPU sockets, with each socket having multiple cores. A `BALANCED` mode results in workers
spread across CPU sockets. Default is `BALANCED`
