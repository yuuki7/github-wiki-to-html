---
title: yuuki 的研究
---

< [[yuuki]]

## 字串生成

生成給定字母表上的所有可能字串是困難的。在 Python 中，簡單情況下可以使用 `itertools.product`:

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
<summary>字串的總數</summary>

從 "a" 到 "z" 有 26 個字串，從 "aa" 到 "zz" 有 $`26^2`$ 個。長度為 $`n`$ 或更短的字串總數為

$`26 + 26^2 + \cdots + 26^n = \displaystyle \frac{26(26^n - 1)}{25}`$.

一般地，首項為 $`r`$、公比為 $`r`$ 的等比數列的前 $`n`$ 項之和為 $`\frac{r(1 - r^n)}{1 - r}`$:

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

以下是用羅馬字書寫的 44 個日語字母（五十音）元素。包含 "n" 會導致衝突；"na"、"ni" 等會被生成兩次。

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

長度為 $`n`$ 的羅馬字字串的數量滿足常係數三階齊次線性遞推關係

$`a_n = 5a_{n - 1} + 36a_{n - 2} + 3a_{n - 3}`$,

初始條件為 $`a_1 = 5`$、$`a_2 = 61`$ 和 $`a_3 = 488`$。

| $`n`$ | $`a_n`$ | $`26^n`$ |
| --- | --- | --- |
| 1 | 5 | 26 |
| 2 | 61 | 676 |
| 3 | 488 | 17,576 |
| 4 | 4,651 | 456,976 |
| 5 | 41,006 | 11,881,376 |
| 6 | 373,930 | 308,915,776 |

## 具有透視的平面

<img src="https://github.com/user-attachments/assets/d1cb0492-afd6-4d54-b0da-ab61ca5ddc18" alt="A human and a bot are touching each other; the distance between the centers of their bases is 50 at y = 0, but only 30 at y = 200." width="270" height="480">

當你位於 $`(0, 0)`$ 時，機器人位於 $`(50, 0)`$ 時會觸碰到你，距離為 50。

然而，當你位於 $`(0, 200)`$ 時，機器人位於 $`(30, 200)`$ 時就會觸碰到你，距離僅為 30。

求機器人位置 $`(x', y')`$ 相對於你的位置 $`(x, y)`$ 的公式是什麼，才能使機器人跟隨你？

<details>
<summary>答案</summary>

當 $`y = 0`$ 時:

$`x' = x + 50`$

當 $`y = 200`$ 時:

$`x' = x + 30`$

可以看到 $`x'`$ 依賴於 $`y`$。設 $`x' = x + f(y)`$。假設 $`f(y) = ay + b`$。則:

$`
\left\{ \begin{alignedat}{3}
& f(0)   &&= b        &&= 50 \\
& f(200) &&= 200a + b &&= 30
\end{alignedat} \right.
`$

因此，$`f(y) = -\frac{y}{10} + 50`$。答案是二維仿射變換:

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
