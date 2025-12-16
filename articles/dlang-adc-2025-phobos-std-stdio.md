---
title: "D言語標準ライブラリ紹介：std.stdio"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: true
---

[![dlang-adc-2025-phobos-std-stdio](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-stdio.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-stdio.yml)

## はじめに

こちらは、D言語 Advent Calendar 2025 4日目の記事となります。

https://qiita.com/advent-calendar/2025/dlang

個人的によく使うPhobos（D言語標準ライブラリ）を短く紹介していくシリーズです。
今回は `"Hello, world!"` でもおなじみ `std.stdio` を題材にします。

## `std.stdio` 紹介

https://dlang.org/phobos/std_stdio.html

`std.stdio` は、C言語にもある `stdio`（`FILE*`）を土台にしつつ、Dからも扱いやすい形にまとめた標準I/Oモジュールです。
ユーザー入力を受け付ける、ファイルの書きこむ、といった基本的な入出力処理を提供します。

この記事では、個人的に良く使うところと「まず困らない」ための **7機能** を紹介します。

## 関数別ミニ解説

### 1. `write` / `writeln`

まず最初に目にすることも多いであろう `write` / `writeln` です。
`write` は **改行なし** の標準出力書き込み、`writeln` は `write(args, '\n')` と同等の **末尾改行あり** 標準出力書き込みです。引数なし `writeln()` は改行だけ出します。

また、`write` / `writeln` は **可変長引数** を取り、複数の値を連結して出力できます。
1つ1つを文字型に変換する必要もなく、値を放り込むだけで大体いい感じに出力してくれます。

**使用例**

```d global name=write_writeln
import std.stdio;

void main() {
    write("progress: ");
    writeln(42, "%"); // "progress: 42%"
}
```

**使用例** (デバッグモードのみ出力)

```d global name=debug_writeln
import std.stdio;

void main() {
    int x = 10;
    debug writeln("debug: x=", x); // debugキーワードでデバッグ時のみ出力
}
```


### 2. `writef` / `writefln`

C言語の `printf` 風 **フォーマット出力** を行う関数です。
`writef` は改行なし、`writefln` は `writef(..., '\n')` 相当で末尾改行あり、です。

フォーマット文字列をコンパイル時引数として渡すこともでき、フォーマットと引数の型が合っているかコンパイル時にチェックしてくれます。
大変強いので基本これで良いと思います。

**使用例**

```d global name=writef_writefln
import std.stdio;

void main() {
    int code = 404;
    string path = "/api/items";

    writefln!"error: code=%d path=%s"(code, path);
}
```

### 3. `readln`

`readln()` は標準入力から1行読む関数です。何か入力を受け付けるためにも使いますが、戻り値を無視して単に画面が流れないよう確認待ちに使ったりもします。
返る文字列は行末に改行(`\n`)を含む文字列となります。合わせて `std.string.chomp` で改行を取り除くことも多いです。

**使用例**

```d global name=readln disabled
import std.stdio;

void main() {
    string line;
    for (;;) {
        line = readln();
        if (line == "exit\n") {
            break;
        }
        write("you said: ", line);
    }
}
```


### 4. `File`

`std.stdio.File` はC言語の `FILE*` を安全に扱うための型です。
よく「使い終わったら `close`しなきゃ」とか考えますが、**参照カウントされていて、最後の `File` がスコープを抜けると自動でcloseされる** のであんまり気にしなくて良いです。
`File("name", "w")` のように、ファイル名とオープンモードを指定して開けます。`r`（読み取り）、`w`（書き込み）、`a`（追記）などCの `fopen` と同じモード指定が使えます。

**使用例**

```d global name=File
import std.stdio;

void main() {
    // ハンドルを扱うので大体スコープを区切って最小限にする
    {
        auto f = File("app.log", "w");
        f.writeln("hello log"); // writelnはFileのメソッドとしても使える
        f.writeln("bye");
    }
}
```


### 5. `stdin / stdout / stderr`

標準入力・標準出力・標準エラー出力を扱うオブジェクトです。それぞれ `File` として提供され、通常のファイルとほぼ同じ操作ができます。
3つ挙げていますが、本格的なツールでなければ大体 `stderr` を指定するためにあるような感じです。


**使用例**

```d global name=stdin_stdout_stderr
import std.stdio;

void main() {
    writeln("normal message");      // stdoutに出力
    stderr.writeln("warning: ..."); // stderrに出力
}
```


### 6. `byLine` / `byLineCopy`

`byLine()` は **`File` を受け取って「1行ずつ読むレンジ」を返す** という関数です。
UFCSを使うと `foreach (line; file.byLine()) { }` のように使えます。

注意点として、`byLine()` は読み取りに使う内部のバッファを使いまわして書き換わるので、必要なタイミングでコピーして取っておく（`auto l = line.idup;`）、という必要があります。
対して `byLineCopy()` は事前に各行をコピーして確保してくれます。パフォーマンスを気にしないなら `byLineCopy()` の方が楽です。
集計をするような場合は `byLine()`、行そのものを後で使うような場合は `byLineCopy()` を使うと良いです。

**使用例**

```d global name=byLine
import std.stdio;

void main() {
    {
        auto f = File("input.txt", "w");
        f.writeln("# this is a comment");
        f.writeln("data line 1");
        f.writeln("data line 2");
    }

    size_t count;
    foreach (line; File("input.txt").byLine()) {
        if (line.length == 0) continue;
        if (line[0] == '#') continue;
        count++;
    }
    writeln("data lines=", count);
}
```


### 7. `readf` / `readfln`

`readf` は標準入力からフォーマットに従って読み取り、何個の変数が埋まったかを返す関数です。
`readfln` は「1行読んでから」同様にパースする版です。
競技プログラミングなんかでは入力サイズとか受け付けるあたりで割と役立つと思います。

**使用例**

```d global name=readfln disabled
import std.stdio;

void main() {
    int a, b, c;
    write("Enter three integers(e.g. 10 20 30): ");
    auto count = readfln!"%d %d %d"(a, b, c);
    writeln("count=", count);
    writeln(a + b + c);
}
```


# まとめ

`std.stdio` はCLIツールを作ると非常によく使います。
競技プログラミングでも入力受けるあたりは定型処理だと思うので1回目を通すと良いかもしれません。
また、`File` や `byLine` のように **規模が多少大きい処理でも耐える道具** が最初から揃っていますので、本格的に性能重視で使いたい時にも役立つと思います。
ぜひ使ってみてください！