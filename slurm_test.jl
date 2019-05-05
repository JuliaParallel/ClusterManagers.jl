
using ClusterManagers

addprocs_slurm(4; exeflags=["--project=$(project)", "--color=$(color_opt)"], job_file_loc="test_loc")

@sync begin
    @async @sync for job_id in collect(1:100) @spawn begin
        @info "Hello World $(job_id)"
    end
    end
end



