---
title: Beweise der ultimativen mathematischen Formeln
---

< [[Ultimate math formulas]]

## Ausmultiplizieren und Faktorisieren

## Quadratische Formel

## Potenzgesetze

Seien $`a`$ und $`b`$ reelle Zahlen und seien $`m`$ und $`n`$ positive ganze Zahlen.

**Definition (*Potenzierung*):**

$`a^1 = a`$ (Def. 1)

$`a^{n + 1} = a^n a`$ für $`n \ge 1`$ (Def. 2)

Durch Induktion über $`n`$:

<details>
<summary>Produkt von Potenzen</summary>

$`a^m a^n = a^{m + n}`$

Basisfall ($`n = 1`$):

$`a^m a^1 = a^m a`$ (nach Def. 1)

$`= a^{m + 1}`$ (nach Def. 2)

Induktionsschritt:

Angenommen, $`a^m a^n = a^{m + n}`$. Dann gilt:

$`a^m a^{n + 1} = a^m(a^n a)`$ (nach Def. 2)

$`= (a^m a^n)a`$ (durch Assoziativität)

$`= a^{m + n} a`$ (nach der Induktionsvoraussetzung)

$`= a^{(m + n) + 1}`$ (nach Def. 2)

$`= a^{m + (n + 1)}`$ (durch Assoziativität)

</details>

<details>
<summary>Potenz einer Potenz</summary>

$`(a^m)^n = a^{mn}`$

Basisfall ($`n = 1`$):

$`(a^m)^1 = a^m`$ (nach Def. 1)

$`= a^{m \cdot 1}`$ (durch Identität)

Induktionsschritt:

Angenommen, $`(a^m)^n = a^{mn}`$. Dann gilt:

$`(a^m)^{n + 1} = (a^m)^n a^m`$ (nach Def. 2)

$`= a^{mn} a^m`$ (nach der Induktionsvoraussetzung)

$`= a^{mn + m}`$ (durch Produkt von Potenzen)

$`= a^{m(n + 1)}`$ (durch Distributivität)

</details>

<details>
<summary>Potenz eines Produkts</summary>

$`(ab)^n = a^n b^n`$

Basisfall ($`n = 1`$):

$`(ab)^1 = ab`$ (nach Def. 1)

$`= a^1 b^1`$ (nach Def. 1)

Induktionsschritt:

Angenommen, $`(ab)^n = a^n b^n`$. Dann gilt:

$`(ab)^{n + 1} = (ab)^n(ab)`$ (nach Def. 2)

$`= (a^n b^n)(ab)`$ (nach der Induktionsvoraussetzung)

$`= (a^n a)(b^n b)`$ (durch Assoziativität und Kommutativität)

$`= a^{n + 1} b^{n + 1}`$ (nach Def. 2)

</details>

## Logarithmengesetze

Seien $`a, b, M, N, x > 0`$ und $`n`$ reelle Zahlen mit $`a, b \ne 1`$. Da ein Logarithmus eine Umkehrung der Potenzierung ist, gilt

$`\log_a(a^x) = a^{\log_a x} = x`$,

genau wie $`f^{-1}(f(x)) = f(f^{-1}(x)) = x`$. Daraus folgt:

$`\log_a(MN) = \log_a(a^{\log_a M} a^{\log_a N}) = \log_a(a^{\log_a M + \log_a N}) = \log_a M + \log_a N`$

$`\log_a(M^n) = \log_a((a^{\log_a M})^n) = \log_a(a^{n \log_a M}) = n \log_a M`$

$`\log_a M = \displaystyle \frac{\log_a M \cdot \log_b a}{\log_b a} = \frac{\log_b(a^{\log_a M})}{\log_b a} = \frac{\log_b M}{\log_b a}`$

## Brüche

## Lineare Gleichungssysteme

## Folgen

## Ableitungen

## Trigonometrische Identitäten

### Trigonometrischer Pythagoras

### Additionstheoreme

$`\cos(\alpha + \beta) + i \sin(\alpha + \beta) = e^{i(\alpha + \beta)}`$

$`= e^{i\alpha} e^{i\beta}`$

$`= (\cos \alpha + i \sin \alpha)(\cos \beta + i \sin \beta)`$

$`= (\cos \alpha \cos \beta - \sin \alpha \sin \beta) + i(\sin \alpha \cos \beta + \cos \alpha \sin \beta)`$

### Doppelwinkelformeln

$`\sin 2\theta = \sin(\theta + \theta) = \sin \theta \cos \theta + \cos \theta \sin \theta = 2 \sin \theta \cos \theta`$

$`\cos 2\theta = \cos(\theta + \theta) = \cos \theta \cos \theta - \sin \theta \sin \theta = \cos^2 \theta - \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = (1 - \sin^2 \theta) - \sin^2 \theta = 1 - 2 \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = \cos^2 \theta - (1 - \cos^2 \theta) = 2 \cos^2 \theta - 1`$

### Mehrfachwinkelformeln

$`\cos n\theta + i \sin n\theta = (\cos \theta + i \sin \theta)^n = \displaystyle \sum_{k = 0}^n \binom{n}{k} \cos^{n - k} \theta \, i^k \sin^k \theta`$

## Eulersche Formel

Sei $`e^{ix} = f + ig`$ (Gl. 1).

Differenzieren beider Seiten nach $`x`$ ergibt:

$`(e^{ix})' = (f + ig)'`$

$`ie^{ix} = f' + ig'`$ (Gl. 2)

Einsetzen von Gl. 1 in die linke Seite ergibt:

$`i(f + ig) = f' + ig'`$

$`-g + if = f' + ig'`$

Gleichsetzen der Real- und Imaginärteile beider Seiten ergibt:

$`-g = f'`$

$`f = g'`$

Dies lässt sich umschreiben zu:

$`f'' = -f`$

$`g'' = -g`$

Dies sind Differentialgleichungen zweiter Ordnung mit den Anfangsbedingungen $`f(0) = 1`$, $`f'(0) = 0`$, $`g(0) = 0`$ und $`g'(0) = 1`$, die man durch Einsetzen von $`x = 0`$ in die Gleichungen 1 und 2 erhält. Die eindeutigen Lösungen sind:

$`f = \cos x`$

$`g = \sin x`$

[[#math|Math]]
