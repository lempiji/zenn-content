---
title: "D言語標準ライブラリ紹介：std.regex"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library", "regex"]
published: true
---

[![dlang-adc-2025-phobos-std-regex](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-regex.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-regex.yml)

# D言語標準ライブラリ紹介：std.regex

## はじめに

こちらは、D言語 Advent Calendar 2025 2日目の記事となります。

https://qiita.com/advent-calendar/2025/dlang

個人的によく使う標準ライブラリを、サクッと「こんなのあるんだ〜」で読める形で紹介していくシリーズです。

## `std.regex` 紹介

https://dlang.org/phobos/std_regex.html

`std.regex` は、D言語の正規表現モジュールです。
典型的には **入力バリデーション / 抽出 / 置換** あたりで出番があります。

正規表現の仕様としてはECMAScript系の文法がベースで、**名前付きキャプチャ**や **Unicode プロパティ** などが拡張として入っています。
肯定否定の先読み戻り読みもサポートし、他の言語の正規表現と大体同じ感覚で使えます。

この記事では、よく使う **8機能** を紹介します。

## 関数別ミニ解説

### 1. `regex`

実行時に正規表現をコンパイルして `Regex` オブジェクトを作ります。
フラグは `"i"`（大小無視）みたいに文字列で渡します（`g i m s x` があります）。

入力となるパターンは **「\`」** （バッククォート）で囲むWYSIWYG文字列で書くのがオススメです。
ちなみに `regex([pat1, pat2, ...])` で「複数パターンのいずれかにマッチする」という `Multi-pattern regex` というのも作れます。

**使用例**

```d global name=regex
import std.regex;
import std.stdio;

void main() {
    auto r = regex(`\b\w+\b`, "i"); // 英単語っぽいものを抽出（大文字小文字無視）
    foreach (c; matchAll("Hello, world!", r)) {
        writeln(c.hit); // "Hello", "world"
    }
}
```


### 2. `ctRegex`

前述 `regex` の亜種で、コンパイル時（CTFE）に正規表現を作って、マッチング用のコードを生成するやつです。
「パターン間違いをビルド時に潰したい」ときに便利です。
ちなみにこれは関数ではなくて **テンプレート** です。

**使用例**

```d global name=ctRegex
import std.regex;
import std.stdio;

void main() {
    // コンパイル時定数なので enum で定義
    enum wordOnly = ctRegex!(`^\p{L}+$`);
    assert(matchFirst("LettersOnly", wordOnly));
    assert(!matchFirst("with_underscore", wordOnly));
}
```

### 3. `matchFirst`

正規表現を使った検索で、入力の **最初の（最左）マッチ**を取ります。

返り値は `Captures` で、
* `c.hit`（マッチ全体）
* `c.pre`（手前）
* `c.post`（後ろ）
* `c[1]` など（キャプチャ）
が使えます。

`Captures` は `if (auto c = matchFirst(...))` みたいに **そのまま真偽で判定できる**のも地味に便利です。

**使用例**（`pre/post/hit`）

```d global name=matchFirst
import std.regex;
import std.stdio;

void main() {
    auto c = matchFirst("@abc#", regex(`(\w)(\w)(\w)`));
    writeln(c.pre); // "@"
    writeln(c.hit); // "abc"
    writeln(c.post); // "#"
}
```

**使用例**（名前付きキャプチャ）

```d global name=matchFirst_named
import std.regex;
import std.stdio;

void main() {
    auto c = matchFirst("a = 42;", regex(`(?P<var>\w+)\s*=\s*(?P<value>\d+);`));
    if (!c) return;

    writeln(c["var"]);   // "a"
    writeln(c["value"]); // "42"
}
```


### 4. `matchAll`

入力中の **非オーバーラップの全マッチ** を列挙するための関数です。
結果は遅延評価されるレンジとして返すので、大きめの入力でも `foreach` で低コストに列挙できます。

**使用例**

```d global name=matchAll
import std.regex;
import std.stdio;

void main() {
    auto text = "2025/12/15 and 7/8/2022";
    auto date = regex(`\b\d{1,4}/\d{1,2}/\d{1,4}\b`);
    foreach (c; matchAll(text, date)) {
        writeln(c.hit);
    }
}
```

### 5. `replaceFirst`

正規表現を使って最初の1回だけ置換します。
置換フォーマットは `$1`（キャプチャ1）や `$&`（全体）などの **簡易フォーマット** です。

**使用例**（キャプチャを並べ替える）

```d global name=replaceFirst
import std.regex;
import std.stdio;

void main() {
    auto s = "2025-12-15";
    auto outStr = replaceFirst(s, regex(`(\d{4})-(\d{2})-(\d{2})`), "$3/$2/$1");
    writeln(outStr); // "15/12/2025"
}
```

### 6. `replaceAll`

全部置換します。ログ整形とか「とにかく全部置き換え」の用途は大体これです。

**使用例**

```d global name=replaceAll
import std.regex;
import std.stdio;

void main() {
    auto s = "a1 b22 c333";
    auto outStr = replaceAll(s, regex(`\d+`), "X");
    writeln(outStr); // "aX bX cX"
}
```

### 7. `splitter`

正規表現を区切りとして分割します。
結果は遅延評価される **文字列** のレンジで得られます。（`Captures` ではない）
ちなみに結果を配列で返す `split` もあります。

**使用例**（雑なカンマ区切り）

```d global name=splitter
import std.regex;
import std.stdio;

void main() {
    auto s = "alice, bob ,carol";
    foreach (part; splitter(s, regex(`\s*,\s*`))) {
        writeln(part);
    }
}
```

### 8. `escaper`

文字列を渡し、正規表現の特殊文字をエスケープする関数です。
手入力される等の怪しい文字列を安全な正規表現として扱えるようにするものです。

ちなみに戻り値は `Escaper` という遅延評価する文字のレンジ型なので、`regex` に渡すなら `to!string(...)` で文字列に変換する必要があります。

**使用例**

```d global name=escaper
import std.regex;
import std.stdio;
import std.conv;

void main() {
    auto userInput = "file(name).txt";
    auto safePattern = to!string(escaper(userInput)); // "file\\(name\\)\\.txt"
    auto r = regex(safePattern);
    assert(matchFirst("file(name).txt", r));
}
```

# まとめ

というわけでサクッと `std.regex` をご紹介しました。

* 普段使いするなら `regex`
* コンパイル時に固めて最適化するなら `ctRegex`
* 抽出は `matchFirst / matchAll`
* 置換は `replaceFirst / replaceAll`
* 分割は `splitter`（必要なら `split`）
* エスケープは `escaper`

ちなみに汎用の `match` / `replace` もありますが、`Regex`のオプション次第で動きが変わるのでちょっとわかりづらいです。
最適化のためにも基本 `matchFirst` / `matchAll` 系を使う方が良いです。
