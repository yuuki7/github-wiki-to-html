---
title: أبحاث yuuki
---

< [[yuuki]]

## توليد السلاسل

إن توليد جميع السلاسل الممكنة على أبجدية معينة أمر صعب. في Python، يمكنك استخدام `itertools.product` في حالة بسيطة:

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
<summary>العدد الكلي للسلاسل</summary>

هناك 26 سلسلة من "a" إلى "z"، و $`26^2`$ من "aa" إلى "zz". العدد الكلي للسلاسل التي طولها $`n`$ أو أقل هو

$`26 + 26^2 + \cdots + 26^n = \displaystyle \frac{26(26^n - 1)}{25}`$.

بشكل عام، مجموع $`n`$ حدًا من متتالية هندسية حدها الأول $`r`$ ونسبتها المشتركة $`r`$ هو $`\frac{r(1 - r^n)}{1 - r}`$:

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

فيما يلي 44 عنصرًا من الأبجدية اليابانية (غوجوون) مكتوبة بالروماجي. إدراج "n" يسبب تصادمات؛ إذ تُولَّد "na" و"ni" وغيرها مرتين.

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

عدد سلاسل الروماجي ذات الطول $`n`$ يحقق علاقة التكرار الخطية المتجانسة من الدرجة الثالثة ذات المعاملات الثابتة

$`a_n = 5a_{n - 1} + 36a_{n - 2} + 3a_{n - 3}`$,

مع الشروط الابتدائية $`a_1 = 5`$ و $`a_2 = 61`$ و $`a_3 = 488`$.

| $`n`$ | $`a_n`$ | $`26^n`$ |
| --- | --- | --- |
| 1 | 5 | 26 |
| 2 | 61 | 676 |
| 3 | 488 | 17,576 |
| 4 | 4,651 | 456,976 |
| 5 | 41,006 | 11,881,376 |
| 6 | 373,930 | 308,915,776 |

## مستويات ذات منظور

<img src="https://github.com/user-attachments/assets/d1cb0492-afd6-4d54-b0da-ab61ca5ddc18" alt="A human and a bot are touching each other; the distance between the centers of their bases is 50 at y = 0, but only 30 at y = 200." width="270" height="480">

عندما تكون عند $`(0, 0)`$، يلمسك الروبوت عندما يكون عند $`(50, 0)`$، على مسافة 50.

لكن عندما تكون عند $`(0, 200)`$، يلمسك الروبوت عندما يكون عند $`(30, 200)`$، على مسافة 30 فقط.

ما الصيغة لإيجاد موضع الروبوت $`(x', y')`$ انطلاقًا من موضعك $`(x, y)`$ بحيث يتبعك الروبوت؟

<details>
<summary>الإجابة</summary>

عندما يكون $`y = 0`$:

$`x' = x + 50`$

عندما يكون $`y = 200`$:

$`x' = x + 30`$

نرى أن $`x'`$ يعتمد على $`y`$. لتكن $`x' = x + f(y)`$. افترض أن $`f(y) = ay + b`$. عندئذ:

$`
\left\{ \begin{alignedat}{3}
& f(0)   &&= b        &&= 50 \\
& f(200) &&= 200a + b &&= 30
\end{alignedat} \right.
`$

إذن $`f(y) = -\frac{y}{10} + 50`$. الإجابة هي التحويل الأفيني ثنائي الأبعاد:

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
