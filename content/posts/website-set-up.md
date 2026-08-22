---
title: "Nginx+MariaDB+PHP+WordPress搭建个人网站"
slug: "website-set-up"
date: 2021-05-10T17:05:50+08:00
lastmod: 2025-08-11T01:45:59+08:00
wpid: 25
wpguid: "https://chr.fan/?p=25"
views: 7766
categories: ["技术"]
---

> 2023.10.28: Deprecated，见[服务器数据迁移记录](./vps-migrate)

建站的教程网上已经一抓一大把了，所以这篇文章并没有什么参考价值~~而且我并不懂什么Nginx和PHP~~，仅仅是作为个人存档用，以防万一之后网站要搬迁。

## 工具

* [Debian系](https://zh.wikipedia.org/wiki/Linux%E5%8F%91%E8%A1%8C%E7%89%88%E5%88%97%E8%A1%A8#Debian%E7%B3%BB)的Linux服务器，这里用Debian系的原因是~~我只会用Debian系~~Debian系统运行比较稳定

* 域名
* SSL证书

## 步骤

### 安装Nginx+MariaDB+PHP7.3+WordPress

这里主要参考[这篇文章](https://blog.csdn.net/Magic_Ninja/article/details/105941424)，他用的是php-7.4，我嫌麻烦就用了7.3，因为不更换源的情况下apt-get指令可以直接装7.3，但是7.4不行。以下是WordPress的提示：

> PHP是用以构建及维护WordPress的程序语言。较新版本的PHP在设计时以更好的性能表现为前提，所以使用最新的PHP版本会为您的站点带来更好的性能表现。推荐的最低PHP版本是7.4。

注意最好先装Nginx，再装PHP，否则最好先执行一下

```bash
sudo apt-get remove apache2
sudo apt-get autoremove
```

#### MariaDB

安装MariaDB

```bash
sudo apt-get update
sudo apt-get install mariadb-server
```

输入以下命令配置root密码：

```bash
sudo mysql_secure_installation
```

设置自己想要的密码即可。

#### WordPress数据库

配置WordPress数据库，用root登录

```bash
sudo mysql -uroot -hlocalhost -p
```

创建用户wordpress，这里把密码改为自己的密码：

```
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'password';
```

创建数据库：

```
create database wordpress default charset utf8 collate utf8_general_ci;
```

授予权限并刷新，这里`password`改为前面设置的密码

```
grant all privileges on wordpress.* to 'wordpress'@'localhost' identified by 'password';

flush privileges;
```

完成，退出数据库。

#### Nginx

安装Nginx

```bash
sudo apt-get install nginx
```

#### PHP

安装php7.3

```bash
sudo apt-get install php7.3
sudo apt-get install php7.3-fpm php7.3-cgi php7.3-curl php7.3-gd php7.3-xml php7.3-xmlrpc php7.3-mysql php7.3-bz2
```

把所有7.3换成7.4就可以安装7.4版本。

这里会显示Apache2运行失败。卸载Apache2

```bash
sudo apt-get remove apache2
```

检查是否安装成功

```bash
php -v
```

配置php，修改`/etc/php/7.3/cgi/php.ini`：

```ini
cgi.fix_pathinfo=1
```

修改`/etc/php/7.3/fpm/php.ini`：

```ini
cgi.fix_pathinfo=0
```

#### WordPress

进入`/var/www/`目录，没有的话就创建。下载最新版wordpress

```bash
cd /var/www/
sudo wget https://wordpress.org/latest.tar.gz
```

解压

```bash
sudo tar -xzvf <压缩包名>
```

将解压后的文件夹更名为`wordpress`，进入`wordpress`文件夹，复制一份sample配置

```bash
sudo cp wp-config-sample.php wp-config.php
```

打开`wp-config.php`，修改数据库的用户名和密码为前面设置的密码

```php
/** The name of the database for WordPress */
define( 'DB_NAME', 'wordpress' );

/** MySQL database username */
define( 'DB_USER', 'wordpress' );

/** MySQL database password */
define( 'DB_PASSWORD', 'yourpassword' );

/** MySQL hostname */
define( 'DB_HOST', 'localhost' );

/** Database Charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The Database Collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );
```

### 获取域名和SSL证书

域名直接买或者白嫖就行，SSL证书也可以白嫖，具体怎么弄就省略了。我是在腾讯云获取的SSL证书，域名正确解析完成之后，下载证书，里面会附带Nginx专用的SSL证书文件，一个是`crt`后缀一个是`key`后缀。把两个文件传输到`/etc/nginx/`目录，权限修改为只读。

### 配置https、伪静态、http重定向

修改`/etc/nginx/conf.d/default.conf`，这里的域名填自己的域名，证书文件名也对应地修改。一共要修改4处。如果用的是PHP7.4，还要注意替换里面的7.3。

```nginx
server {
    listen       443 ssl;
    server_name  your.domain;
    root /var/www/wordpress;

    ssl_certificate yourcertificate.crt; 
    #私钥文件名称
    ssl_certificate_key yourcertificate.key; 
    ssl_session_timeout 5m;
    #请按照以下协议配置
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; 
    #请按照以下套件配置，配置加密套件，写法遵循 openssl 标准。
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE; 
    ssl_prefer_server_ciphers on;

    #charset koi8-r;
    access_log  /var/log/nginx/host.access.log  main;

    location / {
        #root   /usr/share/nginx/html;
        index  index.html index.htm index.php;
        try_files $uri $uri/ /index.php?$args;
    }

    error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
    #    root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    location ~ \.php$ {
        #root           html;
        fastcgi_pass   unix:/run/php/php7.3-fpm.sock;
        fastcgi_index  index.php;
        #fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include        fastcgi_params;
    }

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    location ~ /\.ht {
        deny  all;
    }
}

server {
    listen 80;
    #填写绑定证书的域名
    server_name your.domain; 
    #把http的域名请求转成https
    return 301 https://$host$request_uri; 
}
```

重启两项服务

```bash
sudo systemctl restart php7.3-fpm
sudo systemctl restart nginx
```

重启正常的话，在浏览器输入域名，如果正确跳转到https，那么设置完成。接下来按照wordpress的提示一步步设置即可。
