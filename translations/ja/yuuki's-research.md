---
title: yuukiの研究
---

< [[yuuki]]

## 文字列の生成

与えられたアルファベット上の可能なすべての文字列を生成することは難しい。Pythonでは、単純な場合には `itertools.product` を使うことができる:

```py
from itertools import product

MAX_LENGTH = 5

alphabet = (
    "a", "b", "c", "d", "e", "f", "g",
    "h", "i", "j", "k", "l", "m", "n",
    "o", "p", "q", "r", "s", "t", "u",
    "v", "w", "x", "y", "z",
)

for length in range(1, MAX_LENGTH + 1):
    for chars in product(alphabet, repeat=length):
        print("".join(chars))

# Output:
# a
# b
# ...
# z
# aa
# ab
# ...
# zz
# aaa
# ...
# zzzzz
```

<details>
<summary>文字列の総数</summary>

"a" から "z" までで26個の文字列があり、"aa" から "zz" までで $`26^2`$ 個ある。長さ $`n`$ 以下の文字列の総数は

$`26 + 26^2 + \cdots + 26^n = \displaystyle \frac{26(26^n - 1)}{25}`$.

一般に、初項 $`r`$、公比 $`r`$ の等比数列の $`n`$ 項の和は $`\frac{r(1 - r^n)}{1 - r}`$ である:

$`
\begin{aligned}
r + r^2 + \cdots + r^n &= \frac{(r + r^2 + \cdots + r^n)(1 - r)}{1 - r} \\
&= \frac{\begin{aligned}
  r &+ r^2 + \cdots + r^n \\
    &- r^2 - \cdots - r^n - r^{n + 1}
\end{aligned}}{1 - r} \\
&= \frac{r - r^{n + 1}}{1 - r} \\
&= \frac{r(1 - r^n)}{1 - r}
\end{aligned}
`$

</details>

以下はローマ字で書かれた日本語のアルファベット（五十音）の44要素である。"n" を含めると衝突が起きる。"na"、"ni" などは2回生成される。

```py
alphabet = (
    "a", "i", "u", "e", "o",
    "ka", "ki", "ku", "ke", "ko",
    "sa", "shi", "su", "se", "so",
    "ta", "chi", "tsu", "te", "to",
    "na", "ni", "nu", "ne", "no",
    "ha", "hi", "fu", "he", "ho",
    "ma", "mi", "mu", "me", "mo",
    "ya", "yu", "yo",
    "ra", "ri", "ru", "re", "ro",
    "wa",
)
```

長さ $`n`$ のローマ字文字列の数は、定数係数の3階同次線形漸化式

$`a_n = 5a_{n - 1} + 36a_{n - 2} + 3a_{n - 3}`$,

を満たし、初期条件は $`a_1 = 5`$、$`a_2 = 61`$、$`a_3 = 488`$ である。

| $`n`$ | $`a_n`$ | $`26^n`$ |
| --- | --- | --- |
| 1 | 5 | 26 |
| 2 | 61 | 676 |
| 3 | 488 | 17,576 |
| 4 | 4,651 | 456,976 |
| 5 | 41,006 | 11,881,376 |
| 6 | 373,930 | 308,915,776 |

## 遠近法のある平面

<img src="https://github.com/user-attachments/assets/d1cb0492-afd6-4d54-b0da-ab61ca5ddc18" alt="A human and a bot are touching each other; the distance between the centers of their bases is 50 at y = 0, but only 30 at y = 200." width="270" height="480">

あなたが $`(0, 0)`$ にいるとき、ボットは $`(50, 0)`$ にあるときにあなたに触れ、距離は50である。

しかし、あなたが $`(0, 200)`$ にいるとき、ボットは $`(30, 200)`$ にあるときにあなたに触れ、距離はわずか30である。

ボットがあなたについてくるように、あなたの位置 $`(x, y)`$ からボットの位置 $`(x', y')`$ を求める式は何か。

<details>
<summary>答え</summary>

$`y = 0`$ のとき:

$`x' = x + 50`$

$`y = 200`$ のとき:

$`x' = x + 30`$

$`x'`$ は $`y`$ に依存することが分かる。$`x' = x + f(y)`$ と置く。$`f(y) = ay + b`$ と仮定する。すると:

$`
\left\{ \begin{alignedat}{3}
& f(0)   &&= b        &&= 50 \\
& f(200) &&= 200a + b &&= 30
\end{alignedat} \right.
`$

したがって、$`f(y) = -\frac{y}{10} + 50`$ である。答えは2次元アフィン変換である:

$`
\left\{ \begin{alignedat}{2}
& x' &&= x - \frac{y}{10} + 50 \\
& y' &&= y
\end{alignedat} \right.
`$

$`
\iff \begin{pmatrix}
x' \\
y'
\end{pmatrix} = \begin{pmatrix}
1 & -\frac{1}{10} \\
0 & 1
\end{pmatrix} \begin{pmatrix}
x \\
y
\end{pmatrix} + \begin{pmatrix}
50 \\
0
\end{pmatrix}
`$

</details>
