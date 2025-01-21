function addprocs_autodetect_current_scheduler(; kwargs...)
    sched = _autodetect_is_slurm()
    if sched == :slurm
        return addprocs(SlurmClusterManager.SlurmManager(); kwargs...)
    elseif sched == :sge
        np = _sge_get_number_of_tasks()
        return addprocs_sge(np; kwargs...)
    elseif sched == :pbs
        np = _torque_get_numtasks()
        return addprocs_pbs(np; kwargs...)
    end
    error("Unable to auto-detect cluster scheduler: $(sched)")
end

function autodetect_current_scheduler()
    if _autodetect_is_slurm()
        return :slurm
    elseif _autodetect_is_sge()
        return :sge
    elseif _autodetect_is_pbs()
        return :pbs
    end
    return nothing
end

##### Slurm:

function _autodetect_is_slurm()
    has_SLURM_JOB_ID = _has_env_nonempty("SLURM_JOB_ID")
    has_SLURM_JOBID = _has_env_nonempty("SLURM_JOBID")
    res = has_SLURM_JOB_ID || has_SLURM_JOBID
    return res
end

##### SGE (Sun Grid Engine):

function _autodetect_is_sge()
    # https://docs.oracle.com/cd/E19957-01/820-0699/chp4-21/index.html
    has_SGE_O_HOST = _has_env_nonempty("SGE_O_HOST")
    return has_SGE_O_HOST

    # Important note:
    # The "job ID" environment variable in SGE is just named `JOB_ID`.
    # This is obviously too vague, because the variable name is not specific to SGE.
    # Therefore, we can't use that variable for our SGE auto-detection.
end

function _sge_get_numtasks()
    msg = "Because this is Sun Grid Engine (SGE), ClusterManagers.jl is not able " *
            "to correctly auto-detect the number of tasks. " *
            "Therefore, ClusterManagers.jl will instead use the value of the " *
            "NHOSTS environment variable: $(np)"
    @warn msg

    # https://docs.oracle.com/cd/E19957-01/820-0699/chp4-21/index.html
    name = "NHOSTS"
    value_int = _getenv_parse_int(name)
    return value_int
end

##### PBS and Torque:

function _autodetect_is_pbs()
    # https://docs.adaptivecomputing.com/torque/2-5-12/help.htm#topics/2-jobs/exportedBatchEnvVar.htm
    has_PBS_JOBID = _has_env_nonempty("PBS_JOBID")
    return has_PBS_JOBID
end

function _torque_get_numtasks()
    # https://docs.adaptivecomputing.com/torque/2-5-12/help.htm#topics/2-jobs/exportedBatchEnvVar.htm
    name = "PBS_TASKNUM"
    value_int = _getenv_parse_int(name)
    return value_int

    @info "Using auto-detected num_tasks: $(np)"
end

##### General utility functions:

function _getenv_parse_int(name::AbstractString)
    if !haskey(ENV, name)
        msg = "Environment variable is not defined: $(name)"
        error(msg)
    end
    original_value = ENV[name]
    if isempty(original_value)
        msg = "Environment variable is defined, but is empty: $(name)"
        error(msg)
    end
    stripped_value_str = strip(original_value)
    if isempty(stripped_value)
        msg = "Environment variable is defined, but contains only whitespace: $(name)"
        error(msg)
    end
    value_int = tryparse(Int, stripped_value_str)
    if !(value_int isa Int)
        msg =
            "Environment variable \"$(name)\" is defined, " *
            "but its value \"$(stripped_value_str)\" could not be parsed as an integer."
        error(msg)
    end
    return value_int
end
