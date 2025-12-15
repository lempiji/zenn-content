---
title: "D言語標準ライブラリ紹介：std.conv"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: false
---

# D言語標準ライブラリ紹介：std.conv

## はじめに

D言語の標準ライブラリにおける最強格、 **使用頻度最高** と思われる `std.conv` の紹介です。
「型変換まわり」をまとめて面倒見てくれる便利モジュールなので、D言語使っていると大体インポートしているかもしれません。

今回は実務で出番が多いところ中心にサクッと紹介します。

## `std.conv` 紹介

https://dlang.org/phobos/std_conv.html

`std.conv` は、値を別の型へ変換したり、入力テキストをパースしたり…といった「変換」を扱うモジュールです。

この記事では、個人的によく使う 6機能 を紹介します。


## 関数別ミニ解説

### 1. `to`

いわゆる「安全な型変換」、これ1個覚えておけば何とかなる **実質最強テンプレート関数** です。
`to!string(x)` や `to!int(x)` のように **変換先の型を明示** すればOKな大変便利な関数です。
UFCSでメソッド呼び出し風にも使えます（`x.to!string()`）。

本当に様々な型に対応していますが、整数化で桁溢れが起きるなら例外が飛ぶなど、黙って壊れない安全設計なのが助かるポイントです。

**使用例**

```d global name=to
import std.conv;
import std.stdio;

void main() {
    string limitStr = "50";

    try {
        ubyte limit = to!ubyte(limitStr);
        writeln("limit=", limit);
    } catch (ConvOverflowException e) {
        writeln("limit is too large: ", e.msg);
    } catch (ConvException e) {
        writeln("invalid limit: ", e.msg);
    }
}
```


### 2. `text / wtext / dtext`

複数の値をまとめて **“いい感じに文字列として連結”** してくれる関数群です。
`std.stdio.writeln` みたいに `to!string` を個別に呼ぶ必要がないので、これ1個覚えておくと結構捗ります。ログ文字列・例外メッセージ・デバッグ表示の組み立てで鉄板、`std.format` の代わりに使うことも多いです。

戻り値の文字列型が `string / wstring / dstring` で分かれているので、用途に合わせて使い分けます。

**使用例**

```d global name=text
import std.conv;
import std.stdio;

void main() {
    int userId = 12345;
    double elapsedMs = 37.5;

    auto msg = text("userId=", userId, " elapsedMs=", elapsedMs);
    writeln(msg);

    // UTF-16(wchar) が欲しい場面（例: Windows API連携など）
    wstring wmsg = wtext("ユーザーID=", userId);
    writeln(wmsg);
}
```


### 3. `parse`

雑に文字列から値を作る関数です。
`"true"` → `true` や `"3.14"` → `3.14` みたいな **論理変換** が行えます。

また、**文字列の引数をrefで受け、読めるところまで読み進める（消費する）** という動作をするので、1行に複数の値が並ぶログ/TSVっぽいものを順に読む…みたいな用途に向いています。

これで日付が読めれば文句なしなんですがそこまでは出来ず、その用途では [dateparser](https://code.dlang.org/packages/dateparser) や [dateparser2](https://code.dlang.org/packages/dateparser2) というライブラリを使います。

**使用例**

```d global name=parse
import std.conv;
import std.stdio;
import std.string : stripLeft;

void main() {
    string line = "200  0.75  OK";
    auto s = line; // parse は 「引数を読み進める」ので別変数で操作

    int status = parse!int(s); // 200まで
    s = s.stripLeft; // 空白を飛ばす

    double ratio = parse!double(s); // 0.75まで
    s = s.stripLeft; // 空白を飛ばす

    string rest = s; // 残りはそのまま
    writeln(status);
    writeln(ratio);
    writeln(rest);
}
```


### 4. `roundTo`

「浮動小数点→整数」の変換をやりたいときの隠れ定番です。
`round` の名前通り四捨五入をするものですが、入力想定値が小さい時は「結果は `ubyte` でいいな」といった細かいニーズがまとめて拾えるのでポイント高いです。

**使用例**

```d global name=roundTo
import std.conv;
import std.stdio;

void main() {
    double timeoutMs = 2500;
    int timeoutSecs = roundTo!int(timeoutMs / 1000);
    writeln(timeoutSecs); // 3
}
```


### 5. `bitCast`

値の **ビット列をそのまま別型として見たい** ときに使えるテンプレート関数です。
以前なら `uint n = 0xDEADBEEF; float f = *cast(float*)&n;` みたいにポインタ経由でやっていたことが、型指定テンプレートで安全にできます。
バイナリ読み取り、浮動小数点のビット表現確認などで出番があります。

**使用例**

```d global name=bitCast
import std.conv;
import std.stdio;

void main() {
    uint raw = 0x3F800000; // IEEE754: 1.0f
    float f = raw.bitCast!float;
    writeln(f); // 1

    // 4バイトとして取り出す
    ubyte[4] bytes = raw.bitCast!(ubyte[4]);
    writeln(bytes);
}
```


### 6. `hexString`

16進数の並びを **コンパイル時に文字列（バイト列）へ変換**できるテンプレートです。空白も入れられるので、マジックナンバー類を **読みやすい形でソースに埋め込む** のに向きます。

**使用例**（ファイルヘッダ等の定数をわかりやすくする）

```d global name=hexString
import std.conv;
import std.stdio;

void main() {
    enum pngSig = hexString!"89 50 4E 47 0D 0A 1A 0A"; // PNGシグネチャ
    ubyte[] sigBytes = cast(ubyte[]) pngSig;
    writeln(sigBytes.length); // 8
}
```


## まとめ

`std.conv` は「とりあえず変換が必要になったらここから当たる」系のモジュールです。
実務だと、

* 値の型変換は `to`
* 論理変換は `parse`
* 文字列化は `text/wtext/dtext`
* 四捨五入などの整数化は `roundTo`
* バイナリ相手は `bitCast` / `hexString`

と覚えておくと色々捗ると思います。
