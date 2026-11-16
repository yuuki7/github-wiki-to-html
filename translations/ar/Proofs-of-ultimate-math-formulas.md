---
title: براهين الصيغ الرياضية النهائية
---

< [[Ultimate math formulas]]

## التوسيع والتحليل إلى عوامل

## الصيغة التربيعية

## قوانين الأسس

ليكن $`a`$ و $`b`$ عددين حقيقيين، وليكن $`m`$ و $`n`$ عددين صحيحين موجبين.

**تعريف (*الرفع إلى قوة*):**

$`a^1 = a`$ (التعريف 1)

$`a^{n + 1} = a^n a`$ من أجل $`n \ge 1`$ (التعريف 2)

بالاستقراء على $`n`$:

<details>
<summary>حاصل ضرب القوى</summary>

$`a^m a^n = a^{m + n}`$

حالة الأساس ($`n = 1`$):

$`a^m a^1 = a^m a`$ (بحسب التعريف 1)

$`= a^{m + 1}`$ (بحسب التعريف 2)

خطوة الاستقراء:

افترض أن $`a^m a^n = a^{m + n}`$. عندئذٍ:

$`a^m a^{n + 1} = a^m(a^n a)`$ (بحسب التعريف 2)

$`= (a^m a^n)a`$ (بالخاصية التجميعية)

$`= a^{m + n} a`$ (بفرض الاستقراء)

$`= a^{(m + n) + 1}`$ (بحسب التعريف 2)

$`= a^{m + (n + 1)}`$ (بالخاصية التجميعية)

</details>

<details>
<summary>قوة قوة</summary>

$`(a^m)^n = a^{mn}`$

حالة الأساس ($`n = 1`$):

$`(a^m)^1 = a^m`$ (بحسب التعريف 1)

$`= a^{m \cdot 1}`$ (بالمتطابقة)

خطوة الاستقراء:

افترض أن $`(a^m)^n = a^{mn}`$. عندئذٍ:

$`(a^m)^{n + 1} = (a^m)^n a^m`$ (بحسب التعريف 2)

$`= a^{mn} a^m`$ (بفرض الاستقراء)

$`= a^{mn + m}`$ (بحاصل ضرب القوى)

$`= a^{m(n + 1)}`$ (بالخاصية التوزيعية)

</details>

<details>
<summary>قوة حاصل ضرب</summary>

$`(ab)^n = a^n b^n`$

حالة الأساس ($`n = 1`$):

$`(ab)^1 = ab`$ (بحسب التعريف 1)

$`= a^1 b^1`$ (بحسب التعريف 1)

خطوة الاستقراء:

افترض أن $`(ab)^n = a^n b^n`$. عندئذٍ:

$`(ab)^{n + 1} = (ab)^n(ab)`$ (بحسب التعريف 2)

$`= (a^n b^n)(ab)`$ (بفرض الاستقراء)

$`= (a^n a)(b^n b)`$ (بالخاصيتين التجميعية والتبديلية)

$`= a^{n + 1} b^{n + 1}`$ (بحسب التعريف 2)

</details>

## قوانين اللوغاريتمات

ليكن $`a, b, M, N, x > 0`$ و $`n`$ أعدادًا حقيقية، مع $`a, b \ne 1`$. وبما أن اللوغاريتم هو معكوس الرفع إلى قوة، فإن لدينا

$`\log_a(a^x) = a^{\log_a x} = x`$،

تمامًا مثل $`f^{-1}(f(x)) = f(f^{-1}(x)) = x`$. وباستخدام ذلك:

$`\log_a(MN) = \log_a(a^{\log_a M} a^{\log_a N}) = \log_a(a^{\log_a M + \log_a N}) = \log_a M + \log_a N`$

$`\log_a(M^n) = \log_a((a^{\log_a M})^n) = \log_a(a^{n \log_a M}) = n \log_a M`$

$`\log_a M = \displaystyle \frac{\log_a M \cdot \log_b a}{\log_b a} = \frac{\log_b(a^{\log_a M})}{\log_b a} = \frac{\log_b M}{\log_b a}`$

## الكسور

## أنظمة المعادلات الخطية

## المتتاليات

## المشتقات

## المتطابقات المثلثية

### متطابقة فيثاغورس

### صيغ الجمع

$`\cos(\alpha + \beta) + i \sin(\alpha + \beta) = e^{i(\alpha + \beta)}`$

$`= e^{i\alpha} e^{i\beta}`$

$`= (\cos \alpha + i \sin \alpha)(\cos \beta + i \sin \beta)`$

$`= (\cos \alpha \cos \beta - \sin \alpha \sin \beta) + i(\sin \alpha \cos \beta + \cos \alpha \sin \beta)`$

### صيغ الزاوية المضاعفة

$`\sin 2\theta = \sin(\theta + \theta) = \sin \theta \cos \theta + \cos \theta \sin \theta = 2 \sin \theta \cos \theta`$

$`\cos 2\theta = \cos(\theta + \theta) = \cos \theta \cos \theta - \sin \theta \sin \theta = \cos^2 \theta - \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = (1 - \sin^2 \theta) - \sin^2 \theta = 1 - 2 \sin^2 \theta`$

$`\cos^2 \theta - \sin^2 \theta = \cos^2 \theta - (1 - \cos^2 \theta) = 2 \cos^2 \theta - 1`$

### صيغ الزوايا المتعددة

$`\cos n\theta + i \sin n\theta = (\cos \theta + i \sin \theta)^n = \displaystyle \sum_{k = 0}^n \binom{n}{k} \cos^{n - k} \theta \, i^k \sin^k \theta`$

## صيغة أويلر

ليكن $`e^{ix} = f + ig`$ (المعادلة 1).

باشتقاق الطرفين بالنسبة إلى $`x`$:

$`(e^{ix})' = (f + ig)'`$

$`ie^{ix} = f' + ig'`$ (المعادلة 2)

بتعويض المعادلة 1 في الطرف الأيسر:

$`i(f + ig) = f' + ig'`$

$`-g + if = f' + ig'`$

بمساواة الجزأين الحقيقي والتخيلي في الطرفين:

$`-g = f'`$

$`f = g'`$

ويمكن إعادة كتابة ذلك على النحو التالي:

$`f'' = -f`$

$`g'' = -g`$

هذه معادلات تفاضلية من الدرجة الثانية بشروط ابتدائية $`f(0) = 1`$ و $`f'(0) = 0`$ و $`g(0) = 0`$ و $`g'(0) = 1`$، يتم الحصول عليها بتعويض $`x = 0`$ في المعادلتين 1 و 2. والحلول الوحيدة هي:

$`f = \cos x`$

$`g = \sin x`$

[[#math|Math]]
