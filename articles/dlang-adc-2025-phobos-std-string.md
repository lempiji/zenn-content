---
title: "D言語標準ライブラリ紹介：std.string"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: true
----------------

[![dlang-adc-2025-phobos-std-string](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-string.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-string.yml)

## はじめに

この記事は、Qiita D言語 Advent Calendar 2025 の8日目の記事です。

https://qiita.com/advent-calendar/2025/dlang

サクッと読める標準ライブラリ紹介シリーズ、今回は `std.string` を取り上げます。


## `std.string` 紹介

https://dlang.org/phobos/std_string.html


`std.string` は、Dの文字列まわりで「よく出る前処理・探索・判定」をまとめて押さえられるモジュールです。非常に頻出で利便性が高い関数が多く入っているので、ぜひ覚えておきたいところです。

ちなみにここで扱う文字列型は `string` / `wstring` / `dstring` の不変型文字列と、 `char[]` / `wchar[]` / `dchar[]` の可変文字列があります。
関数によってどちらを要求するか変わってきますので、そのあたりは関数の機能から見極めるか、ドキュメントを参照してください。

この記事では、個人的によく使う **6つの機能** をピックアップして紹介します。

## 1. strip

**前後の空白を落としてから処理する**、は入力処理の定番です。
`strip` は両端、`stripLeft` / `stripRight` は片側だけを削れます。よく `trim` と呼ばれたりもします。

空白判定は既定で `std.uni.isWhite` を使用します。タブ文字なんかも対象です。
それに加えて「この文字集合を削る」という指定もできます。
ユーザー入力や設定値の前処理とするのはもちろんですが、URLの末尾 `/` などを削りたいときにも便利です。

**使用例**

```d global name=strip_example
import std.stdio : writeln;
import std.string : strip, stripLeft, stripRight;

void main()
{
    auto a = " \t  hello world \n ".strip;
    writeln(a); // "hello world"

    auto b = "///api/v1///".strip("/"); // 端の '/' だけ削る（文字集合指定）
    writeln(b); // "api/v1"

    auto c = "  **note**  ".stripLeft(" ").stripRight(" ");
    writeln(c); // "**note**"
}
```


## 2. chomp / chompPrefix 

`chomp(str)` は、末尾に改行系があれば **1 個だけ**　落とします（`"\r"`, `"\n"`, `"\r\n"` など）。delimiter 指定版もあり、末尾がその delimiter で終わるときにだけ削れます。

また、`chompPrefix(str, delimiter)` というものもあります。これは「その prefix が付いているときだけ削る」という関数です。URL スキームや "Bearer" のようなヘッダの前置きがあるところで便利です。

**使用例**

```d global name=chomp_example
import std.stdio : writeln;
import std.string : chomp, chompPrefix;

void main()
{
    writeln(chomp(" hello\n"));     // " hello"
    writeln(chomp("hello \r\n"));   // "hello "
    writeln(chomp("hello \n\n"));   // "hello \n"（1個だけ落とす）

    writeln(chomp("hello world", "orld")); // "hello w"


    writeln(chompPrefix("Bearer abcdef", "Bearer ")); // "abcdef"
    writeln(chompPrefix("Token abcdef",  "Bearer ")); // "Token abcdef"（一致しないのでそのまま）
}
```


## 3. startsWith / endsWith

`startsWith` / `endsWith` は **前方一致 / 後方一致** の判定として頻出の関数です。
`std.string` からも使えますが、実体は `std.algorithm.searching` 側の関数が `public import` されています。

**使用例**

```d global name=startswith_example
import std.stdio : writeln;
import std.string : startsWith, endsWith;

void main()
{
    auto s = "report_2025.json";

    writeln(s.startsWith("report_")); // true
    writeln(s.endsWith(".json"));     // true
}
```


## 4. indexOf / lastIndexOf

文字列中の何かを探して「位置」を返す関数です。
`indexOf` は最初に見つかった位置、`lastIndexOf` は最後に見つかった位置を返します。
どちらも見つからない場合は `-1` を返す設計です。

また `CaseSensitive` を引数で切り替えられます。デフォルトは大文字小文字を区別する設定です。

**使用例**

```d global name=indexof_example
import std.stdio : writeln;
import std.string : indexOf, lastIndexOf;
import std.typecons : No; // No.caseSensitive

void main()
{
    auto s = "Hello hello";

    writeln(s.indexOf('e'));              // 1
    writeln(s.indexOf("hello"));          // 6
    writeln(s.indexOf("HELLO"));          // -1
    writeln(s.indexOf("HELLO", No.caseSensitive)); // 0（大小無視）

    writeln(s.lastIndexOf('l'));          // 最後の 'l' の位置
    writeln(s.indexOf('l', 3));           // 3 以降で最初の 'l'
}
```


## 5. splitLines / lineSplitter

ログ・設定ファイル・簡易データなど、文字列を「行ごとに分割する」という関数です。

* `splitLines`：**行の配列**を作って返す（使い勝手がよい）
* `lineSplitter`：入力を **スライスの range として返す**（`foreach` でそのまま回せる）

**とりあえず行単位に回すなら `lineSplitter` が軽量**で、その後必要なら `std.array` の `array` で配列化すればOK、という分かりやすい指針です。

**使用例**

```d global name=splitLines_example
import std.stdio : writeln;
import std.string : splitLines;

void main()
{
    auto text = "alpha\r\nbeta\ngamma";
    auto lines = splitLines(text);

    writeln(lines); // ["alpha", "beta", "gamma"]
}
```

```d global name=lineSplitter_example
import std.stdio : writeln;
import std.string : lineSplitter;

void main()
{
    auto text = "alpha\r\nbeta\ngamma";

    foreach (line; text.lineSplitter())
    {
        writeln(line);
    }
}
```


## 6. std.array の再公開系（std.string からも呼べる）

`std.string` は、`std.array` の `split / join / replace / replaceInPlace / empty` を **public import** しています。
`import std.string;` だけで、文字列を扱っていて「つい欲しくなる配列系の関数」も一緒に入ってきます。`string` は `immutable(char)[]` のエイリアスなので、`std.array` 側の関数も普通に使えるわけですね。便利。

**使用例**

```d global name=std_string_array_example
import std.stdio : writeln;
import std.string; // split / join / replace なども入る（public import）

void main()
{
    auto parts = "a,b,c".split(",");
    writeln(parts.join("|"));            // "a|b|c"
    writeln("a|b|c".replace("|", ","));  // "a,b,c"
}
```


## まとめ

前処理で `strip` を使ったりするのは結構多いと思います。加えて `chomp` や `startsWith` / `endsWith`、`indexOf` あたりも頻出です。

とりあえず `std.string` を `import` しておけば、文字列まわりの基本的な操作は大体カバーできると思いますので、ぜひ活用してみてください。

https://dlang.org/phobos/std_string.html
