---
title: 终极数学公式的证明
---

< [[Ultimate math formulas]]

## 展开与因式分解

## 二次公式

## 指数法则

设 $`a`$ 和 $`b`$ 为实数，$`m`$ 和 $`n`$ 为正整数。

**定义（*乘幂*）：**

$`a^1 = a`$ （定义 1）

$`a^{n + 1} = a^n a`$，当 $`n \ge 1`$ 时 （定义 2）

对 $`n`$ 使用数学归纳法：

<details>
<summary>幂的乘积</summary>

$`a^m a^n = a^{m + n}`$

基础情形（$`n = 1`$）：

$`a^m a^1 = a^m a`$ （由定义 1）

$`= a^{m + 1}`$ （由定义 2）

归纳步骤：

假设 $`a^m a^n = a^{m + n}`$。则：

$`a^m a^{n + 1} = a^m(a^n a)`$ （由定义 2）

$`= (a^m a^n)a`$ （由结合律）

$`= a^{m + n} a`$ （由归纳假设）

$`= a^{(m + n) + 1}`$ （由定义 2）

$`= a^{m + (n + 1)}`$ （由结合律）

</details>

<details>
<summary>幂的幂</summary>

$`(a^m)^n = a^{mn}`$

基础情形（$`n = 1`$）：

$`(a^m)^1 = a^m`$ （由定义 1）

$`= a^{m \cdot 1}`$ （由恒等式）

归纳步骤：

假设 $`(a^m)^n = a^{mn}`$。则：

$`(a^m)^{n + 1} = (a^m)^n a^m`$ （由定义 2）

$`= a^{mn} a^m`$ （由归纳假设）

$`= a^{mn + m}`$ （由幂的乘积）

$`= a^{m(n + 1)}`$ （由分配律）

</details>

<details>
<summary>乘积的幂</summary>

$`(ab)^n = a^n b^n`$

基础情形（$`n = 1`$）：

$`(ab)^1 = ab`$ （由定义 1）

$`= a^1 b^1`$ （由定义 1）

归纳步骤：

假设 $`(ab)^n = a^n b^n`$。则：

$`(ab)^{n + 1} = (ab)^n(ab)`$ （由定义 2）

$`= (a^n b^n)(ab)`$ （由归纳假设）

$`= (a^n a)(b^n b)`$ （由结合律和交换律）

$`= a^{n + 1} b^{n + 1}`$ （由定义 2）

</details>

## 对数法则

设 $`a, b, M, N, x > 0`$ 且 $`n`$ 为实数，其中 $`a, b \ne 1`$。由于对数是乘幂的逆运算，我们有

$`\log_a(a^x) = a^{\log_a x} = x`$，

就像 $`f^{-1}(f(x)) = f(f^{-1}(x)) = x`$ 一样。利用这一点：

$`\log_a(MN) = \log_a(a^{\log_a M} a^{\log_a N}) = \log_a(a^{\log_a M + \log_a N}) = \log_a M + \log_a N`$

$`\log_a(M^n) = \log_a((a^{\log_a M})^n) = \log_a(a^{n \log_a M}) = n \log_a M`$

$`\log_a M = \displaystyle \frac{\log_a M \cdot \log_b a}{\log_b a} = \frac{\log_b(a^{\log_a M})}{\log_b a} = \frac{\log_b M}{\log_b a}`$

## 分数

## 线性方程组

## 数列

## 导数

## 三角恒等式

### 毕达哥拉斯恒等式

### 和角公式

$`\cos(\alpha + \beta) + i \sin(\alpha + \beta) = e^{i(\alpha + \beta)}`$

$`= e^{i\alpha} e^{i\beta}`$

$`= (\cos \alpha + i \sin \alpha)(\cos \beta + i \sin \beta)`$

$`= (\cos \alpha \cos \beta - \sin \alpha \sin \beta) + i(\sin \alpha \cos \beta + \cos \alpha \sin \beta)`$

### 倍角公式

$`\sin 2\theta = \sin(\theta + \theta) = \sin \theta \cos \theta + \cos \theta \sin \theta = 2 \sin \theta \cos \theta`$

$`\cos 2\theta = \cos(\theta + \theta) = \cos \theta \cos \theta - \sin \theta \sin \theta = \cos^2 \theta - \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = (1 - \sin^2 \theta) - \sin^2 \theta = 1 - 2 \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = \cos^2 \theta - (1 - \cos^2 \theta) = 2 \cos^2 \theta - 1`$

### 多倍角公式

$`\cos n\theta + i \sin n\theta = (\cos \theta + i \sin \theta)^n = \displaystyle \sum_{k = 0}^n \binom{n}{k} \cos^{n - k} \theta \, i^k \sin^k \theta`$

## 欧拉公式

设 $`e^{ix} = f + ig`$ （式 1）。

对两边关于 $`x`$ 求导：

$`(e^{ix})' = (f + ig)'`$

$`ie^{ix} = f' + ig'`$ （式 2）

将式 1 代入左端：

$`i(f + ig) = f' + ig'`$

$`-g + if = f' + ig'`$

令两边的实部和虚部相等：

$`-g = f'`$

$`f = g'`$

可以改写为：

$`f'' = -f`$

$`g'' = -g`$

这些是二阶微分方程，其初始条件 $`f(0) = 1`$、$`f'(0) = 0`$、$`g(0) = 0`$ 和 $`g'(0) = 1`$ 是将 $`x = 0`$ 代入式 1 和式 2 得到的。其唯一解为：

$`f = \cos x`$

$`g = \sin x`$

[[#math|Math]]
