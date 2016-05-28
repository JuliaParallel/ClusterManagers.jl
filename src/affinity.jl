# ClusterManager for HTCondor

export LocalAffinityManager, AffinityMode, COMPACT, BALANCED

@enum AffinityMode COMPACT BALANCED

type LocalAffinityManager <: ClusterManager
    affinities::Array{Int}

    function LocalAffinityManager(;np=CPU_CORES, mode::AffinityMode=BALANCED, affinities::Array{Int}=[])
        assert(Sys.OS_NAME == :Linux)

        if length(affinities) == 0
            if mode == COMPACT
                affinities = [i%CPU_CORES for i in 1:np]
            else
                # mode == BALANCED
                if np > 1
                    affinities = [Int(floor(i)) for i in linspace(0, CPU_CORES - 1e-3, np)]
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
        io, pobj = open(detach(
            setenv(`taskset -c $core_id $(Base.julia_cmd(exename)) $exeflags $worker_arg`, dir=dir)), "r")
        wconfig = WorkerConfig()
        wconfig.process = pobj
        wconfig.io = io
        push!(launched, wconfig)
    end

    notify(c)
end

function manage(manager::LocalAffinityManager, id::Integer, config::WorkerConfig, op::Symbol)
    if op == :interrupt
        kill(get(config.process), 2)
    end
end

