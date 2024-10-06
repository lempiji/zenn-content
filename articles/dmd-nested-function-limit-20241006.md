---
title: "D言語のローカル関数は6346回ネストするとコンパイラが死ぬ"
emoji: "🪚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["D言語", "dlang", "コンパイラ", "検証"]
published: false
---

# はじめに

みなさん、ローカル関数は便利に使っていますか？

ローカル関数とは、ある関数の中にその関数の中でのみ使える関数を定義できる機能です。近年では様々な言語で使えるようになってきましたが、D言語でももちろん利用可能です。

ネストしている関数のイメージはこんな感じです。

```d
void test()
{
    void proc() {
        writeln("Hello, World!");
    }

    foreach (_; 0 .. 100) {
        proc();
    }
}
```

関数の実装が長くなると同じような処理が出てきたりしますし、そういった処理をその場でちょっとまとめたりするのに便利ですよね。
もちろんローカル関数が長くなれば、ローカル関数の中にローカル関数を定義して、さらにその中にローカル関数を定義する、といったようにネストすることが可能です。

さて、気になった方もいるかもしれません。

**「ローカル関数の中にローカル関数を定義できる」**

これはどこまでネストできるのでしょうか？
今回はそんなローカル関数にまつわるトリビアです。

# TL;DR

D言語でローカル関数をネストしすぎるとコンパイルエラーになるので注意しましょう。

# 実験

## ローカル関数をネストしたらエラーになる？

まずは簡単にローカル関数の例です。

今回の実験では、ざっとこんな感じでネストしているとします。
ネスト回数は番号を付けます。0から始まりますので、f1が出てきたら2回ネストしているとカウントすることに注意します。（1から始めればよかった）

```d
auto test() {
    auto f0() {
        auto f1() {
            return 0;
        }
        return f1();
    }
    return f0();
}

void main() {
    import std.stdio;
    writeln(test());
}
```

ちょっと（黒魔術を）使っていれば10回くらいはネストしていてもおかしくありませんね？
果たして、これが何回ネストしたらコンパイラの限界が訪れるのでしょうか、ちょっとわくわくします。

## 実験方針

簡単3ステップです。

1. ネストしたローカル関数を含んだソースコードのファイルを生成する
2. 生成したソースコードを実際にコンパイルして、エラーになるか確認する
3. 1-2を繰り返して、エラーになるネストレベルを調査する（二分探索で自動化）

早速やっていきましょう。

## ソースコード

ソースコードの生成は以下のようにします。これで作った文字列をファイルに保存すればOKです。

```d
string makeNestedFuncSource(size_t nestLevel)
{
    string source;
    source ~= "auto test() {\n";
    foreach (i; 0 .. nestLevel)
    {
        source ~= "auto f" ~ i.to!string ~ "() {\n";
    }
    source ~= "return 0;\n";
    foreach_reverse (i; 0 .. nestLevel)
    {
        source ~= "}\n";
        source ~= "return f" ~ i.to!string ~ "();\n";
    }
    source ~= "}\n";
    return source;
}
```

次に実際にコンパイルする関数を作ります。エラーが出た場合は `true` を返します。これは後でソートする都合のためです。

```d
bool testCrunshNestfunc(size_t nestLevel)
{
    write("nestLevel: ", nestLevel, " => ");
    auto source = makeNestedFuncSource(nestLevel);
    {
        auto f = File("nestedFunc.d", "w");
        f.writeln(source);
        f.writeln("void main() {");
        f.writeln("import std.stdio;");
        f.writeln("writeln(test());");
        f.writeln("}");
    }
    scope (exit) std.file.remove("nestedFunc.d");

    try
    {
        auto p = spawnShell("dmd -run nestedFunc.d");
        auto statusCode = p.wait();
        writeln(statusCode == 0 ? "OK" : "NG");
        return statusCode != 0;
    }
    catch (Exception e)
    {
        write("NG");
        return true;
    }
}
```

次に、ネストレベルを調査するための二分探索を用意します。
これは Ruby の `Array#bsearch` で `find-minimum` モードの動作に相当するものです。
要は、昇順に並んだデータのうち、大きい方の最小値を探すモードです。これを今回はエラーになるネストレベルを探すために使います。

```d
// 二分探索関数の定義
auto bsearch(alias pred, Range)(auto ref Range range)
    if (isRandomAccessRange!Range && hasLength!Range && !isInfinite!Range)
{
    alias predicate = unaryFun!pred;

    static assert(is(typeof(predicate(range[0])) : bool), "Predicate must evaluate to a boolean.");

    size_t low = 0;
    size_t high = range.length;
    bool found = false;

    while (low < high)
    {
        size_t mid = low + (high - low) / 2;

        if (predicate(range[mid]))
        {
            found = true;
            high = mid;
        }
        else
        {
            low = mid + 1;
        }
    }

    return (found && low < range.length) ? low : -1; // 見つからなかった場合は -1 を返す
}

unittest
{
    int[] arr = [1, 5, 8, 12, 20, 33, 42, 55, 68, 72, 88];
    auto index = bsearch!"a > 20"(arr);
    assert (index == 5);
}
```

最後に、これらをmain関数でまとめて実行します。
とりあえずネストなしから10000まで調査するようにしておきます。

```d
import common;
import std;

void main()
{
    auto result = iota(0, 10000).bsearch!testCrunshNestfunc;
    writeln(result);
}
```

## 実行


これを以下のコマンドで実行します。

```
rdmd crush_nestfunc.d
```

なお、ここでrdmdを使ってるのはめっちゃ便利だからです。

- 参考: [D言語（rdmd）はスクリプト用途にめっちゃ便利](https://qiita.com/lempiji/items/0730a6441f4f23a57119)

### dmd

実行環境を確認します。

```
dmd --version

DMD64 D Compiler v2.109.1
Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved written by Walter Bright
```

実行結果は以下の通りです。

```
nestLevel: 5000 => OK
nestLevel: 7500 => NG
nestLevel: 6250 => OK
nestLevel: 6875 => NG
nestLevel: 6563 => NG
nestLevel: 6407 => NG
nestLevel: 6329 => NG
nestLevel: 6290 => OK
nestLevel: 6310 => NG
nestLevel: 6300 => OK
nestLevel: 6305 => OK
nestLevel: 6308 => NG
nestLevel: 6307 => NG
nestLevel: 6306 => OK
6307
```

ネストレベルが6306であれば問題なし、6307になるとエラーになりました。
つまり+1して6308回ネストするとエラーになることがわかりました。

### ldc2

続いてLLVMバックエンドのLDC2でも試してみます。

まずはバージョン確認から。

```
ldc2 --version
LDC - the LLVM D compiler (1.34.0):
  based on DMD v2.104.2 and LLVM 16.0.6
  built with LDC - the LLVM D compiler (1.34.0)
  Default target: x86_64-pc-windows-msvc
  Host CPU: skylake
  http://dlang.org - http://wiki.dlang.org/LDC

以下省略
```
（ちょっと古い）

コンパイルするコマンドをちょっと変えておきます。

```
auto p = spawnShell("ldc2 -run nestedFunc.d");
```

さて、まずは10000回でエラーになることを確認しておきます。

```
nestLevel: 10000 => Exception Code: 0xC00000FD
NG
```

無事死にました。`0xC00000FD` はスタックオーバーフローのエラーコードです。

他にもいくつか試してみます。

```
nestLevel: 6307 => OK
nestLevel: 6308 => OK
nestLevel: 6309 => OK
nestLevel: 7000 => Exception Code: 0xC00000FD
NG
```

おや、ldc2はdmdよりも多くのネストが可能そうです。

コンパイルできる場合はとても時間がかかるので、ちょっと範囲を絞って実行してみましょう。（あとログが消えてしまったので中途半端な記録ですが…）

```
nestLevel: 6475 => Exception Code: 0xC00000FD
NG
nestLevel: 6387 => Exception Code: 0xC00000FD
NG
nestLevel: 6343 => OK
nestLevel: 6365 => Exception Code: 0xC00000FD
NG
nestLevel: 6354 => Exception Code: 0xC00000FD
NG
nestLevel: 6349 => Exception Code: 0xC00000FD
NG
nestLevel: 6346 => Exception Code: 0xC00000FD
NG
nestLevel: 6345 => Exception Code: 0xC00000FD
NG
nestLevel: 6344 => OK
6345
```

ネストレベルが6344であれば問題なし、6345になるとエラーになりました。
つまり+1して6346回ネストするとエラーになることがわかりました。

### 結果と考察

dmdのバージョン2.109.1では、ローカル関数を **6308回** ネストするとコンパイルエラーになるようです。
LLVMバックエンドのLDC2 v1.34.0では、やや多い **6346回** ネストするとコンパイルエラーになるようです。

恐らくどちらもネストしている関数の解析でスタックオーバーフローしていると思いますが、原因調査はまたの機会に。

また、数字が違うのはコンパイラフロントエンドのバージョン違いが原因かもしれません。これも追試した方が良さそうです。

## 振り返り

DMDの探索に思ったよりもずいぶん時間がかかりました。

特に成功時と失敗時でコンパイル時間が圧倒的に違い、成功すると大変遅く、失敗するときはすぐエラー、という傾向がありました。
コンパイルが通る場合は1回あたり数分かかるので、dmdの場合今回は6回成功、ざっくり30分以上かかりました。（放置ですが）

検索する範囲をもっと狭めたり、何か違う基準で確認ができると良かったかもしれません。
たとえば、失敗する分には速いので、失敗する側を多めに探索するという方法も考えられます。極論、後ろから順番に辿る手もありえます。

しかしそこは我らがD言語、既に `SortedRange` というものがあり、ソート済みを条件に効率的に範囲を絞れる `upperBound` という関数があります。

この `upperBound` には `SearchPolicy` というテンプレート引数を渡すことができ、その中には `linear` や `binary` に加え、少し珍しい `gallop` や `trot` およびそれらのBackward版があります。
これらは指数的または積算的に探索のステップ幅を拡げて境界値を探し、その後に二分探索を行うというものです。

詳しくは以下を参照してください。
https://dlang.org/library/std/range/search_policy.html


要するに `ballopBackword` あたりを使ってやればよかったんじゃないの？という振り返りでした。やってないんですが。
`bsearch` のようにちょっと一般化すれば便利なものができると思うので、興味がある方はぜひ調べて試してみてください。

# まとめ

ローカル関数をネストしすぎないように気をつけましょう。
1000回くらいだったらコンパイル時間もほぼ気にならないと思うので、それくらいに留めておくと良いと思います。

## 謝辞・参考

この記事は以下の記事を参考にしながら書かせていただきました。感謝！

- [clang++に30740次元の配列を食わせると死ぬ](https://zenn.dev/kaityo256/articles/extremely_high_dimensional_array)

以上！