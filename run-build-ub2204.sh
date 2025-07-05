#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
echo
cat /proc/cpuinfo
echo
if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2204 -itd ubuntu:22.04 bash
else
    docker run --rm --name ub2204 -itd ubuntu:22.04 bash
fi
sleep 2
docker exec ub2204 apt update -y
docker exec ub2204 apt upgrade -fy
docker exec ub2204 apt install -y bash vim wget ca-certificates
docker exec ub2204 /bin/ln -svf bash /bin/sh
docker exec ub2204 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2204 ub2204:/home/
docker exec ub2204 /bin/bash /home/ub2204/.preinstall_ub2204
docker exec ub2204 /bin/bash /home/ub2204/build-haproxy.sh
#_haproxy_ver="$(docker exec ub2204 ls -1 /tmp/ | grep -i '^haproxy.*xz$' | sed -e 's|haproxy-||g' -e 's|-[0-1]_.*||g')"
mkdir -p /tmp/_output.tmp
for i in $(docker exec ub2204 ls -1 /tmp/ | grep -i '^haproxy.*\.tar'); do docker cp ub2204:/tmp/$i /tmp/_output.tmp/ ; done

exit

sleep 2
docker stop ub2204 || true
sleep 2
docker rm -f ub2204 || true
sleep 2

if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2204 -itd ubuntu:22.04 bash
else
    docker run --rm --name ub2204 -itd ubuntu:22.04 bash
fi
sleep 2
docker exec ub2204 apt update -y
docker exec ub2204 apt upgrade -fy
docker exec ub2204 apt install -y bash vim wget ca-certificates
docker exec ub2204 /bin/ln -svf bash /bin/sh
docker exec ub2204 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2204 ub2204:/home/
docker exec ub2204 /bin/bash /home/ub2204/.preinstall_ub2204
docker exec ub2204 /bin/bash /home/ub2204/build-haproxy-quictls.sh
_haproxy_ver="$(docker exec ub2204 ls -1 /tmp/ | grep -i '^haproxy.*xz$' | sed -e 's|haproxy-||g' -e 's|-quictls.*||g')"
mkdir -p /tmp/_output.tmp
docker cp ub2204:/tmp/haproxy-"${_haproxy_ver}"-quictls-1_ub2204_amd64.tar.xz /tmp/_output.tmp/
docker cp ub2204:/tmp/haproxy-"${_haproxy_ver}"-quictls-1_ub2204_amd64.tar.xz.sha256 /tmp/_output.tmp/

exit
