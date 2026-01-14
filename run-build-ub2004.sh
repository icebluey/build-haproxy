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
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2004 -itd ubuntu:20.04 bash
else
    docker run --rm --name ub2004 -itd ubuntu:20.04 bash
fi
docker exec ub2004 apt update -y
docker exec ub2004 bash -c 'if [[ -f /usr/local/sbin/unminimize ]]; then yes | /usr/local/sbin/unminimize; fi'
docker exec ub2004 apt upgrade -fy
docker exec ub2004 apt install -y bash vim wget ca-certificates cmake ninja-build clang perl
docker exec ub2004 /bin/ln -svf bash /bin/sh
docker exec ub2004 /bin/rm -fr /tmp/.setup_env_ub2004
docker exec ub2004 wget -q "https://raw.githubusercontent.com/icebluey/build/master/.setup_env_ub2004" -O "/tmp/.setup_env_ub2004"
docker exec ub2004 /bin/bash /tmp/.setup_env_ub2004
docker exec ub2004 /bin/rm -f /tmp/.setup_env_ub2004
docker exec ub2004 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2004 ub2004:/home/
docker exec ub2004 /bin/bash /home/ub2004/build-haproxy.sh
mkdir -p /tmp/_output.tmp
for i in $(docker exec ub2004 ls -1 /tmp/ | grep -i '^haproxy.*\.tar'); do docker cp ub2004:/tmp/$i /tmp/_output.tmp/ ; done
exit
