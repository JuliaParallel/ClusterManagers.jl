## ClusterManagers - Support for different clustering technologies

Currently support exists for :

- Sun Grid Engine - via `addprocs_sge(np::Integer, queue="")` or `addprocs(SGEManager(np, queue))`
                    and `addprocs_pbs(np::Integer, queue="")` or `addprocs(PBSManager(np, queue))`

- Scyld - `addprocs_scyld(np::Integer)` or `addprocs(ScyldManager(np))`
- HTCondor - `addprocs_htc(np::Integer)` or `addprocs(HTCManager(np))`
- Slurm - `addprocs_slurm(np::Integer; kwargs...)` or `addprocs(SlurmManager(np); kwargs...)`


### To write a custom cluster manager:

See section http://docs.julialang.org/en/latest/manual/parallel-computing/#clustermanagers

### Example usage (for the Slurm cluster manager)

<pre><code>
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
</code></pre>
