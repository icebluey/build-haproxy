#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
cd "$(dirname "$0")"
systemctl start docker
echo
cat /proc/cpuinfo
echo
if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name al9 -itd almalinux:9 bash
else
    docker run --rm --name al9 -itd almalinux:9 bash
fi
docker exec al9 dnf clean all
docker exec al9 dnf makecache
docker exec al9 dnf install -y wget bash
docker exec al9 /bin/bash -c 'ln -svf bash /bin/sh'
docker exec al9 /bin/bash -c 'rm -fr /tmp/*'
docker cp al9 al9:/home/
docker exec al9 /bin/bash /home/al9/.preinstall_al9
docker exec al9 /bin/bash /home/al9/build-haproxy.sh
mkdir -p /tmp/_output.tmp
for i in $(docker exec al9 ls -1 /tmp/ | grep -i '^haproxy.*\.tar'); do docker cp al9:/tmp/$i /tmp/_output.tmp/ ; done
exit
