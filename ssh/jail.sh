#!/bin/bash
#
# setup ssh jail
#
# Usage:
#     jail.sh setup gate
#     jail.sh setup jail
#     jail.sh crew [user] [role]
#     jail.sh role [role] [user]
#     jail.sh esc crew [user]
#     jail.sh esc role [role]
#

# source ${BASH_SOURCE%/*}/vars.sh
jail='/var/jail'
gate='/etc/ssh/gate'
pubs='https://raw.githubusercontent.com/figroc/devops/master/pub'

# functions
function chroot_cmds {
    for cmd in $2; do
        cp $1/${cmd} ${jail}/$1/
        l2chroot $1/${cmd}
    done
}

function shadow_home {
    if [ -z $2 ]; then
        sed -i '/^'$1':.*/s@:'${jail}'@:@' /etc/passwd
    else
        sed -i '/^'$1'\.'$2':.*/s@:'${jail}'@:@' /etc/passwd
    fi
}

function shadow_user {
    if [ -z $2 ]; then
        sed -i '/^'$1':.*/d' ${jail}/etc/passwd
        grep '^'$1':' /etc/passwd | tee -a ${jail}/etc/passwd
    else
        sed -i '/^'$1'\.'$2':.*/d' ${jail}/etc/passwd
        grep '^'$1'\.'$2':' /etc/passwd | tee -a ${jail}/etc/passwd
    fi
}

function shadow_group {
    while (($#)); do
        sed -i '/^'$1':.*/d' ${jail}/etc/group
        grep '^'$1':' /etc/group | tee -a ${jail}/etc/group
        shift
    done
}

# command switch
case $1 in
    setup)
        case $2 in
            gate)
                mkdir -p ${gate}/{sys,roles,crews}
                chown devops:devops ${gate}/sys/
                ;;

            jail)
                cmds='bash sh'
                cmdu='ssh ssh-agent scp sftp rssh'
                libu='openssh/sftp-server rssh/rssh_chroot_helper'

                # tools
                if apt-get install rssh; then
                    sed -i '/^# chrootpath = .*/s@@chrootpath = '${jail}'@' /etc/rssh.conf
                fi
                if wget -O /sbin/l2chroot https://www.cyberciti.biz/files/lighttpd/l2chroot.txt; then
                    sed -i '/^BASE=.*/s@@BASE="'${jail}'"@' /sbin/l2chroot
                    chown root:root /sbin/l2chroot
                    chmod +x /sbin/l2chroot
                fi

                # dirs
                mkdir -p ${jail}/{dev,etc,lib,lib64,usr,bin,home}
                mkdir -p ${jail}/usr/{bin,lib}
                mkdir -p ${jail}/usr/etc/ssh
                mkdir -p ${jail}/usr/lib/{openssh,rssh}
                chown root:root ${jail}
                chmod go-w ${jail}
                chmod o-r ${jail} ${jail}/home

                # devices
                mknod -m 622 ${jail}/dev/console c 5 1
                mknod -m 666 ${jail}/dev/null c 1 3
                mknod -m 666 ${jail}/dev/zero c 1 5
                mknod -m 666 ${jail}/dev/ptmx c 5 2
                mknod -m 666 ${jail}/dev/tty c 5 0
                mknod -m 444 ${jail}/dev/random c 1 8
                mknod -m 444 ${jail}/dev/urandom c 1 9
                chown root:tty ${jail}/dev/{console,ptmx,tty}
                ln -s /proc/self/fd ${jail}/dev/fd
                ln -s /proc/self/fd/0 ${jail}/dev/stdin
                ln -s /proc/self/fd/1 ${jail}/dev/stdout
                ln -s /proc/self/fd/2 ${jail}/dev/stderr
                ln -s /proc/kcore ${jail}/dev/core
                mkdir -p ${jail}/dev/{pts,shm}
                mount -vt devpts -o gid=4,mode=620 none ${jail}/dev/pts
                mount -vt tmpfs none ${jail}/dev/shm

                # files
                cp -ar /etc/ld.so.conf.d ${jail}/etc/
                cp /etc/ld.so.cache ${jail}/etc/
                cp /etc/ld.so.conf ${jail}/etc/
                cp /etc/resolv.conf ${jail}/etc/
                cp /etc/hosts ${jail}/etc/
                touch ${jail}/etc/{group,passwd}
                cp /etc/nsswitch.conf ${jail}/etc/
                sed -i '/^group:.*/s/compat/files/' ${jail}/etc/nsswitch.conf
                sed -i '/^passwd:.*/s/compat/files/' ${jail}/etc/nsswitch.conf
                mkdir -p ${jail}/lib/x86_64-linux-gnu
                cp /lib/x86_64-linux-gnu/libnss_* ${jail}/lib/x86_64-linux-gnu/
                cp -ar /lib/terminfo ${jail}/lib/

                # group
                if addgroup jail; then
                    shadow_group jail
                fi

                # bin
                chroot_cmds /bin ${cmds}
                chroot_cmds /usr/bin ${cmdu}
                chroot_cmds /usr/lib ${libu}
                ;;

            *)
                ;;
        esac
        ;;

    crew)
        user=$2
        role=$3

        mkdir -p ${gate}/roles
        mkdir -p ${gate}/crews

        if addgroup crews; then
            shadow_group crews
        fi

        if [ ! -z ${user} ]; then
            if addgroup ${user}; then
                shadow_group ${user}
            fi
            if adduser --disabled-password --gecos '' --home ${jail}/home/${user} \
                --ingroup ${user} ${user}; then
                chmod -R g+rw ${jail}/home/${user}
                wget -O ${gate}/crews/${user}.pub ${pubs}/${user}.pub
                chown ${user}:${user} ${gate}/crews/${user}.pub
                usermod -a -G jail,crews ${user}
                shadow_home ${user}
                shadow_user ${user}
                shadow_group jail crews ${user}
            fi
        fi

        if [ ! -z ${role} ]; then
            if addgroup ${role}; then
                shadow_group ${role}
            fi
            if adduser --disabled-password --gecos '' --home ${jail}/home/${user} \
                --ingroup ${user} --force-badname ${user}.${role}; then
                usermod -a -G jail,crews,${role} ${user}.${role}
                shadow_home ${user} ${role}
                shadow_user ${user} ${role}
                shadow_group jail crews ${role}
            fi
        fi
        ;;

    role)
        role=$2
        user=$3

        if adduser --disabled-password --gecos '' --home ${jail}/home/${role} ${role}; then
            sed -i '/^'${role}':.*/s@:'${jail}'@:@' /etc/passwd
            usermod -a -G jail ${role}
            shadow_home ${role}
            shadow_user ${role}
            shadow_group jail ${role}
        fi
        if wget -O ${gate}/sys/${user}.pub ${pubs}/${user}.pub; then
            chown ${role}:${role} ${gate}/sys/${user}.pub
        fi
        ;;

    agent)
        adir=${jail}${gate}/sys

        case $2 in
            key)
                if mkdir -p ${adir}; then
                    chown devops:devops ${adir}
                fi
                if [ ! -f ${adir}/agent.id ]; then
                    ssh-keygen -t rsa -b 4096 -N '' -C 'agent' ${adir}/agent
                    mv ${adir}/agent ${adir}/agent.id
                    chmod a+r ${adir}/agent.id
                fi
                ;;
            cp2)
                svr=$3
                if [ ! -z ${svr} ]; then
                    scp ${adir}/agent.pub ${svr}:${gate}/sys/${HOSTNAME}.pub
                fi
                ;;
            *)
                ;;
        esac
        ;;

    esc)
        case $2 in
            crew)
                user=$3

                mkdir -p ${gate}/crews
                addgroup crews
                if adduser --disabled-password --gecos '' ${user}; then
                    usermod -a -G crews ${user}
                    wget -O ${gate}/crews/${user}.pub ${pubs}/${user}.pub
                    chown ${user}:${user} ${gate}/crews/${user}.pub
                fi
                ;;

            role)
                role=$3

                adduser --disabled-password --gecos '' ${role}
                ;;

            agent)
                adir=${gate}/sys

                case $3 in
                    key)
                        if mkdir -p ${adir}; then
                            chown devops:devops ${adir}
                        fi
                        if [ ! -f ${adir}/agent.id ]; then
                            ssh-keygen -t rsa -b 4096 -N '' -C 'agent' ${adir}/agent
                            mv ${adir}/agent ${adir}/agent.id
                            chown devops:devops ${adir}/agent.*
                        fi
                        ;;
                    cp2)
                        srv=$4
                        if [ ! -z ${svr} ]; then
                            scp ${adir}/agent.pub ${svr}:${adir}/${HOSTNAME}.pub
                        fi
                        ;;
                    *)
                        ;;
                esac
                ;;

            *)
                ;;
        esac
        ;;

    *)
        ;;
esac
