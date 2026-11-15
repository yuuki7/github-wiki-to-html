---
title: 終極數學公式的證明
---

< [[Ultimate math formulas]]

## 展開與因式分解

## 二次公式

## 指數法則

設 $`a`$ 和 $`b`$ 為實數，$`m`$ 和 $`n`$ 為正整數。

**定義（*乘冪*）：**

$`a^1 = a`$ （定義 1）

$`a^{n + 1} = a^n a`$，當 $`n \ge 1`$ 時 （定義 2）

對 $`n`$ 使用數學歸納法：

<details>
<summary>冪的乘積</summary>

$`a^m a^n = a^{m + n}`$

基礎情形（$`n = 1`$）：

$`a^m a^1 = a^m a`$ （由定義 1）

$`= a^{m + 1}`$ （由定義 2）

歸納步驟：

假設 $`a^m a^n = a^{m + n}`$。則：

$`a^m a^{n + 1} = a^m(a^n a)`$ （由定義 2）

$`= (a^m a^n)a`$ （由結合律）

$`= a^{m + n} a`$ （由歸納假設）

$`= a^{(m + n) + 1}`$ （由定義 2）

$`= a^{m + (n + 1)}`$ （由結合律）

</details>

<details>
<summary>冪的冪</summary>

$`(a^m)^n = a^{mn}`$

基礎情形（$`n = 1`$）：

$`(a^m)^1 = a^m`$ （由定義 1）

$`= a^{m \cdot 1}`$ （由恆等式）

歸納步驟：

假設 $`(a^m)^n = a^{mn}`$。則：

$`(a^m)^{n + 1} = (a^m)^n a^m`$ （由定義 2）

$`= a^{mn} a^m`$ （由歸納假設）

$`= a^{mn + m}`$ （由冪的乘積）

$`= a^{m(n + 1)}`$ （由分配律）

</details>

<details>
<summary>乘積的冪</summary>

$`(ab)^n = a^n b^n`$

基礎情形（$`n = 1`$）：

$`(ab)^1 = ab`$ （由定義 1）

$`= a^1 b^1`$ （由定義 1）

歸納步驟：

假設 $`(ab)^n = a^n b^n`$。則：

$`(ab)^{n + 1} = (ab)^n(ab)`$ （由定義 2）

$`= (a^n b^n)(ab)`$ （由歸納假設）

$`= (a^n a)(b^n b)`$ （由結合律和交換律）

$`= a^{n + 1} b^{n + 1}`$ （由定義 2）

</details>

## 對數法則

設 $`a, b, M, N, x > 0`$ 且 $`n`$ 為實數，其中 $`a, b \ne 1`$。由於對數是乘冪的逆運算，我們有

$`\log_a(a^x) = a^{\log_a x} = x`$，

就像 $`f^{-1}(f(x)) = f(f^{-1}(x)) = x`$ 一樣。利用這一點：

$`\log_a(MN) = \log_a(a^{\log_a M} a^{\log_a N}) = \log_a(a^{\log_a M + \log_a N}) = \log_a M + \log_a N`$

$`\log_a(M^n) = \log_a((a^{\log_a M})^n) = \log_a(a^{n \log_a M}) = n \log_a M`$

$`\log_a M = \displaystyle \frac{\log_a M \cdot \log_b a}{\log_b a} = \frac{\log_b(a^{\log_a M})}{\log_b a} = \frac{\log_b M}{\log_b a}`$

## 分數

## 線性方程組

## 數列

## 導數

## 三角恆等式

### 畢達哥拉斯恆等式

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

## 歐拉公式

設 $`e^{ix} = f + ig`$ （式 1）。

對兩邊關於 $`x`$ 求導：

$`(e^{ix})' = (f + ig)'`$

$`ie^{ix} = f' + ig'`$ （式 2）

將式 1 代入左端：

$`i(f + ig) = f' + ig'`$

$`-g + if = f' + ig'`$

令兩邊的實部和虛部相等：

$`-g = f'`$

$`f = g'`$

可以改寫為：

$`f'' = -f`$

$`g'' = -g`$

這些是二階微分方程，其初始條件 $`f(0) = 1`$、$`f'(0) = 0`$、$`g(0) = 0`$ 和 $`g'(0) = 1`$ 是將 $`x = 0`$ 代入式 1 和式 2 得到的。其唯一解為：

$`f = \cos x`$

$`g = \sin x`$

[[#math|Math]]
