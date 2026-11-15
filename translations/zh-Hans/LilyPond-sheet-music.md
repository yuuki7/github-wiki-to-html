---
title: LilyPond 乐谱
---

[[#yuuki|yuuki]] [[#music|Music]]

把乐谱记谱法形式化为字符串，是很有趣的。

MusicXML 是一种实用的交换格式，MuseScore 等应用程序都支持它。但是，它过于冗长，不适合手写。

LilyPond 记谱法很适合用来写简单的乐谱。不过，它的互换性较差；很少有工具能把它转换成其他格式。

还有许多其他格式：

| Format                     |
|----------------------------|
| Music Macro Language (MML) |
| ABC notation               |
| LilyPond notation          |
| Guido notation             |
| MEI                        |
| MusicXML                   |
| MNX                        |

下面是一些传统音乐的 LilyPond 乐谱片段。

仓库：https://github.com/yuuki7/sheetmusic

## Happy Birthday to You

```lilypond
\fixed c' {
  \time 3/4

  \partial 4
  g8.[ g16] | a4 g4 c'4 | b2 g8.[ g16] | a4 g4 d'4 | c'2 g8.[ g16] | \break

  g'4 e'4 c'4 | b4 a4\fermata f'8.[ f'16] | e'4 c'4 d'4 | c'2 \bar "|."
}
```

!["Happy Birthday to You"的乐谱](https://cdn.jsdelivr.net/gh/yuuki7/sheetmusic/happy/happy.svg)

<details>
<summary>播放</summary>

[播放"Happy Birthday to You"](https://github.com/user-attachments/assets/2495c0e8-170b-4230-9838-9d4fbe2c85be)

</details>

## Row, Row, Row Your Boat

```lilypond
\fixed c' {
  \numericTimeSignature
  \time 4/4

  c4 c4 c8.[ d16] e4 | e8.[ d16] e8.[ f16] g2 | \break

  \tuplet 3/2 { c'8[ c'8 c'8] } \tuplet 3/2 { g8[ g8 g8] }
  \tuplet 3/2 { e8[ e8 e8] } \tuplet 3/2 { c8[ c8 c8] }
  | g8.[ f16] e8.[ d16] c2 \bar "|."
}
```

!["Row, Row, Row Your Boat"的乐谱](https://cdn.jsdelivr.net/gh/yuuki7/sheetmusic/row/row.svg)

<details>
<summary>播放</summary>

[播放"Row, Row, Row Your Boat"](https://github.com/user-attachments/assets/58783036-f6ae-4422-9c6a-f5f1fd4b9972)

</details>

## Twinkle, Twinkle, Little Star

```lilypond
\fixed c' {
  \numericTimeSignature
  \time 4/4

  c4 c4 g4 g4 | a4 a4 g2 | f4 f4 e4 e4 | d4 d4 c2 | \break

  g4 g4 f4 f4 | e4 e4 d2 | g4 g4 f4 f4 | e4 e4 d2 | \break

  c4 c4 g4 g4 | a4 a4 g2 | f4 f4 e4 e4 | d4 d4 c2 \bar "|."
}
```

!["Twinkle, Twinkle, Little Star"的乐谱](https://cdn.jsdelivr.net/gh/yuuki7/sheetmusic/twinkle/twinkle.svg)

<details>
<summary>播放</summary>

[播放"Twinkle, Twinkle, Little Star"](https://github.com/user-attachments/assets/bc352143-674d-4313-9bca-53b110c24b6a)

</details>
