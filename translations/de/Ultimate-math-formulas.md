---
title: Ultimative mathematische Formeln
---

[[Beweise|Proofs of ultimate math formulas]]

## Ausmultiplizieren und Faktorisieren

$`(a + b)^2 = a^2 + 2ab + b^2`$

$`(a + b)^3 = a^3 + 3a^2 b + 3ab^2 + b^3`$

$`(a + b)^n = \displaystyle \sum_{k = 0}^n \binom{n}{k} a^{n - k} b^k`$ (Binomischer Lehrsatz)

$`a^2 - b^2 = (a + b)(a - b)`$

$`a^3 - b^3 = (a - b)(a^2 + ab + b^2)`$

$`a^n - b^n = (a - b) \displaystyle \sum_{k = 0}^{n - 1} a^{n - 1 - k} b^k`$

## Quadratische Formel

$`ax^2 + bx + c = 0`$

$`\implies x = \displaystyle \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}`$

## Potenz- und Logarithmengesetze

$`a^m a^n = a^{m + n}`$

$`(a^m)^n = a^{mn}`$

$`(ab)^n = a^n b^n`$

$`\log_a(MN) = \log_a M + \log_a N`$

$`\log_a(M^n) = n \log_a M`$

$`\log_a M = \displaystyle \frac{\log_b M}{\log_b a}`$

## Brüche

$`\displaystyle \frac{a}{b} + \frac{c}{d} = \frac{ad + bc}{bd}`$

$`\displaystyle \frac{a}{b} + \frac{c}{d} + \frac{e}{f} = \frac{adf + bcf + bde}{bdf}`$

## Lineare Gleichungssysteme

$`
\begin{cases}
ax + by = e \\
cx + dy = f
\end{cases} \iff \begin{pmatrix}
a & b \\
c & d
\end{pmatrix} \begin{pmatrix}
x \\
y
\end{pmatrix} = \begin{pmatrix}
e \\
f
\end{pmatrix}
`$

$`
x = \displaystyle \frac{ed - bf}{ad - bc} = \frac{\begin{vmatrix}
e & b \\
f & d
\end{vmatrix}}{\begin{vmatrix}
a & b \\
c & d
\end{vmatrix}}
`$

$`
y = \displaystyle \frac{af - ec}{ad - bc} = \frac{\begin{vmatrix}
a & e \\
c & f
\end{vmatrix}}{\begin{vmatrix}
a & b \\
c & d
\end{vmatrix}}
`$

## Folgen

$`\displaystyle \sum_{k = 1}^n k = 1 + 2 + \cdots + n = \frac{n(n + 1)}{2}`$

$`\displaystyle \sum_{k = 1}^n \bigl( a + (k - 1)d \bigr) = a + (a + d) + \cdots + \bigl( a + (n - 1)d \bigr) = \frac{n \bigl( 2a + (n - 1)d \bigr)}{2}`$

$`\displaystyle \sum_{k = 1}^n ar^{k - 1} = a + ar + \cdots + ar^{n - 1} = \frac{a(1 - r^n)}{1 - r}`$

## Ableitungen

$`(x^n)' = nx^{n - 1}`$

## Trigonometrische Identitäten

$`\sin^2 \theta + \cos^2 \theta = 1`$ (Trigonometrischer Pythagoras)

### Additionstheoreme

$`\sin(\alpha + \beta) = \sin \alpha \cos \beta + \cos \alpha \sin \beta`$

$`\cos(\alpha + \beta) = \cos \alpha \cos \beta - \sin \alpha \sin \beta`$

### Doppelwinkelformeln

$`\sin 2\theta = 2 \sin \theta \cos \theta`$

$`\cos 2\theta = \cos^2 \theta - \sin^2 \theta = 1 - 2 \sin^2 \theta = 2 \cos^2 \theta - 1`$

### Mehrfachwinkelformeln

$`\sin n\theta = \displaystyle \sum_{k = 0}^{\left\lfloor \frac{n - 1}{2} \right\rfloor} (-1)^k \binom{n}{2k + 1} \cos^{n - (2k + 1)} \theta \sin^{2k + 1} \theta`$

$`\cos n\theta = \displaystyle \sum_{k = 0}^{\left\lfloor \frac{n}{2} \right\rfloor} (-1)^k \binom{n}{2k} \cos^{n - 2k} \theta \sin^{2k} \theta`$

## Eulersche Formel

$`e^{i\pi} + 1 = 0`$ (Eulersche Identität)

$`e^{i\theta} = \cos \theta + i \sin \theta`$ (Eulersche Formel)

$`(\cos \theta + i \sin \theta)^n = \cos n\theta + i \sin n\theta`$ (Formel von De Moivre)

[[#math|Math]]
