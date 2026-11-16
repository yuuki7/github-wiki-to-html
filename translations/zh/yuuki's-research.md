---
title: yuuki 的研究
---

< [[yuuki]]

## 字符串生成

生成给定字母表上的所有可能字符串是困难的。在 Python 中，简单情况下可以使用 `itertools.product`:

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
<summary>字符串的总数</summary>

从 "a" 到 "z" 有 26 个字符串，从 "aa" 到 "zz" 有 $`26^2`$ 个。长度为 $`n`$ 或更短的字符串总数为

$`26 + 26^2 + \cdots + 26^n = \displaystyle \frac{26(26^n - 1)}{25}`$.

一般地，首项为 $`r`$、公比为 $`r`$ 的等比数列的前 $`n`$ 项之和为 $`\frac{r(1 - r^n)}{1 - r}`$:

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

以下是用罗马字书写的 44 个日语字母（五十音）元素。包含 "n" 会导致冲突；"na"、"ni" 等会被生成两次。

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

长度为 $`n`$ 的罗马字字符串的数量满足常系数三阶齐次线性递推关系

$`a_n = 5a_{n - 1} + 36a_{n - 2} + 3a_{n - 3}`$,

初始条件为 $`a_1 = 5`$、$`a_2 = 61`$ 和 $`a_3 = 488`$。

| $`n`$ | $`a_n`$ | $`26^n`$ |
| --- | --- | --- |
| 1 | 5 | 26 |
| 2 | 61 | 676 |
| 3 | 488 | 17,576 |
| 4 | 4,651 | 456,976 |
| 5 | 41,006 | 11,881,376 |
| 6 | 373,930 | 308,915,776 |

## 具有透视的平面

<img src="https://github.com/user-attachments/assets/d1cb0492-afd6-4d54-b0da-ab61ca5ddc18" alt="A human and a bot are touching each other; the distance between the centers of their bases is 50 at y = 0, but only 30 at y = 200." width="270" height="480">

当你位于 $`(0, 0)`$ 时，机器人位于 $`(50, 0)`$ 时会触碰到你，距离为 50。

然而，当你位于 $`(0, 200)`$ 时，机器人位于 $`(30, 200)`$ 时就会触碰到你，距离仅为 30。

求机器人位置 $`(x', y')`$ 相对于你的位置 $`(x, y)`$ 的公式是什么，才能使机器人跟随你？

<details>
<summary>答案</summary>

当 $`y = 0`$ 时:

$`x' = x + 50`$

当 $`y = 200`$ 时:

$`x' = x + 30`$

可以看到 $`x'`$ 依赖于 $`y`$。设 $`x' = x + f(y)`$。假设 $`f(y) = ay + b`$。则:

$`
\left\{ \begin{alignedat}{3}
& f(0)   &&= b        &&= 50 \\
& f(200) &&= 200a + b &&= 30
\end{alignedat} \right.
`$

因此，$`f(y) = -\frac{y}{10} + 50`$。答案是二维仿射变换:

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
