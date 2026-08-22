---
title: "Arch踩坑记录"
slug: "arch-pitfalls"
date: 2021-10-23T17:49:36+08:00
lastmod: 2025-12-28T02:40:14+08:00
wpid: 172
wpguid: "https://chr.fan/?p=172"
views: 11400
categories: ["记录"]
tags: ["Linux", "Arch", "记录"]
---

> 本文已经过时。笔者已经切换到[NixOS](https://nixos.org/).
> 本文最后一次更新并检查内容的时间：2025年12月28日

> 不定期更新遇到的新问题，仅做记录，仅限我的各安装了Arch Linux的设备上可能可以如下解决问题

### 无声音，No input or output devices found

```shell
sudo pacman -S sof-firmware
sudo pacman -S alsa-ucm-conf
```

#### 无线网卡

去google对应型号网卡的解决方案。有可能需要make一些组件进依赖库。

### PDF中文字体不显示

```shell
sudo pacman -S poppler-data
```

### Linux QQ

> ~~2022年4月15日 Update: 参考AUR package [deepin-wine-qq](https://github.com/vufa/deepin-wine-qq-arch/tree/action)的官方文档~~
> 2023年10月15日 Update: 请安装AUR package [linuxqq](https://aur.archlinux.org/packages/linuxqq)

### 一定概率下，开机时卡住数十秒，之后关机/重启时必然卡住10分钟以上

> tl;dr: 请慎用`systemctl enable`来开机启动某些服务。

ref: [systemd - Debugging](https://freedesktop.org/wiki/Software/systemd/Debugging/), Diagnosing Shutdown Problems

以下是排查步骤，不是解决步骤：

1. 启动时在grub界面添加启动参数`systemd.log_level=debug systemd.log_target=kmsg log_buf_len=1M printk.devkmsg=on enforcing=0`。

2. 创建可执行文件`/usr/lib/systemd/system-shutdown/debug.sh`，写入如下内容

   ```sh
   #!/bin/sh
   mount -o remount,rw /
   dmesg > /shutdown-log.txt # 最好换成家目录 /home/xxx/shutdown-log.txt
   mount -o remount,ro /
   ```

3. 重启。如果没有遇到卡住的情况就反复重启，直到复现问题为止。（也可以直接将启动参数设为默认，省得每次启动都重设一次，这个搜一下就知道怎么弄，不细说了）
4. 出现问题之后，下次启动时检查`shutdown-log.txt`，找到具体是哪里卡住。

### 关机时， A stop job is running for User Manager for UID 1000 卡住一分钟以上

原因是`systemctl --user`启动的某个服务在关机时没有正确处理`SIGTERM`，导致卡住很久，最终systemd会用`SIGKILL`来杀它。排查方法：下次启动后，观察上次启动时的日志，倒序查看

```shell
journalctl --boot=-1 -r
```

观察时间和报错，找到超时的原因。以我这里为例

```journal
Feb 12 03:13:05 AntaresArch systemd[989]: xdg-document-portal.service: Failed with result 'timeout'.
Feb 12 03:13:05 AntaresArch systemd[989]: xdg-document-portal.service: Main process exited, code=killed, status=9/KILL
Feb 12 03:13:05 AntaresArch systemd[989]: xdg-document-portal.service: Failed to kill control group /user.slice/user-1000.slice/user@1000.service/session.slice/xdg-document-portal.service, ignoring: Invalid argument
Feb 12 03:13:05 AntaresArch systemd[989]: xdg-document-portal.service: Killing process 1114 (fusermount3) with signal SIGKILL.
Feb 12 03:13:05 AntaresArch systemd[989]: xdg-document-portal.service: Killing process 1098 (xdg-document-po) with signal SIGKILL.
Feb 12 03:13:05 AntaresArch systemd[989]: xdg-document-portal.service: State 'stop-sigterm' timed out. Killing.
```

然后去解决掉对应进程即可。

### Clion，Chrome和VSCode同时打开会卡死：swapfile太小

> tl;dr: 推荐8G及以上内存的计算机分配至少8G的swap空间。

原先swapfile只有2G。先关闭swap，注意这里swap路径是`/swapfile`

```shell
sudo swapoff /swapfile
```

将swap改为8G

```shell
sudo fallocate -l 8G /swapfile
```

启动swap

```shell
sudo mkswap /swapfile
```

另外，可以设置用swap的频率，0-100，值越大会越频繁地用swap：

```shell
sudo sysctl vm.swappiness=60
```

检查目前这一值是多少（我的笔记本是60）：

```shell
cat /proc/sys/vm/swappiness
```

### pip broken

问题如下：

```shell
> pip
...(数十行traceback)
ImportError: cannot import name 'appdirs' from 'pip._vendor' (/usr/lib/python3.10/site-packages/pip/_vendor/__init__.py)
```

> 不要随便`rm -rf` /usr/lib/python3.X/site-packages文件夹以及里面的包啊！就算环境是python3.10删3.9的包也最好不要，但是家目录下面那个可以删了排查一些奇怪的问题。以及不要用sudo权限跑`pip freeze | xargs pip uninstall -y`！！

解决方法：

```shell
sudo pacman -S $(pacman -Qqo /usr/lib/python3.10)
```

### VSCode 无法同步设置和插件

新版本(1.66)的vscode取消了sync的命令行token，但是xdg-open不支持vscode的authentication，解决方案：先回退到稳定版本1.63.2，成功sync之后升级到新版本。（反正登录只需要一次，之后输个密码就行了）

### KDE 开机界面输入密码后卡死

我的最终解决方案是，进入tty2
```shell
rm ~/.Xauthority*
```
然后重启（并不保证这类问题全部适用）。如果没法解决可以尝试删除`~/.cache`，`~/.config`甚至`~/.local`，再不行试试重装plasma吧。

### Inkscape缺失python依赖

```shell
pip3 install lxml
pip3 install cssselect
```

### 迁移到新设备上的Arch Linux相关问题

#### BIOS找不到grub的启动条目

`grub-install` 时使用`--removable`参数即可，详情可见[Arch Linux 安装使用教程](https://archlinuxstudio.github.io/ArchLinuxTutorial/#/rookie/basic_install?id=_16%e5%ae%89%e8%a3%85%e5%bc%95%e5%af%bc%e7%a8%8b%e5%ba%8f)

#### 安装后Grub里找不到Linux

> 您是不是在跑`pacstrap`之前没有mount boot分区？？？

#### F1-F12功能键失效，或者功能异常

~~是腹灵导致他这样的.jpg~~ 参考Arch Wiki [Apple Keyboard](https://wiki.archlinux.org/title/Apple_Keyboard)，编辑`/etc/modprobe.d/hid_apple.conf`

#### pacman装包时突然系统crash导致安装出错

这个事情并不常见……只能简单记录下问题和最终解决方案。

问题表现：装fcitx5的时候不小心装到了fcitx相关的一个包，装的过程中系统卡死任何操作都无法响应。长按关机后重启，每次执行`pacman`安装的时候都会有类似这样的警告：
```
ldconfig: File /usr/lib/libQt6OpenGL.so.6.5.2 is empty, not checked.
ldconfig: File /usr/lib/libQt6Gui.so.6.5.2 is empty, not checked.
ldconfig: File /usr/lib/libQt6Gui.so is empty, not checked.
ldconfig: File /usr/lib/libfcitx-utils.so is empty, not checked.
ldconfig: File /usr/lib/libfcitx-core.so.0 is empty, not checked.
ldconfig: File /usr/lib/libQt6Test.so is empty, not checked.
```

初步解决方案：`pacman -Qkk`找到所有错误，发现实在过多，先把fcitx相关的包全部移除之后把`pacman -Qkk`的输出提及到的无效文件全部`rm`掉。

后续：发现chrome和typora无法使用输入法（fcitx5）。使用命令行打开typora，发现如下报错：
```
Gtk-WARNING **: 18:05:35.095: Loading IM context type 'fcitx' failed
```
最终解决方案：运行`fcitx5-diagnose`
```
Cannot load module /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx.so: /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx.so: file too short
/usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx.so does not export GTK+ IM module API: /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx.so: file too short

        Found `gtk-query-immodules` for unknown gtk version at `/usr/bin/gtk-query-immodules-3.0`.

        **Failed to find fcitx5 in the output of `/usr/bin/gtk-query-immodules-3.0`**

        **Cannot find `gtk-query-immodules` for gtk 3**

        **Cannot find fcitx5 im module for gtk 3.**

3.  Gtk IM module cache:

    1.  gtk 2:

        **Cannot find immodules cache for gtk 2**

        **Cannot find fcitx5 im module for gtk 2 in cache.**

    2.  gtk 3:

        Found immodules cache for gtk `3.24.38` at `/usr/lib/gtk-3.0/3.0.0/immodules.cache`.
        Version Line:

            # Created by /usr/bin/gtk-query-immodules-3.0 from gtk+-3.24.38

        **Failed to find fcitx5 in immodule cache at `/usr/lib/gtk-3.0/3.0.0/immodules.cache`**

        **Cannot find fcitx5 im module for gtk 3 in cache.**
```
`file too short`就是一个提示，`sudo rm /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx.so`，然后再次`sudo pacman -S fcitx5-im`解决问题。

~~小心fcitx~~

#### pacman装包校验失败

记得装完系统要装`archlinuxcn-keyring`。

### VSCode从自行安装的二进制包迁移到AUR的visual-studio-code-bin仓库导致的一系列问题

> 这个操作，正常人类不一定能碰得到……总之装软件一定要先看Arch Wiki，不然容易犯错。想用微软源的vscode包不用自己去官网装，直接AUR装`visual-studio-code-bin`就行。

安装`visual-studio-code-bin`时忘了从KDE的desktop entry里删掉自定义的code项，装完之后删了已经来不及了，首先是AUR的code没有生成desktop entry，其次是一堆文件类型的file association还在关联旧的那个code。

初次尝试的时候将两者文件都先删干净，原KDE desktop entry删除，然后重装`visual-studio-code-bin`，结果还是没有生成新的desktop entry。只好重新自己写一个desktop entry给AUR版本的，结果发现设置的图标在其他地方大都能生效，就底部任务栏上显示不出，file association还是有很多文件类型关联在旧的code上。最终解决方案：vscode打开`~/.config`，全局全字不忽略大小写搜code，发现了`code.desktop`以及`code-2.desktop`，~~太好了，我逐渐理解一切.jpg~~直接把全部`~/.config`下的`code-2`字符串全删了换成`code`，然后把`code-2.desktop`覆盖掉`code.desktop`。粗暴，但有效（
