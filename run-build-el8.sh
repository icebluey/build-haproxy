#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
docker run --cpus="2.0" --hostname 'x86-034.build.eng.bos.redhat.com' --rm --name al8 -itd icebluey/almalinux:8 bash
sleep 2
docker exec al8 yum clean all
docker exec al8 yum makecache
docker exec al8 /bin/bash -c 'rm -fr /tmp/*'
docker cp el8 al8:/home/
docker exec al8 /bin/bash /home/el8/build-haproxy-quictls.sh
_haproxy_ver="$(docker exec al8 ls -1 /tmp/ | grep -i '^haproxy.*xz$' | sed -e 's|haproxy-||g' -e 's|-[0-1]\.el.*||g')"
rm -fr /home/.tmp.haproxy
mkdir /home/.tmp.haproxy
docker cp al8:/tmp/haproxy-"${_haproxy_ver}"-1.el8.x86_64.tar.xz /home/.tmp.haproxy/
docker cp al8:/tmp/haproxy-"${_haproxy_ver}"-1.el8.x86_64.tar.xz.sha256 /home/.tmp.haproxy/
exit
