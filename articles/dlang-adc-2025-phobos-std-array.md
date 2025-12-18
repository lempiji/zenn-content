---
title: "D言語標準ライブラリ紹介：std.array"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: false
---

D言語アドベントカレンダー 2025 の **7日目**の記事です。

https://qiita.com/advent-calendar/2025/dlang

個人的によく使う標準ライブラリを手短に紹介していくシリーズ、今回は配列まわりの `std.array` を取り上げます。

## `std.array` 紹介

https://dlang.org/phobos/std_array.html

`std.array` は、組み込み配列（動的配列）や連想配列を扱うための関数・型が集まったモジュールです。
配列を作る、変形する、要素を追加・削除する、連結・分割する、置換する…といった様々な操作をサポートしています。

今回は結構良く使うものを **7機能** ピックアップして紹介します。


## 関数別ミニ解説

### 1. `array`

`array` は、D言語で良く扱われる「レンジ」を「動的配列」にする関数です。よく使いますし、よく見かけます。

> レンジとは、雑に言えば「`foreach`で順番に読める要素が並んだもの」「`empty`・`front`・`popFront` で逐次走査できる要素列を表すオブジェクト」です。

レンジは遅延評価されるオブジェクトが多いので、**どこかで配列に確定させたい** ことがよくあります。たとえば何かの関数に渡したり、インデックスアクセスやランダムアクセスできるようにする、といった目的です。

**使用例**

```d global name=array_example
import std.array : array;
import std.algorithm.iteration : map;
import std.range : iota;

void main()
{
    // iota -> map は遅延Rangeなので、最後に array で確定させる
    int[] squares = iota(1, 6).map!(n => n * n).array;
    assert(squares == [1, 4, 9, 16, 25]);
}
```


### 2. `Appender` / `appender`

「配列にたくさんの要素を追加する」時に、**速く・無駄なく** 要素を追加するための仕組みです。
`Appender` は単純な配列の結合操作（`arr ~= data`）より効率的で、内部でメモリ確保やコピーの管理をうまくやってくれます。

また、 `appender` は `Appender` を作るための便利関数です。型だけ指定して作れたり、既存配列を渡して作ることもできます。

**使用例**

```d global name=appender_example
import std.array : appender;
import std.conv : to;

void main()
{
    auto w = appender!string;
    w.reserve(32); // 先に確保しておくと realloc が減る

    foreach (i; 0 .. 5)
    {
        w ~= i.to!string;
        w ~= '\n';
    }

    auto text = w[]; // 完成した string を得る
    assert(text[0 .. 4] == "0\n1\n");
}
```


### 3. `join`

レンジのレンジを**一気に連結して1つの配列**にする関数です。他の言語では `flatMap` や `flatten`、`SelectMany` のような名前で呼ばれるものです。
結合時に区切り文字も指定できます。区切りに "/" を指定してURLを組み立てる時に便利です。

なお、これは **「eager」と呼ばれる即時で配列を作る（確定させる）**タイプの関数です。
もし遅延評価するようなものが欲しい時は `std.algorithm` の `joiner` を使ってください。
あるいは `joiner` を使ってから `array` を呼んで配列に確定させるような場合、大抵この `join` が効率的です。

**使用例**

```d global name=join_example
import std.array : join;

void main()
{
    auto parts = ["usr", "local", "bin"];
    auto path = parts.join("/");

    assert(path == "usr/local/bin");
}
```


### 4. `split`

`range` と区切りを指定して、分割して、配列の配列にして返す関数です。これも即時評価で配列を確保するタイプの動きをします。

区切り文字には文字でも文字列でも渡すことができますが、**省略すると空白区切り** になります。また、連続する空白はマージされて空要素が出ないなどちょっと注意が必要です。


**使用例**

```d global name=split_example
import std.array : split;

void main()
{
    // 区切り指定
    assert("a,b,c".split(",") == ["a", "b", "c"]);
    // 空白マージ
    assert("Hello\t\tWorld\t!".split() == ["Hello", "World", "!"]);
}
```


### 5. `replace` / `replaceFirst` / `replaceLast`

配列要素を置換する関数です。元の配列はそのまま、置き換えた新しい配列を返します。
おおまかに以下の3種類があります。

* `replace`：全部置換
* `replaceFirst`：最初の1回だけ置換
* `replaceLast`：最後の1回だけ置換


**使用例**

```d global name=replace_example
import std.array : replace, replaceFirst, replaceLast;

void main()
{
    assert("a--b--c".replace("--", "/") == "a/b/c");
    assert("a--b--c".replaceFirst("--", "/") == "a/b--c");
    assert("a--b--c".replaceLast("--", "/") == "a--b/c");
}
```


### 6. `replaceInPlace`

これは配列の書き換え位置と書き換え内容を指定して、要素を直接置き換える関数です。入力に取った配列を **破壊的に書き換え** ます。似ている関数としては、Javascriptの `Array.splice` があります。

ちなみに注意点ですが、`string` は不変型なので使えません。書き換え可能な要素型を持つ動的配列なら普通に使えます。

**使用例**

```d global name=replaceInPlace_example
import std.array : replaceInPlace;

void main()
{
    int[] a = [1, 2, 3, 4, 5];

    // 2,3,4 を [9,9] に置き換える（短くなる）
    a.replaceInPlace(1, 4, [9, 9]);
    assert(a == [1, 9, 9, 5]);
}
```


### 7. `insertInPlace`

配列 `array` の指定位置に要素列を挿入します。挿入する要素列は通常のレンジ（input range）を指定できます。


**使用例**

```d global name=insertInPlace_example
import std.array : insertInPlace;

void main()
{
    int[] a = [1, 2, 3];
    a.insertInPlace(1, [9, 9]); // 1 の後ろに挿入
    assert(a == [1, 9, 9, 2, 3]);
}
```


## まとめ（使い分けの目安）

以上、`std.array` の中からよく使う7つの関数を紹介しました。
これら以外にも色々な関数がありますので、ぜひドキュメントを参照してみてください。

https://dlang.org/phobos/std_array.html
