# balance
| defaults | frontend | listen | backend |
| --- | --- | --- | --- |
| yes | no | yes | yes |
```
balance <algorithm> [ <arguments> ]
```
```
roundrobin
static-rr
leastconn
first
hash
source
uri
url_param
hdr(<name>)
random
random(<draws>)
rdp-cookie
rdp-cookie(<name>)
log-hash
sticky
```
| 算法         | 粘性     | 动态权重 | 适用协议 | 适用场景     |
| ---------- | ------ | ---- | ---- | -------- |
| roundrobin | 否      | ✅    | 所有   | 均衡请求分发   |
| static-rr  | 否      | ❌    | 所有   | 大规模集群    |
| leastconn  | 否      | ✅    | 所有   | 长连接      |
| first      | 否      | ❌    | 所有   | 节能、省资源   |
| hash       | 取决于表达式 | 可选   | 所有   | 自定义负载逻辑  |
| source     | 是      | ❌    | TCP  | IP 粘性    |
| uri        | 是      | ❌    | HTTP | 缓存代理     |
| url\_param | 是      | ❌    | HTTP | 用户 ID 粘性 |
| hdr(name)  | 是      | ❌    | HTTP | 按头路由     |
| random     | 否      | ✅    | 所有   | 大规模动态环境  |
| rdp-cookie | 是      | ❌    | TCP  | RDP 粘性   |
| log-hash   | 是      | ❌    | LOG  | 日志处理     |
| sticky     | 是      | ❌    | LOG  | 简单冗余     |

```
 1. roundrobin
轮询方式，按权重轮流选择服务器。
动态算法：可以动态调整服务器权重。
适用场景：各服务器响应速度相近的 HTTP 流量。
限制：最大支持 4095 个服务器。

backend web_servers
    balance roundrobin
    server web1 192.168.1.10:80 check
    server web2 192.168.1.11:80 check

说明：请求会依次分配给 web1, web2, 然后再回到 web1。

backend web_servers
    balance roundrobin
    server web1 192.168.1.10:80 weight 3 check
    server web2 192.168.1.11:80 weight 1 check

说明：表示 web1:web2 的请求比例约为 3:1。

haproxy -f /etc/haproxy/haproxy.cfg -sf $(pidof haproxy)
```

```
2. static-rr
也是轮询方式，但为 静态算法：修改权重不会立刻生效。
优点：
  没有服务器数量限制。
  新恢复的服务器会立即被使用。
  CPU 开销更低。
适用场景：大规模后端服务器集群。

backend web_servers
    balance static-rr
    server web1 192.168.1.10:80 weight 1
    server web2 192.168.1.11:80 weight 3

说明：分配顺序根据启动时计算的权重顺序固定，即使权重改变也不会动态变化。

```
```
3. leastconn
选择当前连接数最少的服务器。
适用于长连接服务，如 SQL、LDAP、RDP。
对短连接如 HTTP 效果一般。
考虑了排队连接数，避免排队延迟。
动态权重支持。

backend sql_servers
    balance leastconn
    server db1 192.168.1.20:3306 check
    server db2 192.168.1.21:3306 check

说明：连接数最少的服务器优先接收新的连接。

```
```
4. first
优先使用编号最小（最前）的服务器，直到该服务器达到 maxconn 限制。
一种节能模式，可通过关闭闲置服务器节省资源。
忽略权重，适合 长连接服务。
搭配云控制器或 http-check send-state 最佳。

backend imap_servers
    balance first
    server imap1 192.168.1.30:143 maxconn 100
    server imap2 192.168.1.31:143 maxconn 100

说明：imap1 满了才使用 imap2。适合用自动脚本根据连接数开关服务器。

```
```
5. hash <expr>
对任意表达式进行哈希，选定服务器。
用于更灵活的负载均衡，如提取请求内容自定义散列。
可指定 hash-type 影响行为（动态或静态）。
适用于高级场景。

backend api_backend
    balance hash
    hash-type consistent
    server api1 192.168.1.40:8080
    server api2 192.168.1.41:8080

use-server if { var(txn.user_id) -m found }

用途：自定义哈希键；配合 req.fhdr()、var() 等。
说明：根据用户 ID 或其他提取值进行负载均衡。

在 HAProxy 中，txn.user_id 是一个 事务范围的变量（TXN scope variable），即属于当前请求处理周期（transaction）的上下文变量。
它不是内建变量，而是一个 自定义变量名，你可以在配置中通过 set-var(txn.user_id) 指令来设置它，比如从 HTTP header、cookie、URL 参数、JWT 等中提取出来。

从 Cookie 提取 user_id 并用于 balance hash
haproxy
Copy
Edit
frontend http-in
    bind *:80
    http-request set-var(txn.user_id) req.cook(user_id)

backend servers
    balance hash
    hash-type consistent
    hash hdr(txn.user_id)
    server s1 192.168.1.101:80
    server s2 192.168.1.102:80
这个配置做了两件事：

1. 提取 cookie 中的 user_id，保存到变量 txn.user_id。
2. 用这个变量进行 hash，从而确保相同用户访问固定后端（有粘性，且不依赖 cookie 插入）。

可替代地，从 URL 参数提取：
http-request set-var(txn.user_id) urlp(user_id)

或者从 Header：
http-request set-var(txn.user_id) req.hdr(X-User-ID)

理解 txn 范围变量（transaction scope）
  txn. 是事务作用域，生命周期为 一次请求（从接收到发送响应）。
  你还可以用 req.（请求作用域）或 sess.（会话作用域）定义变量。

在 hash 中使用	balance hash + hash var(txn.user_id) 实现用户级负载均衡粘性

```
```
6. source
根据客户端 IP 哈希分配服务器，实现 IP 粘性。
适合 TCP 模式 或 禁用 cookie 的场景。
默认为静态算法。

backend ssh_gateway
    balance source
    hash-type consistent
    server ssh1 192.168.1.50:22
    server ssh2 192.168.1.51:22

用途：源 IP 绑定 stickiness，适合 TCP。
说明：同一个 IP 会一直打到同一台机器，适合用户粘性需求。

```
```
7. uri
根据 URI（可选参数：len, depth, whole, path-only）进行哈希。
同一 URI 会被路由到同一服务器，提升缓存命中率。
用于HTTP 缓存代理、病毒扫描代理等场景。

backend cache_backend
    balance uri
    hash-type consistent
    hash-balance-factor 5
    server cache1 192.168.1.60:80
    server cache2 192.168.1.61:80

用途：缓存代理、CDN、病毒扫描场景。
说明：相同 URI 会命中同一台机器，增加缓存命中率。

```
```
8. url_param(<name>)
提取 HTTP 请求中的 URL 参数并哈希。
支持 check_post 检查 POST 内容体。
用于根据用户 ID 进行会话绑定，适合 Web 应用。

backend login_backend
    balance url_param(userid)
    server app1 192.168.1.70:80
    server app2 192.168.1.71:80

用途：按用户 ID 绑定 session。
说明：请求中带有 ?userid=123 会用于 hash。适合 RESTful API。

```
```
9. hdr(<name>)
按 HTTP 请求头进行哈希（例如 Host）。
可选参数：use_domain_only（忽略子域名）。
适合根据请求头路由的场景。
hdr 表示 header 

backend domain_backend
    balance hdr(Host)
    server blog 192.168.1.80:80
    server shop 192.168.1.81:80

用途：Host、X-Session-ID 等 header 定向。
说明：根据 Host 头部的内容做负载。Host: shop.example.com 可用于多租户结构。

```
```
10. random 或 random(<draws>)
使用随机数决定服务器，权重有效，动态支持。
<draws> 指定多次采样再选连接最少的服务器（默认 2）——称为 “Power of Two Choices” 算法。
适合大规模动态集群，服务器频繁上下线时非常有用。

backend big_cluster
    balance random(2)
    server node1 192.168.1.90:80
    server node2 192.168.1.91:80
    server node3 192.168.1.92:80

用途：大规模集群中高效避免倾斜。
说明：随机选两个服务器，从中挑负载最小的一个分配。对动态上下线服务器效果好。

```
```
11. rdp-cookie(<name>)
从 RDP 协议中的 cookie（默认为 mstshash）中提取会话标识并哈希。
用于 TCP 模式下的会话粘性（RDP、远程桌面）。

backend rdp_backend
    balance rdp-cookie(mstshash)
    server win1 192.168.1.100:3389
    server win2 192.168.1.101:3389

用途：远程桌面用户保持 stickiness。
说明：RDP 请求中的 mstshash cookie 被用于分配。

```
```
12. log-hash
专用于 LOG 模式下的后端负载均衡。
通过字符串转换器提取日志中关键信息进行哈希。

backend log_backend
    mode log
    balance log-hash(txn.log_id)
    server log1 192.168.1.110:514
    server log2 192.168.1.111:514

用途：专用于 LOG 模式，根据日志内容选择后端。
说明：可将日志同 ID 的信息发送到同一后端，便于关联处理。

```
```
13. sticky
尽可能一直使用第一个可用服务器，直到它挂了。
用于极简模式或日志系统，仅在服务器不稳定时切换。

backend log_sticky
    balance sticky
    server log1 192.168.1.120:514
    server log2 192.168.1.121:514

用途：日志集中化；首选一个后端，除非故障。
说明：日志会优先发送到 log1，它挂了再换 log2，后恢复也不会马上回来。

```


