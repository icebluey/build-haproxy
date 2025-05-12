# Run
```
# el8 / el9
dnf install -y libxcrypt glibc

```

# Concatenate the certificate files
```
cat server.crt intermediateCA.crt > fullchain.crt
cat fullchain.crt server.key > haproxy.pem
```

# Examples
```

global
    ssl-default-bind-options ssl-min-ver TLSv1.3

frontend http
    mode http
    bind :80,[::]:80
    bind :443,[::]:443 ssl crt /home/haproxy1.pem crt /home/haproxy2.pem alpn h2 ssl-min-ver TLSv1.3
    bind quic4@:443 ssl crt /home/haproxy1.pem crt /home/haproxy2.pem alpn h3 ssl-min-ver TLSv1.3
    bind quic6@:443 ssl crt /home/haproxy1.pem crt /home/haproxy2.pem alpn h3 ssl-min-ver TLSv1.3
    #http-request redirect scheme https unless { ssl_fc }
    http-request redirect scheme https code 301 unless { ssl_fc }
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

backend app
    balance roundrobin | leastconn | hash
    # ...
    server 定义server的名字 ip:port check [sni req.ssl_sni] [maxconn 300] [ssl]
backend 后端名1
    balance roundrobin | leastconn | hash
    # ...
    server 定义server的名字 ip:port check [sni req.ssl_sni] [maxconn 300] [ssl]
backend 后端名2
    balance roundrobin | leastconn | hash
    # ...
    server 定义server的名字 ip:port check [sni req.ssl_sni] [maxconn 300] [ssl]

```

## SSL/TLS termination (终止) 也叫 SSL/TLS offloading (卸载), mode http
#### /etc/haproxy/haproxy.cfg
```
# 前端
frontend http
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

```

## SSL/TLS passthrough (穿透), mode tcp, 不需要证书
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



https://www.haproxy.org/download/3.1/doc/configuration.txt
```
tcp-request inspect-delay 5s
当 HAProxy 接收到一个 TCP 连接后，它会等待数据达到一定程度再开始检查。
如果在 5 秒内收到了足够的数据，就会继续进行后续处理；如果 5 秒后仍然没有足够的数据，则 HAProxy 将按照当前已收到的数据继续处理请求。


# mode tcp 时, 使用 req.ssl_
req.ssl_hello_type : integer
req_ssl_hello_type : integer (deprecated)

req.ssl_sni : string
req_ssl_sni : string (deprecated)

Examples :
   # Wait for a client hello for at most 5 seconds
   tcp-request inspect-delay 5s
   tcp-request content accept if { req.ssl_hello_type 1 }
   use_backend bk_allow if { req.ssl_sni -f allowed_sites }
   default_backend bk_sorry_page

tcp-request content <action> [{if | unless} <condition>]

  Example:
        # reject SMTP connection if client speaks first
        tcp-request inspect-delay 30s
        acl content_present req.len gt 0
        tcp-request content reject if content_present

        # Forward HTTPS connection only if client speaks
        tcp-request inspect-delay 30s
        acl content_present req.len gt 0
        tcp-request content accept if content_present
        tcp-request content reject

```

```
# mode http 时, 使用 ssl_fc_

ssl_fc_sni
ssl_fc_sni -i demo.abc.xyz

ACL derivatives :
  ssl_fc_sni_end : suffix match
  ssl_fc_sni_reg : regex match

```


https://www.haproxy.com/documentation/haproxy-configuration-tutorials/core-concepts/acls/
```
Access Control Lists (ACL)
The syntax is :
acl <aclname> <criterion> [flags] [operator] [<value>] ...

The following ACL flags are currently supported :

   -i : ignore case during matching of all subsequent patterns.
   -f : load patterns from a list.
   -m : use a specific pattern matching method
   -n : forbid the DNS resolutions
   -M : load the file pointed by -f like a map.
   -u : force the unique id of the ACL
   -- : force end of flags. Useful when a string looks like one of the flags.

Available operators for integer matching are :

  eq : true if the tested value equals at least one value
  ge : true if the tested value is greater than or equal to at least one value
  gt : true if the tested value is greater than at least one value
  le : true if the tested value is less than or equal to at least one value
  lt : true if the tested value is less than at least one value

  - exact match     (-m str) : the extracted string must exactly match the
    patterns;

  - substring match (-m sub) : the patterns are looked up inside the
    extracted string, and the ACL matches if any of them is found inside;

  - prefix match    (-m beg) : the patterns are compared with the beginning of
    the extracted string, and the ACL matches if any of them matches.

  - suffix match    (-m end) : the patterns are compared with the end of the
    extracted string, and the ACL matches if any of them matches.

  - subdir match    (-m dir) : the patterns are looked up anywhere inside the
    extracted string, delimited with slashes ("/"), the beginning or the end
    of the string. The ACL matches if any of them matches. As such, the string
    "/images/png/logo/32x32.png", would match "/images", "/images/png",
    "images/png", "/png/logo", "logo/32x32.png" or "32x32.png" but not "png"
    nor "32x32".

  - domain match    (-m dom) : the patterns are looked up anywhere inside the
    extracted string, delimited with dots ("."), colons (":"), slashes ("/"),
    question marks ("?"), the beginning or the end of the string. This is made
    to be used with URLs. Leading and trailing delimiters in the pattern are
    ignored. The ACL matches if any of them matches. As such, in the example
    string "http://www1.dc-eu.example.com:80/blah", the patterns "http",
    "www1", ".www1", "dc-eu", "example", "com", "80", "dc-eu.example",
    "blah", ":www1:", "dc-eu.example:80" would match, but not "eu" nor "dc".
    Using it to match domain suffixes for filtering or routing is generally
    not a good idea, as the routing could easily be fooled by prepending the
    matching prefix in front of another domain for example.

acl short_form  hdr_beg(host)        www.
acl alternate1  hdr_beg(host) -m beg www.
acl alternate2  hdr_dom(host) -m beg www.
acl alternate3  hdr(host)     -m beg www.

acl url_static  path_beg         /static /images /img /css
acl url_static  path_end         .gif .png .jpg .css .js
acl host_www    hdr_beg(host) -i www
acl host_static hdr_beg(host) -i img. video. download. ftp.

hdr(<name>) The HTTP header <name> will be looked up in each HTTP
            request. Just as with the equivalent ACL 'hdr()' function,
            the header name in parenthesis is not case sensitive. If the
            header is absent or if it does not contain any value, the
            roundrobin algorithm is applied instead.

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
