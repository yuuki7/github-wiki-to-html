---
title: LilyPondの楽譜
---

[[#yuuki|yuuki]] [[#music|Music]]

楽譜の記法を文字列として形式化するのは面白い。

MusicXMLは実用的な交換形式であり、MuseScoreのようなアプリケーションが対応している。しかし、手で書くには冗長すぎる。

LilyPondの記法は、簡単な楽譜を書くのに便利である。ただし交換性は低く、他の形式に変換するツールは少ない。

他にも多くの形式がある：

| Format                     |
|----------------------------|
| Music Macro Language (MML) |
| ABC notation               |
| LilyPond notation          |
| Guido notation             |
| MEI                        |
| MusicXML                   |
| MNX                        |

以下は、伝統音楽のLilyPond楽譜の断片である。

リポジトリ：https://github.com/yuuki7/sheetmusic

## Happy Birthday to You

```lilypond
\fixed c' {
  \time 3/4

  \partial 4
  g8.[ g16] | a4 g4 c'4 | b2 g8.[ g16] | a4 g4 d'4 | c'2 g8.[ g16] | \break

  g'4 e'4 c'4 | b4 a4\fermata f'8.[ f'16] | e'4 c'4 d'4 | c'2 \bar "|."
}
```

!["Happy Birthday to You"の楽譜](https://cdn.jsdelivr.net/gh/yuuki7/sheetmusic/happy/happy.svg)

<details>
<summary>再生</summary>

["Happy Birthday to You"を再生](https://github.com/user-attachments/assets/2495c0e8-170b-4230-9838-9d4fbe2c85be)

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

!["Row, Row, Row Your Boat"の楽譜](https://cdn.jsdelivr.net/gh/yuuki7/sheetmusic/row/row.svg)

<details>
<summary>再生</summary>

["Row, Row, Row Your Boat"を再生](https://github.com/user-attachments/assets/58783036-f6ae-4422-9c6a-f5f1fd4b9972)

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

!["Twinkle, Twinkle, Little Star"の楽譜](https://cdn.jsdelivr.net/gh/yuuki7/sheetmusic/twinkle/twinkle.svg)

<details>
<summary>再生</summary>

["Twinkle, Twinkle, Little Star"を再生](https://github.com/user-attachments/assets/bc352143-674d-4313-9bca-53b110c24b6a)

</details>
