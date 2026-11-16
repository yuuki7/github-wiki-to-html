---
title: yuukis Forschung
---

< [[yuuki]]

## Erzeugung von Zeichenketten

Alle möglichen Zeichenketten über einem gegebenen Alphabet zu erzeugen, ist schwierig. In Python kann man in einem einfachen Fall `itertools.product` verwenden:

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
<summary>Gesamtzahl der Zeichenketten</summary>

Es gibt 26 Zeichenketten von "a" bis "z" und $`26^2`$ von "aa" bis "zz". Die Gesamtzahl der Zeichenketten der Länge $`n`$ oder weniger ist

$`26 + 26^2 + \cdots + 26^n = \displaystyle \frac{26(26^n - 1)}{25}`$.

Allgemein ist die Summe von $`n`$ Gliedern einer geometrischen Folge mit erstem Glied $`r`$ und Quotient $`r`$ gleich $`\frac{r(1 - r^n)}{1 - r}`$:

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

Im Folgenden stehen die 44 Elemente des japanischen Alphabets (Gojūon), geschrieben in Rōmaji. Die Aufnahme von "n" verursacht Kollisionen; "na", "ni" usw. werden zweimal erzeugt.

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

Die Anzahl der Rōmaji-Zeichenketten der Länge $`n`$ erfüllt die homogene lineare Rekurrenz dritter Ordnung mit konstanten Koeffizienten

$`a_n = 5a_{n - 1} + 36a_{n - 2} + 3a_{n - 3}`$,

mit den Anfangsbedingungen $`a_1 = 5`$, $`a_2 = 61`$ und $`a_3 = 488`$.

| $`n`$ | $`a_n`$ | $`26^n`$ |
| --- | --- | --- |
| 1 | 5 | 26 |
| 2 | 61 | 676 |
| 3 | 488 | 17,576 |
| 4 | 4,651 | 456,976 |
| 5 | 41,006 | 11,881,376 |
| 6 | 373,930 | 308,915,776 |

## Ebenen mit Perspektive

<img src="https://github.com/user-attachments/assets/d1cb0492-afd6-4d54-b0da-ab61ca5ddc18" alt="A human and a bot are touching each other; the distance between the centers of their bases is 50 at y = 0, but only 30 at y = 200." width="270" height="480">

Wenn du bei $`(0, 0)`$ bist, berührt dich der Bot, wenn er bei $`(50, 0)`$ ist, in einem Abstand von 50.

Wenn du jedoch bei $`(0, 200)`$ bist, berührt dich der Bot, wenn er bei $`(30, 200)`$ ist, in einem Abstand von nur 30.

Wie lautet die Formel, um aus deiner Position $`(x, y)`$ die Position $`(x', y')`$ des Bots zu finden, sodass der Bot dir folgt?

<details>
<summary>Antwort</summary>

Wenn $`y = 0`$:

$`x' = x + 50`$

Wenn $`y = 200`$:

$`x' = x + 30`$

Man sieht, dass $`x'`$ von $`y`$ abhängt. Setze $`x' = x + f(y)`$. Nimm an, $`f(y) = ay + b`$. Dann:

$`
\left\{ \begin{alignedat}{3}
& f(0)   &&= b        &&= 50 \\
& f(200) &&= 200a + b &&= 30
\end{alignedat} \right.
`$

Also ist $`f(y) = -\frac{y}{10} + 50`$. Die Antwort ist die zweidimensionale affine Transformation:

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
