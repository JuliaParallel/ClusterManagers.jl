#!/bin/bash

# start sge
#wait a bit for master configuration
sleep 3

sudo service gridengine-exec restart

sleep infinity
