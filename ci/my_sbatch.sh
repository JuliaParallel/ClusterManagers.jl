#!/bin/bash

#SBATCH --ntasks=2
#SBATCH --time=00:10:00

julia --project=ClusterManagers -e 'using Pkg; Pkg.test(; test_args=["slurm"])'
