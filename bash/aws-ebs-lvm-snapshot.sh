#!/bin/bash

SNAP_CMD=/usr/local/ec2/bin/ec2-create-snapshot
MOUNT_POINT=/mail
export JAVA_HOME=/usr/lib/jvm/java-6-sun-1.6.0.06
export EC2_CERT=/mnt/aws-config/cert-XXXX.pem
export EC2_HOME=/usr/local/ec2
export EC2_PRIVATE_KEY=/mnt/aws-config/pk-XXXX.pem

vols=("vol-xxxx" "vol-xxxx" "vol-xxxx")
i=0
xfs_freeze -f $MOUNT_POINT

for vol in ${vols[@]}
do
        $SNAP_CMD $vol &
        pids[i]=$!
        let i+=1
done

for pid in ${pids[@]}
do
        wait $pid
done

xfs_freeze -u $MOUNT_POINT
