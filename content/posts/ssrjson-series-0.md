---
title: "ssrJSON: 如何写出性能最高的Python JSON库？（简介）"
slug: "ssrjson-series-0"
date: 2025-08-11T02:11:11+08:00
lastmod: 2025-08-11T02:15:41+08:00
wpid: 407
wpguid: "https://chr.fan/?p=407"
views: 12568
categories: ["技术"]
tags: ["Python", "C", "JSON", "SIMD", "orjson", "yyjson", "ssrJSON", "JSON parsing", "DragonBox"]
---

> TL;DR: 笔者开发的[ssrJSON](https://github.com/Antares0982/ssrJSON)是一个利用SIMD加速的Python JSON解析库，主要使用C语言编写。在绝大多数测试用例中，比之前*世界上性能最高*的Python JSON解析库[orjson](https://github.com/ijl/orjson)快；在处理非ASCII字符串（例如中文）以及浮点数时，有极大的性能优势。

## Intro

ssrJSON是一个使用C/C++编写的Python JSON库，利用现代硬件的SIMD指令以达到尽可能高的JSON编解码性能。ssrJSON会检测硬件支持的SIMD特性，自动选择合适的SIMD指令集进行编解码。

ssrJSON提供了与Python标准库json模块兼容的两个接口`dumps`和`loads`，额外提供一个接口`dumps_to_bytes`，将编码的结果输出为bytes类型。

### 编码

JSON库的编码性能基本上不会受到Python语言本身相关的限制，可以说上限极高。ssrJSON在编码字符串时，大规模应用了SIMD指令进行拷贝与转换；`dumps_to_bytes`的实现还需要额外考虑UTF-8编码相关的问题，ssrJSON对所有支持的SIMD特性以及Python字符串（PyCompactUnicodeObject）格式，都实现了一套完整的UTF-8编码算法。对于浮点数的编码，ssrJSON使用了稍微修改的[DragonBox](https://github.com/jk-jeon/dragonbox)算法（一个性能极高的浮点转换算法）。对于整数的编码，使用了[yyjson](https://github.com/ibireme/yyjson)（一个性能极高的C语言JSON解析库）中对整数的编码算法。

### 解码

JSON库的解码性能主要瓶颈在于创建Python对象的速度。因此，ssrJSON使用了[orjson](https://github.com/ijl/orjson)的短键缓存算法，大幅降低Python字符串对象创建的开销。对于字符串处理，当输入为str类型时，与编码同样大规模应用了SIMD指令以加速解码过程；当输入为bytes类型时，ssrJSON应用了一个魔改的yyjson字符串解码算法。除此之外，解码算法大规模复用了yyjson的相关代码，包括数字相关的解码算法、解码主逻辑等。

## 用法

ssrJSON已经分发到PyPI，安装ssrJSON只需`pip install ssrjson`即可，支持Python3.9+。

ssrJSON的接口设计几乎和json模块兼容，目前提供了`dumps`, `loads`以及`dumps_to_bytes`，前二者接受的参数和`json.dumps`，`json.loads`相同，因此在很多简单用法下可以用`import ssrjson as json`完全替换。`dumps_to_bytes`的输出大多数情况下等价于`dumps`后接一个将str类型按UTF-8编码为bytes类型的操作。一些细节的差异请参见[README](https://github.com/Antares0982/ssrJSON?tab=readme-ov-file#features)。

## 基准测试

> ssrJSON有专用的性能基准测试仓库[ssrJSON-benchmark](https://github.com/Nambers/ssrJSON-benchmark)，下面的数据均来源于该仓库提供的benchmark脚本。以下以Intel i13700k，Python3.13环境为例，简单阐述一下ssrJSON的基准测试性能，设备SIMD特性等级为AVX2（x86-64 v3），原始统计数据在[这里](https://gist.github.com/Antares0982/0dfcc172bbb80fffbc22ccd9cb28ff58)，PDF报告在[这里](https://github.com/Antares0982/ssrJSON-benchmark/blob/6438552af4be34a5d6ebed9a440fe5fb5d63b371/results/AVX2/i7-13700K_0.0.3.pdf)。为了节省篇幅，带缩进的情况文中暂时省略。

除标准库json模块外，我们还会与orjson做对照，版本为3.10.16。其他第三方JSON解析库的速度已经被orjson碾压了，不做比较。因为`orjson.dumps`输出的是UTF-8编码的bytes类型对象，对比测试`ssrjson.dumps`时我们使用`json.dumps`以及“`orjson.dumps`后接`str.decode("utf-8")`”（简称`orjson.dumps + decode`）进行比较；对比测试`ssrjson.dumps_to_bytes`时，用“`json.dumps`后接`str.encode("utf-8")`”（简称`json.dumps + encode`）以及`orjson.dumps`进行比较。

在开始之前需要先说明一个非ASCII的字符串相关的orjson特性。orjson的实现中没有UTF-8编解码相关的功能，而是直接使用了CPython提供的一些接口，例如`PyUnicode_AsUTF8AndSize`。这些接口会将非ASCII的`PyUnicodeObject`进行UTF-8编码，然后将UTF-8表示缓存在该`PyUnicodeObject`对象（也就是Python的str）中。当下一次再需要取用这一对象的UTF-8表示时，可以直接使用该缓存，但代价是增加内存占用。编码时orjson只会输出UTF-8编码的bytes类型；解码时如果输入是str类型，orjson目前（v3.11.1）的实现是先将其进行UTF-8编码，然后再开始JSON解码，因此编解码都会用到类似的CPython接口。在测试用例内容是纯ASCII时，由于`PyUnicodeObject`本身内容就符合UTF-8编码了，不会进行上述缓存操作，因此不会导致性能测试结果有偏差；但对于测试用例中有非ASCII字符时，在使用完全相同的字符串对象（地址相同）进行基准测试时，除了第一次之外，后续都会加快很多。复用完全相同的对象进行反复编解码在实际生产环境中不是一个常见的行为，因此为了贴近真实情形，ssrJSON-benchmark中会使用值相等的不同对象来进行基准测试。笔者发现orjson的基准测试脚本没有考虑这一情况，向orjson提交了[issue](https://github.com/ijl/orjson/issues/586)说明这一问题，但被其维护者直接无视掉了。使用一个[简单的纯中文JSON用例](https://github.com/Nambers/ssrJSON-benchmark/blob/main/src/ssrjson_benchmark/_files/simple_object_zh.json)测试发现，orjson的dumps后接decode，性能比json.dumps还低，只有标准库json的74%的速度。仅orjson.dumps，也只比json.dumps + encode快20%左右，如下图。

![](/wp-content/uploads/2025/08/simple_object_zh.json.svg)



### ASCII

对仅含ASCII字符串的JSON（四个测试用例），ssrJSON编码的性能约为2~4GB/s（由于均为ASCII，dumps和dumps_to_bytes区别不大），速度约为Python的JSON标准库json的8～12倍。解码性能约为1~1.5GB/s，速度约为json的2～4倍。

![](/wp-content/uploads/2025/08/simple_object.json.svg)

特殊构造的简单纯ASCII用例[simple_object](https://github.com/Nambers/ssrJSON-benchmark/blob/main/src/ssrjson_benchmark/_files/simple_object.json)，`dumps`约为13.88GB/s，`json.dumps`的约14.23倍，`dumps_to_bytes`约为13.94GB/s，`json.dumps + encode`的约14.57倍。`loads`在str输入和bytes输入两种情况下相差不大，为`json.loads`的约1.9倍。

### 非ASCII

非ASCII的情况，由于Python对PyUnicodeObject的设计比较复杂、每个测试用例字符类型占比不一致，`dumps`每秒输出的字节数变化较大，整体约为json的6~9倍（三个测试用例）。`dumps_to_bytes`使用了原创的Python字符串UTF-8编码SIMD加速算法，是`json.dumps + encode`的6~10倍。`loads`约为`json.loads`的2～4倍。

![](/wp-content/uploads/2025/08/simple_object_zh.json.svg)

前面提到过的特殊构造的简单纯中文用例[simple_object_zh](https://github.com/Nambers/ssrJSON-benchmark/blob/main/src/ssrjson_benchmark/_files/simple_object_zh.json)，`dumps`约为16.60GB/s，`json.dumps`的约17.61倍，`dumps_to_bytes`约为13.83GB/s，`json.dumps + encode`的约10.11倍。`loads`在str输入和bytes输入两种情况下相差不大，约为3.77GB/s，`json.loads`的约2倍。

### 数字类型

![](/wp-content/uploads/2025/08/canada.json.svg)

得益于Dragonbox算法与yyjson，浮点的编解码性能相对于json而言快很多（也和CPython本身的json实现对浮点的处理很慢有关）。以[canada.json](https://github.com/Nambers/ssrJSON-benchmark/blob/main/src/ssrjson_benchmark/_files/canada.json)为例（绝大部分对象为浮点），`dumps`约为json的22.98倍，`dumps_to_bytes`约为json的23.19倍。`loads`则是7.5倍左右。

![](/wp-content/uploads/2025/08/mesh.json.svg)

另一个数字很多、float与int都大量出现的用例[mesh.json](https://github.com/Nambers/ssrJSON-benchmark/blob/main/src/ssrjson_benchmark/_files/canada.json)，`dumps`和`dumps_to_bytes`约为json的20倍，`loads`约4倍。

## Future Ideas

ssrJSON开发状态仍处于Beta阶段，一些json模块支持的、比较有用的特性尚未实现（例如object_hook），以及目前尚未支持ARM（Neon）架构。这些feature都在计划当中，对ARM Neon的支持将是重点（目前的设计允许轻松地扩展到其他SIMD指令集，但很多细节仍需考虑）。欢迎广大开发者向ssrJSON贡献代码！
