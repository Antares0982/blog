---
title: "xjb 与 zmij: 最快的浮点转字符串算法之争"
slug: "xjb-vs-zmij"
date: 2026-08-09T17:46:46+08:00
lastmod: 2026-08-09T17:46:46+08:00
wpid: 771
wpguid: "https://chr.fan/?p=771"
views: 102
categories: ["技术"]
tags: ["ftoa", "dtoa", "benchmark", "fastest", "xjb", "zmij", "double", "float", "performance"]
---

> 阅前注意：这不是一篇严谨的综述文章，理论部分可能存在错误。性能结果相关内容时效性不长，撰写于 2026 年 7 月 22日。
> ~~本文由能工智人编写（~~. 

前几个月我给目前最快的两个 ftoa 算法都提交了一些核心热点路径上的 SIMD 性能优化 PR ，这篇博客是以第三方+一线参与视角总结一下目前（2026年中）前沿  ftoa 算法和实现的现状。感觉 AI 时代绝大多数人可能都不关心这些底层算法的实现了，但个人觉得比较有趣，就随便写点了，~~基于人类幻觉~~想到啥说啥。

## 前言

*浮点数转最短十进制字符串*也算是计算机科学的一个老生常谈话题了，几乎所有的 GUI 程序和 JSON 序列化都有将浮点数转为十进制字符串的需求，也就是 ftoa (float to ASCII)，本文后续会一直用该术语。这一问题有一个公认的事实标准，由论文 *How to Print Floating-Point Numbers Accurately （Steele & White, 1990）* 给出： 

* No information is lost; the original fraction can be recovered from the output by rounding.
* No "garbage digits" are produced.
* The output is correctly rounded; It is never necessary to propagate carries on rounding.

ftoa 问题的核心难点在于，保证正确性的同时还要跑得快。从 Dragon4 算法开始，经过数十年的演变，到 2025 年为止，实现正确且本身能保证高性能的 ftoa 算法非 [Schubfach][] (Raffaello Giulietti) 莫属。该算法用鸽巢原理证明最短十进字符串表示不可能超过某个精度，然后在 128 位范围搜索（ Schubfach 这个名字本身就来自于鸽巢原理的德文）。这部分论证可以直接点进 [Schubfach][] 论文去看，它成为了后续几乎所有快速 ftoa 实现的理论基础。现在你几乎能在各个高性能有关的算法仓库里看到 Schubfach 的预查表，比如前段时间随手翻了一下字节的 [sonic](https://github.com/bytedance/sonic/blob/579b6ffa7b3b36665600615500a2bf2d59964c5c/native/tab.h#L71) 就有它的预查表。

假定 $0 \lt a \lt v \lt b$ 且两两为 nextafter ，对于浮点数 $v$ 的满足 S & W 条件的 ftoa 问题，按照 Schubfach 模型，可以将其做如下简化。舍入区间 $R_v$ 为两个中点值之间的部分：若 $v$ 的最后一bit为1则为开区间 $(\frac{a+v}2,\frac{v+b}2)$ ，否则为相同边界的闭区间。核心任务是将浮点数 $v=c \cdot 2^q\ (c, q \in \mathbb Z)$ 转换为一个数值接近的十进制值 $d \cdot 10^k \in R_v \ (d, k \in \mathbb Z)$ 。

2025 年为止比较快的 ftoa 实现有：

* [Dragonbox][] (Junekey Jeon   [@jk-jeon](https://github.com/jk-jeon)): 在 Shubfach 算法基础上做了一些改良
* [yy_double][] (郭耀源 [@ibireme](https://github.com/ibireme/)): [yyjson][] 生态的高度工程化实现，从预查表内容上可以看出也是基于 Schubfach
* ~~以及其他我听过或者没听过的~~

自 Schubfach ，各 ftoa 实现的前半部分已经大同小异了，基本上都是几次乘（除）法、移位得出十进制数字字符串。于是真正拉开性能差距的变成了后半段，即：如何把算出来的十进制数字快速摆放成最终的 ASCII 字符串。


## 为什么 xjb 与 zmij 快？

2025 年 10 月， xjb 的作者 [xjb714][] 在 [Victor Zverovich](https://github.com/vitaut) 维护的高性能 C/C++ formatting 库  [{fmt}](https://github.com/fmtlib/fmt) 发 [issue #4590](https://github.com/fmtlib/fmt/issues/4590)，宣告了 xjb 算法的诞生。其算法基于前人的算法上做了一些改良，最初的版本没有经过高度的工程化，但 benchmark 显示，速度超过了 yy_double ，比 dragonbox 快了一倍还多。

2025 年 12 月， Victor 发表了一篇[博客](https://vitaut.net/posts/2025/faster-dtoa/)，宣告了 [Żmij][] 的诞生，并打算用 zmij 替掉现有的 {fmt} ftoa 实现。

> Żmij: 波兰语，从最开始的 Dragon4，到 Grisù, Ryū, dragonbox 各个算法/实现，名字都和龙带点关系，全家都是龙（
> 那个 Ż 字母不好打，所以都是用 zmij 代称（

根据其性能测试数据，[zmij][] 性能比 [Dragonbox][] 快了 68% 。博客中说到，  [zmij][] 对基础的 [Schubfach][] 做了大量工程改良，包括将 64 位乘法改为 32 位乘法以减少指令数、用魔数乘法代替 CPU 上昂贵的除法运算、用 csel/cmov 来减少条件分支等。这些工程优化其实不算什么新东西，在各个高性能库中类似的思路随处可见，例如 [yyjson][] 大量应用了这种技法，但将其综合起来应用正是初版 [zmij][] 快的秘诀。

很快，凭借 Victor 在开源界的影响力， zmij 很快有了[Rust 移植版本](https://github.com/dtolnay/zmij)，并迅速地在全世界范围内广泛传播。随后几个月，xjb 和 zmij 两边都进行了大量迭代，速度变得越来越快，将其他所有 ftoa 远远甩开了。

### 快速路径的问题拆解

下面以 double 为例（dtoa）。根据 S & W 的准则，dtoa 必须满足 round-trip 和最短原则；Schubfach 证明了，double 转十进制字符串，其有效数字最多为17位。这意味着我们可以先将问题简单地拆解成这样的形式：

* 用类 Schubfach 的算法，快速算出前面提到的 $d$ 和 $k$（u64 足够表示17位十进制整数数字），以及其小数点位置、指数大小
* 将 $d$ 转为 ASCII，写入 $[{\rm buf}, {\rm buf}+17)$  范围
* 根据输出格式是科学记数法还是整数，用 memmove() 给小数点和指数部分腾出空间，然后写入它们，去掉末尾多余的0。例如 $d=12345678900000000$, $k=-13$,  就是将已经写好的 `"12345678900000000"` 转为 `"1234.56789"` 或者 `"1.23456789e3"` 。

### xjb 的 scaling 改良

xjb 算法对基本的 Schubfach 方案做了 scaling 改良。该改良的核心思想是，通过少乘一个 10 ，得到短结果并单独算是否需要额外一位以及额外一位是什么值。这部分优化能够在关键热点路径上减少一些计算量，增加指令级并行度。本小节后续内容由 [xjb714][] 友情贡献（

仅对于regular浮点数（irregular 情况的个数有限，可以直接穷举），即 $v-a=b-v$，令 $k = \lfloor q \cdot \log_{10}(2) \rfloor$ 

* 先找较短表示是否存在。将浮点数 $v$ 拟合到间隔为 $10^{k+1}$ 的一维数轴刻度上，离浮点数最近的两个上下限间隔刻度值为 $\lfloor v \cdot 10^{-k-1} \rfloor$ 和 $\lfloor v \cdot 10^{-k-1}  \rfloor + 1$ ，即两个候选值 $\lfloor v \cdot 10^{-k-1}\rfloor  10^{k+1}$ 和 $\lfloor v \cdot 10^{-k-1} +1 \rfloor 10^{k+1}$ ，若存在有一个候选值处于 $R_v$ 区间范围内，则选择该值作为满足 S & W 原则的值，若两个值都不满足条件则 fallback 到下一步。可以证明两个候选值不可能同时满足条件。

* 将浮点数 $v$ 拟合到间隔为 $10^k$ 的数轴刻度上，离浮点数最近的两个上下限间隔刻度值为 $\lfloor v \cdot 10^{-k} \rfloor$ 和 $\lfloor v \cdot 10^{-k} \rfloor + 1$ ，即两个候选值 $\lfloor v \cdot 10^{-k} \rfloor 10^k$ 和 $(\lfloor v \cdot 10^{-k} \rfloor+1) 10 ^ k$ ，此时选择离浮点数 $v$ 最近的那个值（ round to nearest 原则），如果两个值的距离相等则采取 round to even 原则，即选择 $\lfloor v \cdot 10^{-k} \rfloor$ 和 $\lfloor v \cdot 10^{-k} \rfloor + 1$ 两个值中的偶数作为最终结果。通过以上步骤，可保证得到的结果为唯一值，即最优解，该值满足 S & W 原则：信息无损，最短长度，正确舍入。

### 快速将数字拼装成字符串

这个问题本质上是，如何快速地做无符号整数转字符串，并且算出除去其尾随0的实际长度。例如，当由前一步得出 `"12345678900000000"` 且小数点在第`buf+4`位置时，后面尾随的8个0全是多余的。我们需要的部分是 `"123456789"` ，于是需要将`"56789"`向后挪动一个字节，在第四个位置写入小数点"."，从而得到 `"1234.56789"`。

先讨论第一步“无符号整数转字符串”。以 yyjson 举例，比较朴素而且很快的一个方案是，每两位单独处理：得出两位数字之后和一个二位数预查表（2 * 100 = 200 字节，再大的话对内存不利，例如四位数则需要 4 * 10000 = 40000 字节了）做 offset ，然后拷贝两字节。比如数字 14 对应的就是两个 char `'1', '4'` ，将这两个字节向 buffer 拷贝，然后重复这一步骤。这要求输入在不同的数据范围走不同的逻辑分支，不是无分支的实现，且并行程度也不高，速度上限卡在这了。

提速的关键思路就是，充分利用 SIMD 。首先是一个简单的观察：假设已经知道从高往低数的第 n 位数字是 x ，那么第 n 个字符当然就是 `'0' + x`。如果能找到一种方法，一次性将数字的十进制位用 SIMD within a register (SWAR) 将所有字节全部摆对，然后和一个全是 `'0'` 的寄存器做向量加法即可解决问题；对于 double 而言最长十进制表示需要 17 位，由于一个向量寄存器大小通常是 16 字节，可能存在的第 17 位则要单独写入。至于算出有多少个尾随0，这可以在加上全是 `'0'` 的 SIMD register 前，用 tzcnt/lzcnt + movemask 等方式算出来。

[Daniel Lemire](https://github.com/lemire) 教授曾经在其[博客](https://lemire.me/blog/2022/03/28/converting-integers-to-decimal-strings-faster-with-avx-512/)中给出一个相当高效的 x86-64 算法，但需要使用 AVX512IFMA + AVX512VBMI ，大多数硬件无法兼容这个算法（目前 [xjb][] 适配了该算法）。受他的思路启发，[Dougall Johnson](https://github.com/dougallj) 设计了一个 [NEON 版本的算法](https://dougallj.wordpress.com/2022/04/01/converting-integers-to-fixed-width-strings-faster-with-neon-simd-on-the-apple-m1/) ， [xjb][] 和 [zmij][] 都采用了这一算法。[Tobias Schlüter](https://github.com/TobiSchluter) 在 [zmij][] 中给出了 SSE 版本的实现 ([PR #59](https://github.com/vitaut/zmij/pull/59))， xjb 也有一套 SSE 版本的实现，整体思路大同小异（但并不 trivial ），核心目的都是尽可能降低整个过程的延迟、提高 IPC。

下面来说说核心的 SIMD 实现，简单来说是利用等式： $x + \left\lfloor x/D \right\rfloor \cdot (2^k - D) = (x \bmod D) + \left\lfloor x/D \right\rfloor \cdot 2^k$ 进行二分逐步拆位。

以 Dougall 的 [NEON 实现](https://gist.github.com/dougallj/b4f600ab30ef79bb6789bc3f86cd597a#file-convert-neon-cpp-L144-L169)为例，首先将原始的 16 位数字先拆成高低两个8位，先算出 `x / 1e8`和`x % 1e8`得出两个 u32 `hi`和`lo`，这部分由于除数和模都是已知，直接转为乘+移位的魔术除法/乘加操作。很明显 `hi` 对应了最终结果的前8位，`lo`则是对应后8位，两边可以并行处理了。先将它们分别放在低 32 和高 32 位（注意：小端 CPU ，后面会讨论）， pack 进一个 `uint64x1t` 向量，将其看作一个 `uint32x2t` 然后做下一层 1e4 的操作。这次，则是对每个 u32 lane 做独立的乘法 + 移位操作算出除以 1e4 的结果 `high_10000`  ，它的每个 u32 lane 是 `x / 1e4` ；然后利用上面等式左边带入 $k=16$ 和 $D = 10000$ 去算右边的部分，得出的就是 `tenthousands = (x % 1e4) | ((x / 1e4) << 16)`，这样就将原本的数字分四块拆到了互不干扰的四个 u16 lane 上，也都可以并行处理了。接下来先将 u16 做零扩展为 u32 ，放进一个 128 bit 向量寄存器，后面再对 1e2 和 1e1 重复这个操作（这部分就不唠叨了）。注意这时候高低两个8字节的内部字节序是反着排列的，因为除去 `hi, lo` 两个变量外，都是商在高位余数在低位，在小端 CPU 上，这正好反了过来，因此需要一次 rev64 操作。这时所有位分配到了正确位置上，就做好和全 `'0'` 向量寄存器相加的准备了。

### no-memmove

回到上面的问题拆解中的后两步，将十进制值写入内存、然后用 `memmove` 给小数点腾空间。对微架构比较了解的可能已经注意到了，虽然 `memmove` 固定 16 字节通常是会优化成 load + store ，但由于前面刚刚写入数字字符串，这一做法实际上是在 CPU 上进行一次*写后读* （Read After Write, RAW），最好的情况是会成功产生一次 store-to-load forwarding (STLF) ，但失败时很可能会造成流水线 stall 。根据我的实际验证（[zmij issue #105](https://github.com/vitaut/zmij/issues/105) 以及 [xjb issue #3](https://github.com/xjb714/xjb/issues/3) ），这实际上会导致 Intel x86-64 架构上的严重性能下降。根据 xjb714 的测试， AMD 芯片上同样也有性能损失。（这一问题也是我在 [ssrJSON][] 的 AVX2 实践中遇到的问题， ssrJSON 中设计了一组 AVX2-trailing 算法来规避它，不过这是后话了，有机会的话以后会写一下相关内容）

根据 [Intel Optimization Reference Manual](https://cdrdv2-public.intel.com/814198/248966-Optimization-Reference-Manual-V1-049.pdf) 3.6.4 节的解释，在 Intel x64 上 STLF 成功的要求非常严格。通常而言，对于现代 Intel 架构，需要读写地址相同，或读在写范围内或者读写入的部分的某一半/某四分之一。在 ftoa 这一情况下上述要求不可能实现。参考 Agner Fog 的 [The microarchitecture of Intel, AMD, and VIA CPUs](https://www.agner.org/optimize/microarchitecture.pdf) ，以 Skylake 为例，在 128 位向量寄存器上 STLF 失败，除去这一行为本身花费的 5 周期外，还额外产生大约 11 周期的延迟。

3月的某个周末我突然想到，在有 SSSE3 的情况下，通过增加一张 shuffle mask 表，用 SIMD shuffle 对数据在寄存器上直接做重排处理，避免先写回内存再重新读（[zmij pull #110](https://github.com/vitaut/zmij/pull/110)）， Tobias Schlüter 也提供了很多进一步的优化思路，最终让 [zmij][] 成功解决了这一瓶颈。这里比较关键的 trick 在于原本去到第16字节的数字，memmove 后需要写入到第 17 字节，超出了一个 128 bit 向量寄存器的范围，为了解决这一问题，需要重排前的数据完全按字节逆序，从而可以提取重排前的前4字节直接写入到 offset = 16 的位置，引入的额外延迟可以被 shuffle 操作隐藏。随后我对 zmij 的 NEON 版本也做了类似尝试（但当时在 Apple M4 上测得的性能提升应该是因为关键路径上的一些代码简化提升了 IPC ，Apple 的 [CPU Optimization Guide](https://developer.apple.com/documentation/apple-silicon/cpu-optimization-guide) 在 5.6.11 节提到， Apple 的 P 核有激进的算法来解决 STLF ，能让一条 load 零延迟地从多个 store 来源取数据并转发，不对齐也 OK 。因此在 Apple M 系芯片上这根本不会造成性能影响），并将同样的设计作为 no-memmove 特性移植到了 xjb （[xjb pull #7](https://github.com/xjb714/xjb/pull/7)），默认为 x86-64 SSSE3+ 启用 no-memmove 。 Apple M 系芯片默认不启用，一是因为芯片本身优秀的 STLF 设计，二是 memmove 版本实现用 lz ， no-memmove 刚需 tz ，而 tz 在 aarch64 实际上是 rbit + lz ，会导致额外的延迟。

## 谁更快？

如果单纯只是问“ xjb 和 zmij 谁更快”，这个问题就是一个蠢问题，而且两个仓库 README 都会告诉你自己比对方快，尤其是 zmij 在用半年前的 xjb 代码和自己对比跑 benchmark （

> 类似这样的底层性能库，性能测试会受到到很多方面的因素影响，例如运行架构、编译器、测试集的数据分布等，极端情况还要考虑如 L1 cache 占用等各类指标。如果你要从中选用一个实现的话，建议从各个角度看一下是否符合需求（例如输出的格式等），以及在实际部署的设备上跑一遍自己的 benchmark 验证，下面给出的结论也不一定完全贴合你的运行环境。从整体上而言，到了 2026 年中， xjb 和 zmij 都趋于稳定的情况下， **float处理 [xjb][] 全局显著更优， double快速路径上 [xjb][] 在 x86-64 架构显著优于 [zmij][] ，在 Apple M 系架构上二者几乎没有区别。**

下面分节列一下一些可能受关注的差异点。

### 常量表

先看~~0人在意的~~非压缩情形的常量表，下面数据来自当前最新版本编译出来的 .rodata ， ~~aarch64 让 AI 对着 x86-64 的 .rodata 蹬出来的，因为懒得开 macbook 了~~。 [xjb][] 在处理 float 和处理 double 两条路径上常量不共享，而 [zmij][] 的 float 和 double 处理共享同一张表，因此能够省下大约 1.4k 。xjb SSSE3+, zmij SSE4.1 因为实现了 no-memmove 需要更大的常量表，会比通常的 SSE2 构建更大一些。现代架构上主要考虑访存局部性、不跨缓存行读取，这一点上两个实现都做得很好，个人认为内存方面的瓶颈可以忽略。从下面表格可以看出二进制大小这块两个实现都是一大坨常量表，主要被 double 卡得死死的，省不了一点，~~要想快就得多打表~~。

|         | [xjb][]       | [zmij][]      |
| ------- | ------------- | ------------- |
| SSE2    | 19264         | 17600         |
| SSE4.1  | 19904         | 19072         |
| aarch64 | 19264（推算） | 18240（推算） |

压缩情形，虽然 [xjb][] 有在仓库放一份 `bench/xjb/float_to_string/ftoa_comp.cpp` ，但因为是独立文件不在 src 目录维护，不纳入考虑。 [zmij][] 有实现压缩版本（宏 `ZMIJ_OPTIMIZE_SIZE=1`），常量表大小压到 640 字节，因此嵌入式等资源紧张环境可以考虑 [zmij][] 。~~再说下去你就要知道我不懂嵌入式了~~

### x86-64

[xjb][] 的优势主要源自于**多架构真机 x 多编译器**的测试矩阵完备。 [xjb714][] 在设计其代码时，会注意 gcc/clang/icpx 等编译器的针对性优化，再加上能够用多种不同的架构运行性能测试并定位瓶颈，保证每次代码更新不会造成性能倒退。在 [xjb][] 代码中随处可见关于编译器和架构的判断；代价是维护难度++。

而 [zmij][] 在维护过程中对多架构的性能关注度明显不足，已经发生过多次性能倒退（个人推测维护者 Victor Zverovich 只在自己的 Mac 上测试，在 aarch64 上确实没观察到过什么性能倒退）。3月左右 [zmij pull #110](https://github.com/vitaut/zmij/pull/110) no-memmove PR 合并之后， zmij 无论是 float 还是 double 速度都很快。但4月左右，Victor Zverovich 开始了一系列重构将算法基底完全转向 [xjb][] ，包括 float 路径整体重写等。可能因为当时我还没有给 [xjb][] 提交 no-memmove PR ，也可能是 Apple 芯片上 no-memmove 根本看不到实际收益， Victor 这次重写还移除了 no-memmove 优化。5月初非指数格式输出的快速路径 zmij 性能倒退了 20% ，在我的 i13700k 上单次调用已经飞出 10 ns 了。这期间 xjb714 与我正在优化 [xjb][] 的性能和代码质量，而 [zmij][] 这一边靠着 Tobias Schlüter 多轮 x86-64 优化，6 月底在 [zmij pull #137](https://github.com/vitaut/zmij/pull/137) 中恢复了 no-memmove （对应宏 `ZMIJ_USE_SIMD_SHUFFLE` ，这个 PR 只有部分提交被合并），到了 7 月，性能终于比 3 月之前好了。将 [zmij][] 算法底座从 yy 切换到 [xjb][] 的过程花了几个月终于有了正收益，但最终还是在快速路径上比 [xjb][] 慢了 10% ，~~在现代 x86-64 上 [zmij][] 唯一的优势也许只剩代码写得工整了，什么叫做基于 xjb 但是不如 xjb~~

### 其他差异对照

[xjb][] 和 [zmij][] 这两个实现互相借鉴了很多内容，但细节上的差异也不小。比较有意思的是 [zmij][] 的 [Rust 移植](https://github.com/dtolnay/zmij)在整数浮点数情况输出方式和原始的 C++ 版本不同，用的是 "1.0" 这样的形式，并且遵守 RFC8259 ，而且不检查输入是否是 `inf/nan` （~~强兼 RFC8259 说是~~）。不过 [zmij][] 的 Rust 移植我不打算过多讨论，基本上和 C++ 版本差不多，区别只在于其最终拼字符串的实现中（ super hot 热点）使用 `ptr::copy` 但传入了动态长度而不是固定 8/16 ，导致编译出来一个优化不掉的真实 `memmove` 函数调用（这在[zmij issue #105](https://github.com/vitaut/zmij/issues/105)讨论过）， Rust 大手子可以考虑给它 PR 优化下。 [zmij][] 仓库还提供了 C 语言版本，但更新速度很慢，难以跟上 C++ （原版）实现的进度。[ssrJSON][] 采用了 [xjb][] 作为底层 ftoa 算法实现，原因是该实现兼容 RFC8259 且性能更好。

|  | zmij | xjb |
|---|---|---|
| x86-64 | 稍慢 | 稍快 |
| Apple M 系 | 持平 | 持平 |
| float 支持 | 较差 | 较好 |
| SIMD | NEON/SSE2/SSE4.1 | NEON/SSE2/SSSE3/SSE4.1/AVX512IFMA |
| 运行时 SIMD 检查 | N/A | N/A |
| no-memmove | NEON/SSE4.1，支持宏开关 | NEON/SSSE3+（NEON支持但默认不开启），支持宏开关 |
| JSON (RFC8259) | NO | YES |
| 整数浮点数输出格式 | "1" | "1.0" |
| 小表 | 支持 | 暂不支持（作者正在开发中） |
| 代码质量 | 较好 | 较差 |

### 真机性能测试

使用 Victor 的 [fmtlib/dtoa-benchmark](https://github.com/fmtlib/dtoa-benchmark) ，结合多数据集在 i7 13700k 上的测试见 Claude artifact [The dataset decides the winner](https://claude.ai/code/artifact/70f25a92-add3-4f81-9b7c-2e843a89c551)，这是用 Opus 5 在多个数据集上跑出来的结果，整体而言 xjb 性能最稳定且最快。

以下使用 [ftoa-benchmark](https://github.com/antares0982/ftoa-benchmark)进行测试，测试数据集来自 canada.json （长定点路径）。单位 ns/call ，结果取 P1 （前1%最优）而不是平均值

#### x86-64

##### （1）intel i7 13700k

###### float

|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, SSE2   | 7.22    | 9.65     |
| gcc, SSE2     | 7.30    | 9.66     |
| clang, SSE4.1 | 7.26    | 9.82     |
| gcc, SSE4.1   | 7.45    | 9.47     |

###### double
|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, SSE2   | 8.26    | 9.77     |
| gcc, SSE2     | 8.29    | 9.83     |
| clang, SSE4.1 | 7.52    | 8.32     |
| gcc, SSE4.1   | 7.90    | 8.32     |

##### （2）AMD Ryzen 7 7840H

###### float

|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, SSE2   | 7.44    | 10.08    |
| gcc, SSE2     | 7.81 | 10.49 |
| icpx, SSE2 | 7.47 | 10.15 |
| clang, SSE4.1 | 7.62 | 10.09 |
| gcc, SSE4.1   | 7.80 | 10.47    |
| icpx, SSE4.1 | 7.62 | 10.12 |

###### double
|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, SSE2   | 9.84 | 12.14 |
| gcc, SSE2     | 9.52 | 11.12 |
| icpx, SSE2 | 9.40 | 11.33 |
| clang, SSE4.1 | 7.79 | 8.04 |
| gcc, SSE4.1   | 8.38 | 8.55 |
| icpx, SSE4.1 | 7.82 | 8.08 |

#### aarch64

##### （2）Apple M1

###### float

|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, NEON   | 5.59    | 6.50     |

###### double

|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, NEON   | 6.72    | 6.73     |

##### （3）Apple M4

###### float

|             | [xjb][] | [zmij][] |
| ----------- | ------- | -------- |
| clang, NEON | 3.53    | 4.24     |

###### double

|             | [xjb][] | [zmij][] |
| ----------- | ------- | -------- |
| clang, NEON | 4.42    | 4.36     |

##### （4）Apple M5

###### float

|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, NEON   | 3.07    | 3.76     |

###### double

|               | [xjb][] | [zmij][] |
| ------------- | ------- | -------- |
| clang, NEON   | 3.95    | 3.93     |

## 结语

~~没有~~

[xjb]: https://github.com/xjb714/xjb
[xjb714]: https://github.com/xjb714
[zmij]: https://github.com/vitaut/zmij
[Żmij]: https://github.com/vitaut/zmij
[Schubfach]: https://fmt.dev/papers/Schubfach4.pdf
[xjb paper]: https://github.com/xjb714/xjb/blob/12fffe418d1f5a039e76e9b96969258970a6dd0a/xjb.pdf
[Dragonbox]: https://github.com/jk-jeon/dragonbox/blob/beeeef91cf6fef89a4d4ba5e95d47ca64ccb3a44/other_files/Dragonbox.pdf
[yyjson]: https://github.com/ibireme/yyjson
[yy_double]: https://github.com/ibireme/c_numconv_benchmark/blob/master/vendor/yy_double/yy_double.c
[ssrJSON]: https://github.com/antares0982/ssrJSON
