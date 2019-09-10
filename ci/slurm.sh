#!/usr/bin/env bash

function jobqueue_before_install {
    docker version
    docker-compose version

    # start slurm cluster
    pushd ./ci/slurm
    ./start-slurm.sh
    popd

    docker ps -a
    docker images
}

function jobqueue_install {
    docker exec -it slurmctld /bin/bash -c "cd /workspace; julia --project -e 'using Pkg; Pkg.build();"
}

function jobqueue_script {
    docker exec -it slurmctld /bin/bash -c "cd /workspace; julia --project test/runtests.jl slurm"
}

function jobqueue_after_script {
    docker exec -it slurmctld bash -c 'sinfo'
    docker exec -it slurmctld bash -c 'squeue'
    docker exec -it slurmctld bash -c 'sacct -l'
}
