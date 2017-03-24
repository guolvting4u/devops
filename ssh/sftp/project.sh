#!/bin/bash
#
# setup sftp project dir
#
# Usage: 
#   project.sh proj
#

jail='/var/jail'
proj=$1

chown -R root:root ${jail}/home/${proj}
chmod -R o-r ${jail}/home/${proj}
mkdir -p ${jail}/home/${proj}/data
chown -R ${proj}:${proj} ${jail}/home/${proj}/data
mkdir -p ${jail}/home/${proj}/data/delivery
chown -R sftp:sftp ${jail}/home/${proj}/data/delivery

mkdir -p ${jail}/data/projects/${proj}
if mount --bind \
    ${jail}/home/${proj}/data \
    ${jail}/data/projects/${proj}; then
    echo ${jail}/home/${proj}/data$'\t'${jail}/data/projects/${proj}$'\tnone\tbind\t0\t0' \
    | tee -a /etc/fstab
fi
