# ClusterManager for HTCondor

export LocalAffinityManager, AffinityMode, COMPACT, BALANCED

@enum AffinityMode COMPACT BALANCED

mutable struct LocalAffinityManager <: ClusterManager
    affinities::Array{Int}

    function LocalAffinityManager(;np=Sys.CPU_THREADS, mode::AffinityMode=BALANCED, affinities::Array{Int}=[])
        @assert(Sys.Sys.KERNEL == :Linux)

        if length(affinities) == 0
            if mode == COMPACT
                affinities = [i%Sys.CPU_THREADS for i in 1:np]
            else
                # mode == BALANCED
                if np > 1
                    affinities = [Int(floor(i)) for i in range(0, stop=Sys.CPU_THREADS - 1e-3, length=np)]
                else
                    affinities = [0]
                end
            end
        end

        return new(affinities)
    end
end


function launch(manager::LocalAffinityManager, params::Dict, launched::Array, c::Condition)
    dir = params[:dir]
    exename = params[:exename]
    exeflags = params[:exeflags]

    for core_id in manager.affinities
        io = open(detach(
            setenv(`taskset -c $core_id $(Base.julia_cmd(exename)) $exeflags $(worker_arg())`, dir=dir)), "r")
        wconfig = WorkerConfig()
        wconfig.process = io
        wconfig.io = io.out
        push!(launched, wconfig)
    end

    notify(c)
end

function manage(manager::LocalAffinityManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :interrupt
        kill(get(config.process), 2)
    end
end

