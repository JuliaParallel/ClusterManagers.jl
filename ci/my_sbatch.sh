#!/bin/bash

#SBATCH --ntasks=2
#SBATCH --time=00:10:00

# Important note:
# There should be no non-comment non-whitespace lines above this line.

set -euf -o pipefail

set -x

julia --project=ClusterManagers -e 'import Pkg; Pkg.test(; test_args=["slurm"])'
