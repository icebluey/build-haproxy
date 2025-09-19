#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
echo
cat /proc/cpuinfo
echo
if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2204 -itd ubuntu:22.04 bash
else
    docker run --rm --name ub2204 -itd ubuntu:22.04 bash
fi
docker exec ub2204 apt update -y
docker exec ub2204 bash -c 'if [[ -f /usr/local/sbin/unminimize ]]; then yes | /usr/local/sbin/unminimize; fi'
docker exec ub2204 apt upgrade -fy
docker exec ub2204 apt install -y bash vim wget ca-certificates
docker exec ub2204 /bin/ln -svf bash /bin/sh
docker exec ub2204 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2204 ub2204:/home/
docker exec ub2204 /bin/bash /home/ub2204/.preinstall_ub2204
docker exec ub2204 /bin/bash /home/ub2204/build-haproxy.sh
mkdir -p /tmp/_output.tmp
for i in $(docker exec ub2204 ls -1 /tmp/ | grep -i '^haproxy.*\.tar'); do docker cp ub2204:/tmp/$i /tmp/_output.tmp/ ; done
exit
