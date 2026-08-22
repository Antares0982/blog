---
title: "Padavan路由器搭建v2ray服务"
slug: "padavan-v2ray"
date: 2021-05-11T20:51:18+08:00
lastmod: 2025-08-11T01:46:10+08:00
wpid: 84
wpguid: "https://chr.fan/?p=84"
views: 17932
categories: ["技术"]
tags: ["v2ray", "padavan", "路由器", "固件", "老毛子"]
---

因为我的所有设备上默认搜索引擎都是Google，在设备上（尤其是手机）开关一些魔法软件会比较麻烦，而且耗电。

所以为什么不把这项繁杂的任务交给路由器呢？
> 2025年1月11日更新：
本文内容已经过时。仅留档用于参考。

> 2022年2月13日更新：
目前部分服务端已经不支持之前版本的v2ray客户端。现改用xray内核，有需要可以自行选用新版本v2ray，在[release页面](https://github.com/v2ray/v2ray-core/releases)下载mips32le版本即可。xray是v2ray的超集，支持vless协议，多数情况下负载更小，适合路由器运行。将后文提到的所有v2ray改为xray即可正常使用。

**声明：本文不提供任何上网工具**

## 工具

* 刷Padavan固件的路由器，最好是带USB接口，没有USB的也可以，但是需要一些[其他操作](https://github.com/ntgeralt/v2ray-for-padavan/blob/master/README.md#%E4%B8%BB%E6%96%87%E4%BB%B6%E9%99%A4%E4%BA%86%E6%94%BEusb%E5%A4%96%E9%83%A8%E5%82%A8%E5%AD%98%E8%BF%98%E5%8F%AF%E4%BB%A5%E6%94%BE%E5%9C%A8tmpstorage%E7%A9%BA%E9%97%B4%E6%88%96trx%E5%9B%BA%E4%BB%B6%E5%B0%81%E5%8C%85)。（我用的是[网件R6800](https://www.netgear.com.cn/home/products/networking/wifi-routers/R6800.aspx)，感谢YYYYeast友情提供的~~电子垃圾~~路由器）（如何刷该固件请自行搜索，不是所有路由器都可以刷Padavan。R6800刷固件的话可以参考[这里](https://www.right.com.cn/forum/thread-396780-1-1.html)）
* 一个之后要一直插在路由器上的U盘，容量基本没有要求
* 稳定的v2ray节点，最好不要经常变动各种信息

## 配置v2ray

### 准备U盘

如果U盘的卷名很怪的话（尤其是有空格或者一些奇怪字符，或者以短横线开头之类），可以把U盘先格式化，换一个卷名。我的U盘卷名改为了`AIDISK`，下面出现的文件路径里，`AIDISK`全部换成你自己的卷名。

### 下载Padavan用的v2ray

下载Padavan用的[v2ray内核以及脚本](https://github.com/ntgeralt/v2ray-for-padavan)，也可以直接下载我的[fork](https://github.com/Antares0982/v2ray-for-padavan)，之后修改完里面的内容后，要把文件夹`FOR-USB-or-TF/FOR-USB-or-TF/media/AiDisk_a1/v2ray`复制到U盘根目录下。（下载fork的话，接下来下载完最新的geosite, geoip data，就可以直接跳到修改配置文件的步骤了）

接下来要修改上面仓库中的文件夹`FOR-USB-or-TF/FOR-USB-or-TF/media/AiDisk_a1/v2ray`里的内容。这个文件夹里几个文件的作用：

* start.sh：写入路由器iptables，将大陆外ip的访问转入1234端口，并启动/重启v2ray内核。
* stop.sh：结束v2ray进程。
* v2ray：本体。
* config.json：v2ray配置文件。默认[Dokodemo door](https://www.v2ray.com/chapter_02/protocols/dokodemo.html)（任意门）协议监听1234端口。

### 下载geosite以及geoip data

原脚本中采用的方案是，只将大陆外的流量重定向到1234端口，这样操作稳定性很差。所以我推荐的方案是，v2ray的config中设置绕过大陆地址，路由器iptables将所有访问均转入1234端口，让v2ray来自行判断哪些ip以及域名走代理。为此，需要下载最新版本的[geosite, geoip data](https://github.com/Loyalsoldier/v2ray-rules-dat/releases)，这个release页每天早上六点自动生成最新的geosite data，下载`geosite.dat`以及`geoip.dat`即可，这两个文件不需要频繁更新。将下载的两个文件放入U盘的v2ray文件夹。

### 修改start.sh

接下来对原脚本作一些简单的修改，来使用`geosite.dat`以及`geoip.dat`。

**首先，确保你的文本编辑器是默认以LF为换行符**（非Windows用户可以忽略这一步骤）。如果使用[vscode](https://code.visualstudio.com/)，在打开脚本前先在`文件->首选项->设置`中搜索EOL，将EOL设置改为LF，而不是用默认的CRLF。

然后修改`start.sh`为下面的代码，重点在于注释掉`chnroute`的几行，以及只代理目标53，80和443端口的流量。如果有其它需求的话也可以代理10000及以上端口的流量。注意这里`AIDISK`改为你的U盘卷名：

```bash
#!/bin/bash
#echo "Load modprobe"
modprobe ip_set_hash_net
modprobe xt_set

cd /media/AIDISK/v2ray
sh stop.sh

#echo "[cleanning iptables]"
iptables -t nat -D PREROUTING V2RAY  >/dev/null 2>&1
iptables -t nat -D OUTPUT V2RAY  >/dev/null 2>&1
/bin/iptables -t nat -F V2RAY >/dev/null 2>&1
/bin/iptables -t nat -X V2RAY >/dev/null 2>&1
/sbin/ipset destroy chnroute >/dev/null 2>&1
#echo "ipset chnroute"
#ipset -exist create chnroute hash:net hashsize 64
#sed -e "s/^/add chnroute /" /media/AIDISK/v2ray/chnroute.txt | ipset restore
echo ""
echo ""
echo "[setting iptables]"
iptables -t nat -N V2RAY
iptables -t nat -A V2RAY -d 0.0.0.0 -j RETURN
iptables -t nat -A V2RAY -d 127.0.0.1 -j RETURN
iptables -t nat -A V2RAY -d 192.168.0.0/16 -j RETURN


# iptables -t nat -A V2RAY -m set --match-set chnroute dst -j RETURN

# Anything else should be redirected to Dokodemo-door's local port

iptables -t nat -A V2RAY -p tcp --dport 53 -j REDIRECT --to-ports 1234
iptables -t nat -A V2RAY -p tcp --dport 80 -j REDIRECT --to-ports 1234
iptables -t nat -A V2RAY -p tcp --dport 443 -j REDIRECT --to-ports 1234
iptables -t nat -A V2RAY -p tcp --dport 10000:65535 -j REDIRECT --to-ports 1234

iptables -t nat -A PREROUTING -p tcp -j V2RAY


echo "-----------------[V2Ray started]---------------------------"
echo "#to stop v2ray"
echo "bash /media/AIDISK/v2ray/stop.sh"
echo "-------------you can close this Window---------------------"

cd /media/AIDISK/v2ray

SSL_CERT_FILE=./cacert.pem ./v2ray --config=/media/AIDISK/v2ray/config.json >/dev/null 2>&1 &

echo "[V2ray start]"
#./v2ray-watchdog >/dev/null 2>&1 &
#echo "[v2ray-watchdog started]."
```

### 修改v2ray配置文件

修改`config.json`，重要的部分是`dns`，`inbounds`和`routing`。`outbounds`按照你的v2ray节点配置填就行，重要的只有第一项需要是直连，因为有很多程序的网络请求是无法在`routing`里找到的（亲测），第一项是默认出口，最好是默认直连。不会写配置的话，可以使用这个[工具](https://tools.sprov.xyz/v2ray/)。我这里的配置是ws+tls，记得更改你的节点域名、uuid等信息。这里`inbounds`可以不要socks代理和http代理，我加上这两项是给自己的Ubuntu笔记本用以及写程序的时候用。`routing`中也是越前面的配置优先级越高，所以第一项用来block ads以外，先direct再proxy的设置会比较合适。其中direct里从`torrent`开始的域名是种子站的规则，通常而言代理服务商是不会允许种子站走代理的，所以设置不走代理才能正常访问。还有一处direct里可以设置直连的`ip`，可以在后面加上自己所处的局域网的ip段，`a.b.0.0/16`代表所有`a.b`开头的ip地址，如果要直连的只有`a.b.c`开头的ip，可以填`a.b.c.0/8`。Telegram的通信是直接使用ip的，所以`"geoip:telegram"`项对于Telegram用户是必要的。

```json
{
  "dns": {
    "hosts": {
      "dns.google": "8.8.8.8",
      "dns.pub": "119.29.29.29",
      "dns.alidns.com": "223.5.5.5",
      "geosite:category-ads-all": "127.0.0.1"
    },
    "servers": [
      {
        "address": "https://1.1.1.1/dns-query",
        "domains": [
          "geosite:geolocation-!cn"
        ],
        "expectIPs": [
          "geoip:!cn"
        ]
      },
      "8.8.8.8",
      {
        "address": "114.114.114.114",
        "port": 53,
        "domains": [
          "geosite:cn",
          "geosite:category-games@cn"
        ],
        "expectIPs": [
          "geoip:cn"
        ],
        "skipFallback": true
      },
      {
        "address": "localhost",
        "skipFallback": true
      }
    ]
  },
  "inbounds": [
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "ip": "127.0.0.1"
      },
      "tag": "in-0",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },
    {
      "port": 1081,
      "protocol": "http",
      "settings": {},
      "tag": "in-1"
    },
    {
      "port": 1234,
      "listen": "0.0.0.0",
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "vmess",
      "tag": "proxy",
      "settings": {
        "vnext": [
          {
            "address": "your-proxy-address",
            "port": 443,
            "users": [
              {
                "id": "your-proxy-uuid",
                "alterId": 2
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": {
          "path": "your-proxy-path",
          "headers": {}
        },
        "tlsSettings": {
          "serverName": "your-proxy-serverName"
        }
      },
      "mux": {
        "enabled": true
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "outboundTag": "blocked",
        "domain": [
          "geosite:category-ads-all"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "domain": [
          "geosite:cn",
          "geosite:private",
          "geosite:apple-cn",
          "geosite:google-cn",
          "geosite:tld-cn",
          "geosite:category-games@cn",
          "torrent",
          "peer_id=",
          "info_hash",
          "get_peers",
          "find_node",
          "BitTorrent",
          "announce_peer"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "192.168.0.0/16",
          "127.0.0.0/16",
          "geoip:cn"
        ]
      },
      {
        "type": "field",
        "outboundTag": "proxy",
        "domain": [
          "geosite:geolocation-!cn"
        ]
      },
      {
        "type": "field",
        "outboundTag": "proxy",
        "ip": [
          "geoip:us",
          "geoip:ca",
          "geoip:telegram"
        ]
      }
    ]
  }
}
```

对v2ray配置文件不了解的话，可以看看v2ray的[官方网站](https://www.v2ray.com/chapter_02/)，个人感觉写得非常通俗易懂。

### 自动获取geosite, geoip data与重启脚本

如果想要自动获取每天的`geosite.dat`并且重启v2ray的话，可以在定时任务里加上任务

```crontab
0 7 * * * bash /media/AIDISK/v2ray/autorenewgeosite.sh &
```

并且写一个脚本`/media/AIDISK/v2ray/autorenewgeosite.sh`

```bash
#!/bin/bash

curl -k --connect-timeout 5 --retry 3 https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat > /media/AIDISK/v2ray/geosite.dat
curl -k --connect-timeout 5 --retry 3 https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat > /media/AIDISK/v2ray/geoip.dat
cd /media/AIDISK/v2ray && bash start.sh
```

注意上面几处`AIDISK`改为你的U盘卷名。

### 将U盘插上路由器

所有文件修改完成之后将v2ray文件夹放入U盘根目录，将U盘插入路由器。注意，如果有多个U盘插口，最好插在USB2.0接口上。

### 大功告成

运行`start.sh`，注意这里的`AIDISK`改为你的U盘卷名。

```bash
bash /media/AIDISK/v2ray/start.sh
```

v2ray启动时读取geosite以及geoip会比较慢，启动后等待一小段时间就可以了。使用时基本不会有延迟（除非你的节点不稳定），使用连上路由器的设备，实际体验和身处境外差不多。

### 建议配置

将`start.sh`复制一份，最后那行稍微删掉一些东西：

```bash
SSL_CERT_FILE=./cacert.pem ./v2ray --config=/media/AIDISK/v2ray/config.json
```

重命名为`debugstart.sh`，执行这个脚本`bash /media/AIDISK/v2ray/debugstart.sh`的话，可以看到v2ray的报错信息。如果遇到问题的话，可以用这个方法检查一下配置到底出了什么毛病。

上面所说的配置示范都可以在我的[fork](https://github.com/Antares0982/v2ray-for-padavan)找到，实测非常好用。

### 后续维护

如果需要更新`geosite.dat`以及`geoip.dat`并且不想用上面的脚本，或者节点信息有变化，需要更新`config.json`，请不要拔下U盘来操作。可以使用[sftp](https://en.wikipedia.org/wiki/SFTP)来更新，要先在路由器的设置页设置开启ssh。传输完成之后记得重新执行一次

```bash
bash /media/AIDISK/v2ray/start.sh
```

就可以了。

当然，`config.json`也可以直接使用路由器内的`vi`指令来修改，这样的话只需要ssh连接到路由器上就行了。
