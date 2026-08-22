---
title: "服务器数据迁移记录"
slug: "vps-migrate"
date: 2023-10-28T20:45:58+08:00
lastmod: 2025-08-11T01:24:49+08:00
wpid: 367
wpguid: "https://chr.fan/?p=367"
views: 5952
categories: ["技术", "记录"]
tags: ["Linux", "服务器", "迁移", "搬迁", "WordPress", "Ubuntu", "Debian"]
---

> 仅个人记录，不保证适用于其他任何人。
>
> reference: 之前写的[Nginx+MariaDB+PHP+WordPress搭建个人网站](./website-set-up)，~~根本没卵用，想穿越回去捅自己~~ ~~我超，真要搬迁啊，预言家刀了~~ 也算是进步记录。
>
> 细节部分在网上一搜大把，~~加上实在是懒得写博客赶紧十分钟水完完事了很烦的好吗~~ 所以不会写得很详细，毕竟也不是两年前那个Linux小白了。

由于博客服务器用的Debian软件包实在过旧，有一些代码很难跑起来。时间累积之后越来越难忍受 ~~玩Arch Linux玩的~~。于是决定系统迁移到Ubuntu，保证稳定性的前提下用一些稍微新一点的软件包。

## 迁移备份数据

服务器迁移所需要备份的内容：

* WordPress
* 数据库
* `/etc`目录
* ssl证书
* 各用户家目录数据文件
* 其他需要的数据

### WordPress

直接将WordPress目录整个打包下来。注意先检查一些临时文件，这些没必要打包进去，如一些插件的storage，如果觉得没必要就先rm了。

我的主题用的是Sakura，安装的时候用的git clone，可以先把当前的修改打成patch然后备份这个patch。当然求稳的话还是要整个目录也备份一下的。

### 数据库

使用`mysqldump`备份即可。备份导出的文件是一个sql源文件。后文 will refer to `dump.sql`。

### etc目录、ssl证书、家目录数据、其他数据

每个目录直接整个打包。`/etc`目录实际上非常小，备份下来只是给之后改配置做参考，不是拿来解压放进新系统的。比较大的是家目录，如果存了很多东西就先筛选一下需要的东西。我自己用的话，不用打包`.local`、`.config`这些，环境重新配起来非常快，而且通常迁移到新机后旧的库也不会兼容。

迁移部分就以上内容，非常简单。

### sftp太慢了？

~~那就别用SFTP~~ ~~什么你没听明白~~ ~~没事我明白就行~~

## 在新系统恢复数据

### 需要的软件包

创建sudo用户、配置ssh密钥、关闭密码登录、apt-get update upgrade都做完之后就可以开始装包了。这里必要的只有很明显需要的那些，`php-*`除了fpm其他都是一些插件，可要可不要。

```shell
sudo apt-get install mariadb-server nginx php php-curl php-dom php-fpm php-gd php-imagick php-intl php-mbstring php-mysql php-zip
```

### 配置php-fpm

建议配置`nginx`前先配置`php-fpm`。前面安装的`php-*`这些是php插件，有些需要在`/etc`目录下找到`php-fpm`的配置文件`php.ini`来启用。具体哪些在里面需要启用可以用`nano`的ctrl+W搜。除此之外`mysqli`必须启用，其他的不启用（甚至不装）问题也不大。

`cgi.fix_pathinfo`？~~就当它不存在，好吗~~

### 配置nginx

nginx的配置文件可以从之前备份的`/etc`目录里复制过来用，但没必要全部复制过来。注意如果出现错误可以直接命令行跑下nginx看它报什么错，照着改就行。

### 恢复数据库

首先systemd启动mariadb。添加WordPress数据库。添加WordPress用户，名字和密码参考备份的WordPress里的`wp-config.php`里的，注意flush privilege。用对应用户登录进去，`source dump.sql`。

### 恢复WordPress

最好不要把原本备份的WordPress直接解压放回去，除非在备份前WordPress和php版本已经是最新，否则很可能出现不兼容的情况。而且绝大多数之前备份的东西都没必要。

从官网上下载到最新的WordPress，解压到对应目录之后可以先`chown -R www-data:www-data wordpress`（~~查询之前把整个目录owner设置成`root`的精神状态~~）。直接去访问网站。填好数据库密码和用户之后创建出`wp-config.php`。

把原本备份下来的内容复制过去（先不管plugins），注意权限给到`www-data`。包括：

* themes，只复制备份前用的那个。之前的git patch可以拿来用了，clone最新的主题然后apply patch也行
* uploads目录

恢复插件。这一步只需要去WordPress商店把原本有的插件一个个装上就行，如果出现商店里没了的插件，那就不要恢复那个插件了，很可能deprecated。

站点健康的页面缓存那不用管，交给`nginx`。

### 恢复家目录数据

解压就行。

## 看起来好像备份恢复很简单？

实际上是踩了一些小坑的，是因为之前的bad designs累积起来导致的。随时记住[KISS法则](https://en.wikipedia.org/wiki/KISS_principle)，否则就很容易踩坑。
