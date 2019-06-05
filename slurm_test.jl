#!/cvmfs/soft.computecanada.ca/easybuild/software/2017/avx512/Compiler/gcc7.3/julia/1.1.0/bin/julia
#SBATCH --time=00:05:00 # Running time of hours
#SBATCH --ntasks=4
#SBATCH --account=def-whitem


using Logging, Distributed

include("/home/mkschleg/mkschleg/ClusterManagers.jl/src/ClusterManagers.jl")

ClusterManagers.addprocs_slurm(4; exeflags=["--project=.", "--color=yes"], job_file_loc="test_loc")

@sync begin
    @async @sync for job_id in collect(1:100) @spawn begin
        println("Hello World $(job_id)")
    end
    end
end



