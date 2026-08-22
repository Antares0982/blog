---
title: "Linux 桌面环境 开机代理脚本"
slug: "archive-linux-desktop-proxy-settings"
date: 2023-10-13T23:51:33+08:00
lastmod: 2023-10-13T23:51:33+08:00
wpid: 346
wpguid: "https://chr.fan/?page_id=346"
views: 3203
hidden: true
url: "/archive/archive-linux-desktop-proxy-settings/"
---

原本一直在笔记本上用Ubuntu，桌面是Gnome。但是一直感觉不好用，于是重装了个Arch，桌面也换用KDE。

因为平时习惯于使用路由器上的代理，但是每次开机之后自己切换代理设置很麻烦，于是一直在Gnome上用开机脚本设置代理。现在换Arch+KDE之后，原先的脚本得改很多地方，于是有了这篇踩坑之后的文章。如果你也想要自己的电脑自动地更换代理设置，那么这篇文章应该会对你有帮助。

原本的Gnome在输入密码登录前会先连接无线网络，所以可以在输密码的时候直接在`.profile`里设置好代理。现在Arch+KDE则不行。这里写的是我个人的开机脚本解决思路，不提供任何代理使用教学以及代理，仅供参考。

我使用的是[oh-my-zsh](https://ohmyz.sh)的主题[Powerlevel10k](https://github.com/romkatv/powerlevel10k)，如果你没有使用zshell，把下文提到的`.zshrc`都换成`.bashrc`。

### 默认配置

当路由器上没有挂代理时（以及局域网其他设备也没开的情况下），使用电脑上自行安装的`v2ray`，首先要执行

```bash
sudo systemctl enable v2ray.service
```

> **注意，这样写开机脚本的话需要用`visudo`修改你的用户权限至少为无需在使用`sudo systemctl`时输入密码。如果你是新手的话，并不推荐这样做。**
>
> 其他解决方案：
>
> * 换用[v2ray on docker](https://toutyrater.github.io/app/docker-deploy-v2ray.html)，并将自己的用户加入`docker`用户组。
> * 在开机脚本里用命令来启动v2ray。`v2ray -config /path/to/config.json &`

在默认情况下就用这个默认代理，端口还是1080和1081，不需要的话开机关闭掉就行。

### 等待联网

新建一个脚本文件并编辑，下面我将以`start.sh`作为文件名为例。以下内容不个别声明的话，都是写在这个脚本里。这篇文章不会把完整的脚本放出来，~~因为我担心小白看了这篇文章之后出现了什么开机开不了的问题，如果你连shell里怎么进行逻辑判断都不清楚的话，建议先去学一下。~~

对于KDE而言，因为脚本是登录时执行，等待联网只需在脚本前加上

```bash
sleep 5
```

即可。**`profile`文件执行完毕之后桌面才会启动，启动后才会联网，如果你的脚本用了sleep 5，那么请务必在`profile`文件里运行脚本时加上`&`**，这也意味着不能使用`source`来`export`环境变量。之后使用的`nc`指令加上`-w 1`参数也是同理。Gnome桌面不需要这个步骤，直接用`source`。这个事后面还会提到，可以先跳过。

因为代理与网络环境可能出现变化，可以考虑在这之后执行一次

```bash
sudo systemctl start v2ray.service
```

### 检测路由器1080端口

这样做前提是你知道如何在路由器上挂一个代理，如果你没有这个需求或者不明白的话可以跳过这一小节。如何在路由器上挂代理可以参考我的另一篇文章：[Padavan路由器搭建v2ray服务](/padavan-v2ray/)。

用

```bash
route_addr=$(netstat -rn | awk '{print $2}'  | sed -n '3p')
```

记录下网关地址。探测1080端口：

```bash
test_answer=`nc -v $route_addr 1080 -w 1 2>&1 | grep -c "succeeded"`
```

如果`test_answer`为则已经联网且路由器上1080端口开放，当然换成检测1081端口也行。这里默认1080端口是代理的socks5端口，1081是http端口。~~一般情况下也不太可能会有别的进程在监听1080端口（~~

如果**没连上网**或者路由器1080端口不开放，则该值为0。

进行`test_answer`值是否非0的判断。该值非0时，先关闭`v2ray`（docker v2ray用户的话要改为docker stop）

```bash
sudo systemctl stop v2ray
```

记录下代理

```bash
http_addr="http://$route_addr:1081"
```

### 检测局域网其他设备上的代理

首先需要在自家路由器里给某个设备设置一个固定局域网ip地址。（或者把某个范围扫一遍也行，就不细说了）

比如，自己的手机使用了代理，以socks5端口为1080为例，并且**在设置里允许局域网连接**，手机的局域网ip是`192.168.1.2`，那么用上面一样的方法

```bash
test_phone=`nc -v 192.168.1.2 1080 -w 1 2>&1 | grep -c "succeeded"`
```

该值为1说明该设备1080端口开放。

这时候记录下

```bash
http_addr="http://192.168.1.2:1081"
```

与上一节同样，关掉开机自启的`v2ray`。

### 设置桌面代理

KDE：这里用路由器上有代理的情况举例。如果是其他设备有代理就把`route_addr`换成那个设备ip，如果都没有，就换成用本地`127.0.0.1`。

```bash
kwriteconfig5 --file $HOME/.config/kioslaverc --group "Proxy Settings" --key "httpProxy" "http://$route_addr 1081"
kwriteconfig5 --file $HOME/.config/kioslaverc --group "Proxy Settings" --key "httpsProxy" "http://$route_addr 1081"
kwriteconfig5 --file $HOME/.config/kioslaverc --group "Proxy Settings" --key "socksProxy" "socks5://$route_addr 1080"
```

Gnome的做法是：

```bash
gsettings set org.gnome.system.proxy mode 'manual'
gsettings set org.gnome.system.proxy.http host $route_addr
gsettings set org.gnome.system.proxy.http port 1081
gsettings set org.gnome.system.proxy.https host $route_addr
gsettings set org.gnome.system.proxy.https port 1081
gsettings set org.gnome.system.proxy.socks host $route_addr
gsettings set org.gnome.system.proxy.socks port 1080
```

### 设置git代理

```bash
git config --global http.proxy $http_addr
git config --global https.proxy $http_addr
```

### export http_proxy

Gnome的话直接在脚本里写上

```bash
export http_proxy=$http_addr
export https_proxy=$http_addr
```

对于KDE桌面的情况，考虑到环境变量基本上只在终端使用，编辑`.bashrc`或者zshell的`.zshrc`，在最后加入两行：

```bash
export http_proxy=`git config http.proxy`
export https_proxy=`git config https.proxy`
```

因为开机脚本设置的git代理是肯定没问题的，这样就保证每次开终端的时候这两个环境变量是等于git代理的。

### 设置登录时执行

KDE用户在`.bash_profile`（或者`.profile`）里加上

```bash
bash start.sh &
```

并且在`.bashrc`或`.zshrc`加入上节提到的两行。

Gnome用户可以直接

```bash
source start.sh
```

### 当网络环境变化时

如果你的电脑连上了另一个wifi，或者开机时没连上网络，但是又不想重启电脑的话，只需要

```bash
source start.sh
```

KDE用户关闭终端再开一次或者`source .zshrc`，就能获取新的`http_proxy`以及`https_proxy`。

到这里脚本就已经完成了。可以用`bash startup.sh`测试一下会不会报错，也可以先在第一行加`#!/bin/bash`然后`chmod +x`来加一个执行权限。

### 是否正确执行？

如果不确定脚本是否正常工作，可以在结尾`echo`一些内容输出到一个log文件里，比如在路由器上找到代理时，执行

```bash
echo "Found proxy in router. `date +'%m-%d %H:%M:%S'`" > startup.log
```
