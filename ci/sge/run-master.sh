#!/bin/bash


# start sge
sudo service gridengine-master restart

while ! ping -c1 slave_one &>/dev/null; do :; done
#Sometimes conf is inaccessible at first
while ! qconf -sconf &>/dev/null; do sleep 0.1; done
cat /var/lib/gridengine//default/common/act_qmaster

qconf -Msconf /scheduler.txt
qconf -Ahgrp /hosts.txt
qconf -Aq /queue.txt

qconf -ah slave_one
qconf -ah slave_two
qconf -ah slave_three

qconf -as $HOSTNAME
bash add_worker.sh dask.q slave_one 4
bash add_worker.sh dask.q slave_two 4

sudo service gridengine-master restart

sleep infinity
