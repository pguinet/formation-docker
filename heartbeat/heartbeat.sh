#!/bin/bash
set -e
trap "echo SIGNAL" HUP INT QUIT KILL TERM

while true;
do
    echo $1 \($(date +%H:%M:%S)\);
    sleep "$HEARTBEATSTEP"
done

