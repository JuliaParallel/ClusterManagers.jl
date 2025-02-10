# Sun Grid Engine (SGE)

> [!WARNING]
> The SGE functionality is not currently being maintained.
>
> We are currently seeking a new maintainer for the SGE functionality. If you are an active user of SGE and are interested in being a maintainer, please open a GitHub issue - say that you are interested in being a maintainer for the SGE functionality.

## SGE via `qsub`: Use `ClusterManagers.addprocs_sge` (or `ClusterManagers.SGEManager`)

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
The keyword `qsub_flags` can be used to specify these and other options.
Additionally the keyword `wd` can be used to specify the working directory (which defaults to `ENV["HOME"]`).

```julia
julia> using Distributed, ClusterManagers

julia> addprocs_sge(5; qsub_flags=`-q queue_name -l h_vmem=4G,tmem=4G`, wd=mktempdir())
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

## SGE via `qrsh`: Use `ClusterManagers.addprocs_qrsh` (or `ClusterManagers.QRSHManager`)

`SGEManager` uses SGE's `qsub` command to launch workers, which communicate the
TCP/IP host:port info back to the master via the filesystem.  On filesystems
that are tuned to make heavy use of caching to increase throughput, launching
Julia workers can frequently timeout waiting for the standard output files to appear.
In this case, it's better to use the `QRSHManager`, which uses SGE's `qrsh`
command to bypass the filesystem and captures STDOUT directly.
