# Concatenate the certificate files
```
cat server.crt intermediateCA.crt > fullchain.crt
cat fullchain.crt server.key > haproxy.pem
```

# Examples
```
frontend http3
    mode http
    bind :80,[::]:80
    bind :443,[::]:443 ssl crt /home/haproxy.pem alpn h2 ssl-min-ver TLSv1.3
    bind quic4@:443 ssl crt /home/haproxy.pem alpn h3 ssl-min-ver TLSv1.3
    bind quic6@:443 ssl crt /home/haproxy.pem alpn h3 ssl-min-ver TLSv1.3
    http-request redirect scheme https unless { ssl_fc }
    #http-request redirect scheme https code 301 unless { ssl_fc }
    http-after-response add-header alt-svc 'h3=":443"; ma=60'

    # HSTS
    # max-age is mandatory 
    # 16000000 seconds is a bit more than 6 months
    http-response set-header Strict-Transport-Security "max-age=16000000; includeSubDomains; preload;"

    default_backend app

    # acl acl名 condition
    acl acl名  req.ssl_sni -i 域名
    tcp-request inspect-delay 5s
    tcp-request content reject if !acl名1 acl名2
    tcp-request content accept if { req.ssl_hello_type 1 }
    use_backend 后端名1 if acl名
    default_backend 后端名2
backend 后端名1
    balance roundrobin | leastconn | hash
    # ...
    server 定义server的名字 ip:port check [sni req.ssl_sni] [maxconn 300] [ssl]

```

## Mode TCP, SSL/TLS pass-through 穿透, 不需要证书
#### /etc/haproxy/haproxy.cfg
```
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    #stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    #stats timeout 30s
    user haproxy
    group haproxy
    daemon
defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    retries 5
    timeout client 1m
    timeout queue 1m
    timeout connect 10s
    timeout server 1m
    timeout check 10s
    maxconn 5000
frontend http443
    bind :443
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    default_backend k8s
backend k8s
    balance leastconn
    server master1 192.168.10.101:6443 check fall 3 rise 3
    server master2 192.168.10.102:6443 check fall 3 rise 3
    server master3 192.168.10.103:6443 check fall 3 rise 3
```

## haproxy log to file
#### /etc/rsyslog.d/10-haproxy.conf
```
#$ModLoad imuxsock
$AddUnixListenSocket /var/lib/haproxy/dev/log
#$template haproxy,"%timestamp:::date-rfc3339% %HOSTNAME% %syslogtag%%msg%\n"
:programname, startswith, "haproxy" {
    /var/log/haproxy/haproxy.log
    stop
}
```

```
chown: invalid user: 'syslog:adm'

apt install rsyslog
 getent passwd syslog
syslog:x:106:109::/home/syslog:/usr/sbin/nologin

```
