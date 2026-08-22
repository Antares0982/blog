---
title: "PRT球谐函数的数学原理"
slug: "spherical-harmonic"
date: 2022-03-06T21:37:35+08:00
lastmod: 2025-08-11T01:25:40+08:00
wpid: 236
wpguid: "https://chr.fan/?p=236"
views: 13629
categories: ["数学"]
tags: ["旋转", "图形学", "球谐", "PRT", "球面谐函数", "数学", "内积", "投影", "勒让德多项式", "勒让德函数", "证明", "推导"]
---

> 博客的公式排版非常不好看，可以移步[这里](/wp-content/uploads/2022/03/sphrical_harmonic.pdf)阅读pdf版。
> 
> 如有错误敬请指正！

图形学中PRT使用球谐函数来预计算光照信息。

网上找到的球谐函数的相关数学原理比较凌乱，有些讲的也不是很清楚，所以自己以数学专业的角度整理了一下。

用到的数学知识：

* 微积分（数学分析）
* 线性代数
* 复变函数
* 泛函分析（较少）

> 注意：下文中的单个字母上标，如果不是标在括号上，一律不代表“幂次”。

### 内积空间

考虑空间$L^2 (S^2)$，即，在三维空间单位球表面上平方可积（模的平方在球面$S^2$上的积分存在且有限）的函数全体。在该空间上定义一个（复）内积（类比于向量的点乘、内积）
$$
\langle f,\ g  \rangle := \int_{S^2} f(w)\overline{g(w)}\,{\rm d} w.
$$
这样的话，$\forall f\in L^2(S^2)$，
$$
\Vert f\Vert^2:=\langle f,f\rangle = \int_{S^2} f(w)\overline{f(w)}\,{\rm d} w\ge 0.
$$
即定义了一个范数$\Vert\cdot \Vert$（类比于向量的长度）。可以注意到，如上定义的内积总是有这样一些性质：
$$
\begin{aligned}
\langle f,g\rangle &= \overline{\langle g,f\rangle}\\
k\langle f,g\rangle &= \langle kf,g\rangle = \langle f,\overline k g\rangle,\ \forall k\in\mathbb C\\
\langle f_1+f_2,g\rangle &= \langle f_1,g\rangle + \langle f_2,g\rangle
\end{aligned}
$$
类比一般的线性空间，我们想找到一组正交系（正交基），这样就可以引入类似于坐标这样的概念。内积空间中的一组**规范正交系**，记为$(e_i) _ { i \in \mathbb N}$，需要满足：

$$
\langle e_i, e_j\rangle = \delta _{ij},
$$
其中
$$
\begin{aligned}
\delta_{ij}=\begin{cases}
1,& i=j,\\
0,&i\neq j.
\end{cases}
\end{aligned}
$$

### 连带勒让德多项式

[连带（也称伴随）勒让德多项式](https://zh.wikipedia.org/wiki/%E4%BC%B4%E9%9A%8F%E5%8B%92%E8%AE%A9%E5%BE%B7%E5%A4%9A%E9%A1%B9%E5%BC%8F)是一组在$L^2[-1,1]$上的正交系。连带勒让德多项式记为$P_l^m(x)$，其中$0\le m\le l$，$m,l\in\mathbb N$。它没有简单的显式表达，但可以递推地求出。它满足
$$
\int_{-1}^1 P_l^m(x)P_k^m(x) \,{\rm d}x= \frac2{2l+1}\frac{(l+m)!}{(l-m)!}\delta_{kl},
$$
即，在$m$固定时，$P_l^m$与$P_k^m$正交，其中$l\neq k$。

对于$m<0$的情形，推广定义：
$$
P_l^{-m}(x) = (-1)^m \frac{(l-m)!}{(l+m)!} P_l^m(x).
$$

 ### 球谐函数（复数形式）

定义球谐函数如下：
$$
Y_l^m (\theta,\varphi) = N_l^m P_l^{m}(\cos \theta){\rm e}^{{\rm i}m\varphi}, \ \ \ -l\le m\le l,
$$
其中$N_l^m$是归一化常数，即，$N_l^m$是使得$Y_l^m$与自身的内积为1（范数为1）的常数（总是实数）：
$$
(N_l^m)^{-2} = \langle P_l^m(\cos \theta){\rm e}^{{\rm i}m\varphi},\ P_l^m(\cos \theta){\rm e}^{{\rm i}m\varphi}\rangle.
$$
考虑内积：
$$
\langle Y_l^m ,Y_k^n\rangle ,
$$
展开计算（注意到$\overline{{\rm e}^{{\rm i}n\varphi}}={\rm e}^{-{\rm i}n\varphi}$）：
$$
\langle Y_l^m ,Y_k^n\rangle=N_l^m N_k^n\int_{S^2} P_l^m(\cos \theta)P_k^n(\cos\theta){\rm e}^{{\rm i}(m-n)\varphi}\,{\rm d} w.
$$
拆开$\theta$和$\varphi$相关的项
$$
\langle Y_l^m ,Y_k^n\rangle = N_l^m N_k^n \int_{0}^{2\pi} {\rm e}^{{\rm i}(m-n)\varphi}\,{\rm d}\varphi \int_0^\pi P_l^m(\cos\theta)P_k^n(\cos\theta)\sin\theta\,{\rm d}\theta.
$$

* 如果$m\neq n$，那么
  $$
  \int_{0}^{2\pi} {\rm e}^{{\rm i}(m-n)\varphi}\,{\rm d}\varphi = \int_0^{2\pi} \cos(m-n)\,{\rm d}\varphi+{\rm i}\int_0^{2\pi} \sin(m-n)\,{\rm d}\varphi = 0.
  $$
  $m=n$时被积项退化为1，积分值为$2\pi$。于是
  $$
  \langle Y_l^m ,Y_k^n\rangle = 2\pi \delta_{mn} N_l^m N_k^n   \int_0^\pi P_l^m(\cos\theta)P_k^n(\cos\theta)\sin\theta\,{\rm d}\theta.
  $$

* 现在设$m=n$，由于连带勒让德函数的性质以及$t=\cos\theta$换元可以立即得出
  $$
  \langle Y_l^m ,Y_k^m\rangle = 2\pi N_l^m N_k^m \delta_{lk}.
  $$

通过以上讨论可以知道，当且仅当$l=k$且$m=n$时上述内积非0。又由$N_l^m$定义，我们得到
$$
\langle Y_l^m ,Y_k^n\rangle = \delta_{lk}\delta_{mn},
$$
从而全体复球谐函数成为一组规范正交系。

### 球谐函数直角坐标表示

**引理.** $Y_l^m(x,y,z)$是关于$x,y,z$的$l$次多项式，可以写成关于$z$的$l-|m|$次多项式与关于$x,y$的$|m|$次齐次多项式$(x\pm{\rm i}y)^{|m|}$的乘积。

*Proof.* 先考虑$m\ge 0$的情形。
$$
Y_l^m(\theta,\varphi) =N_l^m P_l^{m}(\cos \theta){\rm e}^{{\rm i}m\varphi},
$$
根据递推公式
$$
P_l^m(t) = (-1)^m (1-t^2)^{m/2} \frac{{\rm d}^m}{{\rm d}t^m}P_l(t),
$$
其中$P_l(t)$为一般的勒让德多项式。于是
$$
P_l^m(\cos \theta) = (-1)^m \sin^m \theta F(\cos \theta),
$$
其中
$$
F(t) :=\frac{{\rm d}^m}{{\rm d}t^m}P_l(t).
$$
因为勒让德多项式
$$
P_l(t) =\frac{1}{2^l l!}\frac{{\rm d}^l}{{\rm d}t^l}((t^2-1)^l)
$$
是一个关于$t$的$l$次多项式，从而$F(t)$是一个关于$t$的$l-m$次多项式。因为在$S^2$上$z=\cos\theta$，所以$F(\cos\theta)$是关于$z$的$l-m$次多项式。于是
$$
\begin{aligned}
Y_l^m(\theta,\varphi) &=N_l^m (-1)^m F(z) \sin^m \theta {\rm e}^{{\rm i}m\varphi}\\
&=N_l^m (-1)^m F(z) (\sin \theta {\rm e}^{{\rm i}\varphi})^m\\
&=N_l^m (-1)^m F(z) (\sin \theta \cos\varphi+{\rm i}\sin\theta \sin \varphi)^m\\
& = N_l^m (-1)^m F(z) (x+{\rm i}y)^m,
\end{aligned}
$$
这就说明了对于$m\ge 0$的情况成立。对于$m<0$的情况，与$-m$同理可得，结果可写为$kG(z)(x-{\rm i}y)^{|m|}$。证毕。

### 无穷维坐标与帕塞瓦尔公式

假设我们有一组希尔伯特（范数完备的内积空间）空间$X$上的规范正交系$(e_i) _ {i\ge 0}$。对于任意一个点$f \in X$，我们可以将$f$写为如下形式（定义与为什么可以这样做的证明稍繁琐，可以参考任意泛函分析教材，不详细展开了）：
$$
f = \sum_{j=0}^\infty a_j e_j,
$$
写成无穷维坐标形式即$(a_0, a_1, a_2, \dots)$. 利用规范正交系的性质我们可以得到
$$
\langle f, e_i\rangle = \sum_{j=0}^\infty a_j\langle e_j, e_i\rangle = a_i,
$$
以及内积空间上的勾股定理的推广**帕塞瓦尔等式**
$$
\Vert f\Vert^2 = \langle f, f\rangle = \sum_{j=0}^\infty \langle a_je_j, a_je_j\rangle = \sum_{j=0}^\infty |a_j|^2.
$$

对于球谐函数系，即$X = L^2(S^2)$，我们可以写成
$$
f = \sum_{l=0}^\infty \sum_{m=-l}^l a_l^m Y_l^m,
$$
以及帕塞瓦尔等式
$$
\Vert f\Vert^2 = \sum_{l=0}^\infty \sum_{m=-l}^l |a_l^m|^2.
$$

球谐系数
$$
a_l^m = \int f(w) \overline{Y_l^m (w)}\,{\rm d}w.
$$

### 球谐函数（实数形式）

复数形式的球谐函数一般而言并不好用，就比如上面计算系数的积分，如果球谐函数是实值的，能省下很多麻烦。

我们用球谐函数的复数形式的$Y_{1}^1, Y_1^0,Y_1^{-1}$举例如何构造实值球谐函数。前面我们已经证明了它们满足规范正交系的性质，我们任取$Y_l^m$，$l\neq 1$。这时候一定有
$$
\begin{aligned}
\langle Y_l^m, Y_1^1\rangle &= 0,\\
\langle Y_l^m, Y_1^0\rangle &= 0,\\
\langle Y_l^m, Y_1^{-1}\rangle &= 0.
\end{aligned}
$$
也就是说，对于函数$f$，如果满足
$$
f = c_{-1}Y_1^{-1}+c_0Y_1^0 +c_1 Y_1^1,
$$
那么
$$
\langle Y_l^m ,f\rangle = 0.
$$
如果我们从全体可以写为$ c_{-1}Y_1^{-1}+c_0Y_1^0 +c_1 Y_1^1$的函数（即$Y_1^m$张成的线性子空间）中，重新选出三个相互正交的、实值且范数为1的函数来替代掉原本的三个$Y_1^m$，这样构造的“球谐函数族”仍然是规范正交基，虽然它可能不再是物理或数学上普遍使用的球谐函数。

实际上这样做的时候，我们总是把$Y_l^m$和$Y_l^{-m}$这一对函数按照上面的方法重新选择。注意到$Y_l^m$与$Y_l^{-m}$形式非常相似，我们总是可以将它们*两个作为一对派生出新的另一对*，比如相加之后除以$\sqrt2$再取虚（实）部，相减之后除以$\sqrt 2$再取实（虚）部。另外，$Y_l^0$总是实值的，不需要重新选取。以及，$-Y_l^m$总是可以替换掉$Y_l^m$。

上面的讨论说明了实值球谐函数的选取方式非常多，主要看实际应用中你想如何定义它。实值球谐函数的例子，可以参考[en wiki](https://en.wikipedia.org/wiki/Table_of_spherical_harmonics#Real_spherical_harmonics)的实值球谐函数表。

### 投影

对于任意一个定义在球面$S^2$上的函数$f$，我们有分解
$$
f = \sum_{l=0}^\infty \sum_{m=-l}^l a_l^m Y_l^m,
$$
如果我们只取其中的前几层，比如$l\le 2$，就得到了$f$对子空间的**投影**
$$
f_p = \sum_{l=0}^2 \sum_{m=-l}^l a_l^m Y_l^m.
$$
$f_p$是在$l\le 2$的所有球谐函数张成的空间里，**最接近** $f$的那个。因为根据帕塞瓦尔等式
$$
\Vert f-f_p\Vert^2 = \sum_{l=3}^\infty \sum_{m=-l}^l |a_l^m|^2,
$$
对于$l\le 2$球谐函数张成的子空间，这一差值的范数至少是$\Vert f-f_p\Vert^2$.可以注意到，如果层数$l$取值越大，$f_p$对$f$的逼近就越好。

在图形学中我们一般用投影$f_p$来代替原本的$f$，这样做一是因为我们不可能算出无穷个球谐系数$a_l^m$，二是取前几层得到的投影在大多数情况下，已经非常近似于原本的$f$。

### 球谐函数的旋转

根据[施密特正交化](https://zh.wikipedia.org/wiki/%E6%A0%BC%E6%8B%89%E5%A7%86-%E6%96%BD%E5%AF%86%E7%89%B9%E6%AD%A3%E4%BA%A4%E5%8C%96)，我们总是能轻松构造出一组规范正交基，除了球谐函数，当然也可以选择别的规范正交基来做分解。使用球谐函数是因为它们的另一个优秀性质：快速旋转。

考虑一个旋转$R$。$f$与旋转$R$的复合，仍然是一个定义在$S^2$的函数。

对于$Y_l^m$与$R$的复合，必然也有
$$
Y_l^m\circ R(\theta,\varphi) = \sum_{k=0}^\infty \sum_{n=-k}^k b_{l,m,k}^n(R) Y_k^n(\theta, \varphi).
$$
但是，对于球谐函数而言，实际上可以写成
$$
Y_l^m\circ R(\theta,\varphi) =  \sum_{n=-l}^l  b_{mn} Y_l^n(\theta, \varphi),
$$
其中$b_{mn}$和$R$有关。也就是说，第$l$层的球谐函数与任意旋转的复合，仍然在第$l$层球谐函数张成的子空间内。这一性质与三维旋转群$SO(3)$的不可约表示密不可分，严格的证明可以参考[物理学中的群论](https://book.douban.com/subject/1813593/)（第2版）第122页。

至于如何解出上述的$a_l^n$，实际上我们可以把它看成解一个$2l+1$元线性方程组，那么我们自然需要$2l+1$个方程。取$2l+1$个不同的球面上的采样点$(\theta_i, \varphi_i),\ i=-l,\dots, l$，得到$2l+1$个等式：（有的说法是将采样点*投影*为球谐系数，这一说法是非常不严谨的。球谐函数分解的是$L^2(S^2)$上的函数，而不是$S^2$上的点）
$$
Y_l^m\circ R(\theta_i, \varphi_i) = \sum_{n=-l}^l b_{mn} Y_l^n(\theta_i, \varphi_i),\ i=-l,\dots, l.
$$
记矩阵$A = \left(Y_l^n(\theta_i, \varphi_i)\right) _ {i,n}$，向量$b_{m} = (b_{m,-l},\ \dots,\ b_{ml})^{\rm T}$，向量$c_m = (Y_l^m\circ R(\theta_{-l}, \varphi_{-l}), \dots, Y_l^m\circ R(\theta_{l}, \varphi_{l}))^{\rm T}$。则得到方程组
$$
Ab_m = c_m.
$$
于是（若$A$可逆）
$$
b_m = A^{-1} c_m.
$$
这个等式只解出了$Y_l^m$的旋转。现在假设我们待旋转的$f$在第$l$层上的球谐系数是$a_l^m$，这一层的投影$f_p$可以分解为
$$
f_p= \sum_{m=-l}^l a_l^m Y_l^m,
$$
则
$$
f_p\circ R = \sum_{m=-l}^l a_l^m \sum_{n=-l}^l b_{mn} Y_l^n = \sum_{n=-l}^l Y_l^n \sum_{m=-l}^l a_l^m b_{mn}.
$$
把所有列向量$b_m$合并，写成矩阵形式$B = (b_m) _ {m=-l}^l$，同理$C=(c_m) _ {m=-l}^l$，得到
$$
B = A^{-1}C
$$
$Y_l^n$项新的系数是$\sum_{m=-l}^l a_l^m b_{mn}$，写成一列，即为
$$
Ba_l = A^{-1}C a_l.
$$
实际应用中，矩阵$A$的值是可以预先算好的，因为$A$与输入的旋转$R$没有关联，也就是说，只要选取的$2l+1$个采样点，能够让算出来的$A$是可逆矩阵，那么这些采样点就是良好的。我们可以直接计算出$A^{-1}$，需要进行旋转时，只需要用$R$计算出$C$，即可得到旋转后的球谐系数。

如果你在别处见到的结果是写成$SA^{-1}$的，而不是$A^{-1}C$，那是因为，在上面的讨论中采用的$A$，相对于那种写法是*转置*过的，这样的目的在于，最终计算时用的是矩阵左乘列向量（数学上比较通用的写法），而不是矩阵右乘行向量。

![](/wp-content/uploads/2022/03/SHrotate.png)

### 其他分解方式

球面上当然也可以选取其他的方式分解，比如Zonal Harmonics以及Wavelets. Zonal Harmonics是一些特殊的球谐函数旋转后的结果。Wavelets不适合快速旋转，但它应用于高频信息的保留时效果比球谐基好。
