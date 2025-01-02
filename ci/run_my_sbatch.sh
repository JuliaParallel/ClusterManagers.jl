#!/bin/bash

set -euf -o pipefail

set -x

rm -fv "${HOME:?}/my_stdout.txt"
rm -fv "${HOME:?}/my_stderr.txt"

sbatch --wait --output="${HOME:?}/my_stdout.txt" --error="${HOME:?}/my_stderr.txt" ./ClusterManagers/ci/my_sbatch.sh
