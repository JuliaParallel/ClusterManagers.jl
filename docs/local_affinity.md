# Using `LocalAffinityManager` (for pinning local workers to specific cores)

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
