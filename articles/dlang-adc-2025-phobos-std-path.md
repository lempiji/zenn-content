---
title: "D言語標準ライブラリ紹介：std.path"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: true
---

[![dlang-adc-2025-phobos-std-path](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-path.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-path.yml)

## はじめに

こちらは、D言語 Advent Calendar 2025 1日目の記事となります。

https://qiita.com/advent-calendar/2025/dlang

個人的に良く使う標準ライブラリの紹介シリーズです。
こんな関数があるんだ～、というのをサクッと読んでもらえればと思います。

## `std.path` 紹介

https://dlang.org/phobos/std_path.html

`std.path` は **「パス文字列を壊さず安全に扱う」ためのモジュール** です。
また基本は **I/Oなしの文字列処理** であるため、「実在するか」「ファイルかディレクトリか」は判断しません。

この記事では、よく使う **7関数** を紹介します。

## 関数別ミニ解説

### 1. `buildPath`

複数のパス要素を引数で渡し、**適切な区切りで結合** して1つのパス文字列にします。
これは `"/"` や `"\"` を手で足さないための便利関数です。先頭や末尾に区切りあるとかないとかで分岐しなくて良くなります。
また途中の要素が **絶対パス**だと、そこから先が優先され、前半が無視されます（リセットされるイメージ）。

**使用例**

```d global name=buildPath
import std.path;
import std.stdio;

void main() {
    auto confPath = buildPath("etc", "myapp", "config.json");
    writeln(confPath); // 例: "etc/myapp/config.json"（OSに応じた区切り）
}
```


### 2. `buildNormalizedPath`

これは `buildPath` の単なる結合に加えて、`"."` や `".."`、余分な区切りなどを **正規化しながら** パスを作ります。
`buildPath` の代わりにこれ一本でも割といけます。

**使用例**

```d global name=buildNormalizedPath
import std.path;
import std.stdio;

void main() {
    auto p = buildNormalizedPath("logs", "app", "..", "app.log");
    writeln(p); // 例: "logs/app.log"
}
```


### 3. `dirName`

これはパスから **親ディレクトリ部分** を取り出します。
親が無い/表せない形のとき、相対パスでは `"."` が返ることがあります。たとえば `"foo.txt"` の親はカレント、という解釈になります。

**使用例**

```d global name=dirName
import std.path;
import std.stdio;

void main() {
    string target = "out/report/result.json";
    writeln(dirName(target)); // "out/report"
}
```


### 4. `baseName`
    
これはパスから **末尾要素（ファイル名/ディレクトリ名）** を取り出します。
名前が覚えづらいですが、単にパス区切りの最後のブロックを得る関数だと思って差し支えないです。

ちなみに末尾が区切りで終わるようなパスは環境で見え方が変わるので、基本は「末尾区切りを避け、ファイルっぽいパス」を入れるようにします。

**使用例**

```d global name=baseName
import std.path;
import std.stdio;

void main() {
    string p = "logs/archive/app.log";
    writeln(baseName(p)); // "app.log"
}
```


### 5. `globMatch`

`"*.log"` のような **globパターン** で、文字列（パス）をマッチ判定します。
イメージは正規表現のような「どこかに含まれる」ではなく、基本は **パス全体がパターンに合うか** の判定として捉えると事故りにくいと思います。

https://ja.wikipedia.org/wiki/%E3%82%B0%E3%83%AD%E3%83%96

**使用例**

```d global name=globMatch
import std.path;
import std.stdio;

void main() {
    string arg = "settings.local.json";
    if (!globMatch(arg, "*.json")) {
        writeln("json only");
        return;
    }
    writeln("ok");
}
```

### 6. `isValidPath`

与えられた文字列が **パスとして妥当な形か？** を判定します。
OS依存のルール（禁止文字など）を含むため、**自前の正規表現で頑張るより断然楽できる**、というタイプの関数です。

**使用例**

```d global name=isValidPath
import std.path;
import std.stdio;

void main() {
    string userInput = "../secret.txt";
    if (!isValidPath(userInput)) {
        writeln("invalid path");
        return;
    }
    writeln("looks well-formed");
}
```

### 7. `isValidFilename`

与えられた文字列が **ファイル名として妥当か？** を判定します。
「`dirName/baseName` で分解した `baseName`部分」をチェックしたい時のバリデータです。
これもOS依存（区切り文字や予約文字など）を含みます。

**使用例**

```d global name=isValidFilename
import std.path;
import std.stdio;

void main() {
    string name = "report_2025-12.txt";
    if (!isValidFilename(name)) {
        writeln("invalid filename");
        return;
    }
    writeln("ok");
}
```

# まとめ

というわけでサクッと `std.path` をご紹介しました。

`std.path` は **パス文字列を安全に扱うためのモジュール** です。
これで **結合・正規化・分解・判定検証** ができるようになったら、次は `std.file` 側で列挙や作成と組み合わせると、CLIツールの **雑務** が一気に片付くのでオススメです。
