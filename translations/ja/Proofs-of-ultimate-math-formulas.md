---
title: 究極の数学公式の証明
---

< [[Ultimate math formulas]]

## 展開と因数分解

## 二次方程式の解の公式

## 指数法則

$`a`$ と $`b`$ を実数とし、$`m`$ と $`n`$ を正の整数とする。

**定義（*累乗*）：**

$`a^1 = a`$ （定義 1）

$`a^{n + 1} = a^n a`$ （$`n \ge 1`$ のとき）（定義 2）

$`n`$ に関する帰納法により：

<details>
<summary>冪の積</summary>

$`a^m a^n = a^{m + n}`$

基底ケース（$`n = 1`$）：

$`a^m a^1 = a^m a`$ （定義 1 による）

$`= a^{m + 1}`$ （定義 2 による）

帰納段階：

$`a^m a^n = a^{m + n}`$ と仮定する。すると：

$`a^m a^{n + 1} = a^m(a^n a)`$ （定義 2 による）

$`= (a^m a^n)a`$ （結合法則による）

$`= a^{m + n} a`$ （帰納法の仮定による）

$`= a^{(m + n) + 1}`$ （定義 2 による）

$`= a^{m + (n + 1)}`$ （結合法則による）

</details>

<details>
<summary>累乗の累乗</summary>

$`(a^m)^n = a^{mn}`$

基底ケース（$`n = 1`$）：

$`(a^m)^1 = a^m`$ （定義 1 による）

$`= a^{m \cdot 1}`$ （恒等式による）

帰納段階：

$`(a^m)^n = a^{mn}`$ と仮定する。すると：

$`(a^m)^{n + 1} = (a^m)^n a^m`$ （定義 2 による）

$`= a^{mn} a^m`$ （帰納法の仮定による）

$`= a^{mn + m}`$ （冪の積による）

$`= a^{m(n + 1)}`$ （分配法則による）

</details>

<details>
<summary>積の累乗</summary>

$`(ab)^n = a^n b^n`$

基底ケース（$`n = 1`$）：

$`(ab)^1 = ab`$ （定義 1 による）

$`= a^1 b^1`$ （定義 1 による）

帰納段階：

$`(ab)^n = a^n b^n`$ と仮定する。すると：

$`(ab)^{n + 1} = (ab)^n(ab)`$ （定義 2 による）

$`= (a^n b^n)(ab)`$ （帰納法の仮定による）

$`= (a^n a)(b^n b)`$ （結合法則と交換法則による）

$`= a^{n + 1} b^{n + 1}`$ （定義 2 による）

</details>

## 対数法則

$`a, b, M, N, x > 0`$ と $`n`$ を実数とし、$`a, b \ne 1`$ とする。対数は累乗の逆演算であるから、次が成り立つ

$`\log_a(a^x) = a^{\log_a x} = x`$

ちょうど $`f^{-1}(f(x)) = f(f^{-1}(x)) = x`$ と同様である。これを使うと：

$`\log_a(MN) = \log_a(a^{\log_a M} a^{\log_a N}) = \log_a(a^{\log_a M + \log_a N}) = \log_a M + \log_a N`$

$`\log_a(M^n) = \log_a((a^{\log_a M})^n) = \log_a(a^{n \log_a M}) = n \log_a M`$

$`\log_a M = \displaystyle \frac{\log_a M \cdot \log_b a}{\log_b a} = \frac{\log_b(a^{\log_a M})}{\log_b a} = \frac{\log_b M}{\log_b a}`$

## 分数

## 連立一次方程式

## 数列

## 微分

## 三角関数の恒等式

### ピタゴラスの恒等式

### 加法定理

$`\cos(\alpha + \beta) + i \sin(\alpha + \beta) = e^{i(\alpha + \beta)}`$

$`= e^{i\alpha} e^{i\beta}`$

$`= (\cos \alpha + i \sin \alpha)(\cos \beta + i \sin \beta)`$

$`= (\cos \alpha \cos \beta - \sin \alpha \sin \beta) + i(\sin \alpha \cos \beta + \cos \alpha \sin \beta)`$

### 倍角の公式

$`\sin 2\theta = \sin(\theta + \theta) = \sin \theta \cos \theta + \cos \theta \sin \theta = 2 \sin \theta \cos \theta`$

$`\cos 2\theta = \cos(\theta + \theta) = \cos \theta \cos \theta - \sin \theta \sin \theta = \cos^2 \theta - \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = (1 - \sin^2 \theta) - \sin^2 \theta = 1 - 2 \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = \cos^2 \theta - (1 - \cos^2 \theta) = 2 \cos^2 \theta - 1`$

### 多倍角の公式

$`\cos n\theta + i \sin n\theta = (\cos \theta + i \sin \theta)^n = \displaystyle \sum_{k = 0}^n \binom{n}{k} \cos^{n - k} \theta \, i^k \sin^k \theta`$

## オイラーの公式

$`e^{ix} = f + ig`$ と置く（式 1）。

両辺を $`x`$ で微分すると：

$`(e^{ix})' = (f + ig)'`$

$`ie^{ix} = f' + ig'`$ （式 2）

式 1 を左辺に代入すると：

$`i(f + ig) = f' + ig'`$

$`-g + if = f' + ig'`$

両辺の実部と虚部を比較すると：

$`-g = f'`$

$`f = g'`$

これは次のように書き換えられる：

$`f'' = -f`$

$`g'' = -g`$

これらは2階微分方程式であり、初期条件 $`f(0) = 1`$、$`f'(0) = 0`$、$`g(0) = 0`$、$`g'(0) = 1`$ は式 1 と式 2 に $`x = 0`$ を代入して得られる。その唯一の解は：

$`f = \cos x`$

$`g = \sin x`$

[[#math|Math]]
