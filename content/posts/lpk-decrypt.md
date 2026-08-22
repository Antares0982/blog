---
title: "Live2DViewerEX 创意工坊lpk文件分析 - 动态调试Unity程序"
slug: "lpk-decrypt"
date: 2021-09-01T04:45:13+08:00
lastmod: 2025-12-28T02:38:54+08:00
wpid: 138
wpguid: "https://chr.fan/?p=138"
views: 27249
categories: ["技术"]
tags: ["Live2D", "看板娘", "Live2DViewerEX", "lpk", "Unity", "逆向工程", "调试", "mono", "加密", "解密"]
---

> 声明：本人不会提供任何解密lpk文件的程序。本文仅仅是技术向的探讨、经验分享。
>
> 如果您认为本文侵犯了您的权益，请联系我，我会立刻删除这篇文章。

自从在博客上弄了看板娘之后，我就对Live2D产生了一些兴趣。去Google了一下别的看板娘，发现有个[Live2DViewerEX](https://store.steampowered.com/app/616720/Live2DViewerEX/)的程序在Steam上架，创意工坊里有很多Live2D模型。

于是乎在Steam上买了一个，下载下来之后发现，它的创意工坊文件是`.lpk`格式，对这样的文件我没有一点头绪。无奈再次Google，找到了一位大佬Chinuno Usami的博客文章：[Live2DViewerEX lpk格式加密分析](https://www.chinuno.com/blog/lpk-decrypt/)。本来我是想直接问问大佬如何解密的，但是为了Live2DViewerEX开发者的权益考虑，他当时建议我自己尝试。因为我从来没接触过逆向工程，最多只会反编译一下起源引擎的游戏插件稍微读一读的样子，再加上那时还在学期没有太多空闲，编译完mono就先把这事搁置了。时隔三个月我又想起了这件事，开始自己尝试逆向Live2DViewerEX。

Chinuno Usami大佬的博客内容写得比较含蓄，但是基本方法已经全部讲清楚了，于是我按照他的方法走了一遍，确实很快就找到了加密的逻辑，非常感谢大佬，博客给了我很大的帮助。下面的内容其实就是把他的博客内容稍微展开一点讲，嫌我废话太多的话可以直接去看大佬的博客~~能力越弱废话越多就是说我了~~，但是同样在关键的地方不可能讲得太详细了。话不多说开始正题。

### lpk文件观察

首先我们先观察一下lpk文件的结构。先暂时以创意工坊上的Potion Maker为例~~Pio超级可爱！！！~~。

一个Live2DViewerEX创意工坊文件包括一张图片，一个`config.json`和一个`.lpk`后缀的文件。实际上这个lpk是一个zip压缩包，我们解压打开它可以看到：

* 一堆文件名看起来像16进制数的文件，后缀为`bin`或者`bin3`；
* 一个体积比较大的无后缀文件（不一定会有？）；
* 一个很小的无后缀文件。

直接以文本文档打开那个小的无后缀文件可以看到，里面以json形式记录了这个Live2D模型的基础信息，avatar那项的值就是那个体积比较大的无后缀文件，costume下的path的值应该就是Live2D模型的入口文件了。但是那些bin文件打开全都是乱码。我们需要用专门的Unity调试工具来找到解密这些文件的方法。

### Unity调试工具

我们需要的动态调试工具是[dnSpy](https://github.com/dnSpy/dnSpy)。这个程序专门用于动态调试一些C#程序，尤其是Unity程序，是一个非常方便的工具。

dnSpy调试Unity时，会提示我们修复`mono.dll`，我估计大概是要解开调试的权限。于是还需要[dnSpy-Unity-mono](https://github.com/dnSpy/dnSpy-Unity-mono)。这个过程是比较简单的，按照仓库里README的做法一步步做就完事了，不过需要注意的是，这个仓库状态是Archived，所以要自己fork一份，并且切换到`dnSpy`这一开发分支上来完成。也可以直接用我[fork](https://github.com/Antares0982/dnSpy-Unity-mono)后生成好的仓库，在Live2DViewerEX还是用2019.4.26版本Unity的情况下，可以直接跳到下面步骤里的最后一个编译步骤。注意，最好在Steam里关闭Live2DViewerEX的自动更新，也不要去验证本地文件完整性。接下来的几个步骤就是~~废话~~解释下README文件说了些什么。

* 按照README的提示，编译好umpatcher之后，找到Live2dViewerEX的本地文件，属性里可以找到Unity版本号（到写这篇博客为止是2019.4.26版本）（2022年1月28日更新：感谢tnt_ts同学，现在增加了2019.4.32以及2019.4.34版本。欢迎大家给我的fork提pull request，或者邮件告诉我新的版本的commit hash）。
* 去[Unity下载页](https://unity3d.com/get-unity/download/archive)找到对应版本Unity Editor并下载，不需要安装。

* 用仓库里带的`extractmono.bat`提取时间戳，需要7z在PATH中。

* 下载仓库[mono](https://github.com/Unity-Technologies/mono)，checkout unity-2019.4-mbe分支，根据`dnSpy-Unity-mono`仓库里README的提示，用`gitk`找到时间戳前的那次merge的commit hash（2019.4.26版本是`90cf2678d79ad248593837523bde01561ee6548e`）
* `umpatcher 2019.4.26-mbe 90cf2678d79ad248593837523bde01561ee6548e "C:\path\to\Unity-mono" "C:\path\to\dnSpy-Unity-mono"` 在`dnSpy-Unity-mono`里生成一个该版本对应的Solution。这个操作会自动commit到`dnSpy-Unity-mono`中。记得把commit hash换成当前对应的那个hash。

* Visual Studio编译，配置是`Release`，平台是`x86`。用编译好的``mono-2.0-bdwgc.dll``替换Live2DViewerEX里的mono就行。可以只替换EXstudio里的mono，之后只调试EXstudio就能找到加密部分代码。

我印象中还遇到了一些编译上的坑，貌似是编译的时候少了些什么东西，下载下来添加进PATH就行了，具体是啥忘了（

### 开始调试

调试用`dnSpy-x86.exe`。点击上面的调试->开始调试，选择Unity，可执行文件选择EXstudio即可。

进去之后第一件事当然是尝试在下面的搜索框搜索`lpk`。不出所望，这段代码直接白给，如图。

![](/wp-content/uploads/2021/09/image-20210831182235324-300x229.png)


如果有一套Live2D模型，接下来的操作就会比较方便了，可以先去GitHub上找找博客用的Live2D模型。在这里设置断点，EXstudio里点击**LPK生成器**，加载Live2D入口json文件，动态调试（当然也可以直接静态地读代码，我第一遍没找到如何触发这个断点，直接读也读出来了，就是稍微有点费劲）发现，程序获取了当前的时间戳(milliseconds，精确到毫秒)，然后和文件名拼在一起运算出了一个key（文件名是用`ComputeHash()`得到的）。之后用这个key作为初始值，做了一些迷惑位运算（主要是异或）生成了我们所见到的`.bin`文件的内容。具体内容就不详细讲了，仔细读懂源代码很快就能得出这一结论。

观察整个过程可以了解到，在解密阶段，如果获取到了这个用时间戳和文件名拼接的key，就可以用完全相同的操作再次异或，得到源文件。问题在于，解密时，怎么知道生成lpk的时间？

一个直接的想法是：既然Live2DViewerEX能够解密这个lpk，那么这个时间戳必然存在于创意工坊信息文件`config.json`，或者那个没有后缀的文本文件中。果然，用LPK生成器生成的lpk文件里，没后缀的文本文件里记录的`id`项，就是我们所需要的时间戳，这一结论从源代码里也可以读出来（~~总之就是，方法非常多~~）。当然，如果有所怀疑的话，可以用这个时间戳除以1000，然后比对一下1970年开始经过的秒数。

### 尝试解密

用EXstudio加密好自己的lpk之后，接下来，可以先直接用熟悉的语言写一个解密器尝试一下。但是，**仅限用LPK生成器生成的LPK文件。**

为什么steam创意工坊的文件就行不通了呢？仔细观察我们能注意到，刚刚生成的lpk里，`type`这一field的值是`"STD2_0"`。但是创意工坊里的文件，这一值是`"STM_1_0"`。`ExportLpk()`这个函数只能生成`STD2_0`的lpk文件。

我们可以想到，输出成创意工坊文件的代码和`ExportLpk()`这一段不太相同，但是和`"STD2_0"`一样，应该会明文地出现在代码某处。这回我们需要尝试找出`STM_1_0`这个字符串出现在源代码的什么地方，设置断点之后在程序里点击创意工坊上传器->Live2D应该就能调试到这段过程。

在下面的搜索栏中设置为搜索*数字/字符串*，然后一个个找一下，果然立刻找到了那段代码。有了前面的经验，很快就能找到key是如何生成的。

![](/wp-content/uploads/2021/09/image-20210831191219108-300x215.png)

之后的内容就不再详细说了，如果上面步骤都能够跟着做了并且读懂了源代码，到这里估计早就找到key的生成方法了（

### 解密程序

接下来收尾啦，用喜欢的语言写个解密程序吧。

Live2D文件里包括`.mtn`，`.moc`，`.json`，`.png`，`.wav`，`.ogg`等后缀的文件，以及那个很大的无后缀Avatar文件（这个文件是未加密的，直接后缀改成`.png`就可以打开）。部分文件解密之后可以用文件开头的512个byte来判断文件MIME类型，比如`.png`，`.wav`文件，具体方法可以去网上查一查。`.mtn`和`.json`都是文本文件，判断一下里面的内容就知道哪个文件是哪个类型了。

我写了一个Go的解密程序，还包括自动改文件名、后缀和对应json值的功能，创意工坊的Potion Maker解密之后，得到了100多套服装以及一大堆的json文件。当然还测试了很多其他的创意工坊lpk，效果很好。

![](/wp-content/uploads/2021/09/image-20210901035145560-768x72.png)

![](/wp-content/uploads/2021/09/image-20210901034140003-768x348.png)

~~（结果，写解密程序反倒花时间最长。耽误了好久的时间，正事儿没干，爬了）~~
