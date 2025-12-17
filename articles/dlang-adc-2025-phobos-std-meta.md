---
title: "D言語標準ライブラリ紹介：std.meta"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: false
---

## はじめに

こちらは、D言語 Advent Calendar 2025 6日目の記事となります。

https://qiita.com/advent-calendar/2025/dlang

個人的によく使う標準ライブラリを手短に紹介していくシリーズです。

今回はテンプレートまわりで頻出の `std.meta` を題材に、「これだけ読めればPhobosに出てくるメタプログラミングは5割大丈夫」をやります。（本当？）


## `std.meta` とは

https://dlang.org/phobos/std_meta.html

`std.meta` はざっくり言えば「型のリスト」（テンプレート引数列 / alias sequence / template parameter sequence）を加工するライブラリです。

`int` や `string` 等からなる型のリストに対して、何かを判定したり、別の型に変換したり、といったことをコンパイル時にやります。

この「型リスト」の実体は、テンプレートの引数なんかで見る `T...` といった可変長テンプレート引数のことです。
これを加工していくのがD言語の醍醐味とも言え、メタプログラミングに欠かせない要素なので今回取り上げます。

今回紹介するのは厳選 **6機能** です。

## 機能別ミニ解説

### 1. `AliasSeq`

テンプレート引数列を「名前付きのリスト」にするものです。
`AliasSeq!(A, B, C)` で「A, B, C という並び」をリスト状にひとまとめにして扱えます。
ちなみに昔の名前は `TypeTuple` でした。

他の機能でも入力にこれを受け取るので、まずはここを押さえると後は簡単です。
ただし、**全部コンパイル時に行われる**のでそこだけ注意です。

**使用例**

```d name=aliasseq_example
import std.meta : AliasSeq;

alias Ts = AliasSeq!(int, double, string); //  型リストを作る

// 大体配列と同じ操作をサポート
static assert(Ts.length == 3);
static assert(is(Ts[0] == int));
static assert(is(Ts[1] == double));

// スライスも可能、他のAliasSeqと比較も可能
alias FirstTwo = Ts[0 .. 2];
static assert(is(FirstTwo == AliasSeq!(int, double)));
```


### 2. `staticMap`

`AliasSeq` を元に変換処理を各要素に適用して、同じ長さの型リストを作るテンプレートです。

用法は `staticMap!(F, Args...)` で、各要素に `F!(Args[i])` を適用して `AliasSeq!(...)` を返すものです。配列を変換する `map` 操作をそのままメタプログラミングに持ってきたものですね。
ちなみにこのテンプレート引数の並び方（`F, Args...`）は `std.meta` の他の機能でもよく出てきます。

**使用例**（型を全部ポインタ型にする）

```d name=staticmap_example
import std.meta : staticMap, AliasSeq;

// 入力の型リスト
alias Types = AliasSeq!(int, double, char);

// ポインタ型に変換するテンプレート
template Ptr(T) { alias Ptr = T*; }

alias Ptrs = staticMap!(Ptr, Types); // 各要素にPtrを適用
static assert(is(Ptrs == AliasSeq!(int*, double*, char*)));

alias Ptrs2 = staticMap!(Ptr, int, double, char); // AliasSeqでなくてもOK
static assert(is(Ptrs2 == AliasSeq!(int*, double*, char*)));
```


### 3. `Filter`

型リストを受け取り、条件に合う要素だけを残すテンプレートです。
用法は `Filter!(F, Args...)` で、各要素に `F!(Args[i])` を適用して `true` なら残し、`false` なら捨てるものです。
これも配列における `filter` 操作をメタプログラミングに持ってきたものですね。


**使用例**（整数型だけ残す）

```d name=filter_example
import std.meta   : Filter, AliasSeq;
import std.traits : isIntegral;

alias Ints = Filter!(isIntegral, int, double, long, string);
static assert(is(Ints == AliasSeq!(int, long)));
```


### 4. `allSatisfy` / `anySatisfy`

型リストの各要素が条件を満たすかどうかをまとめて判定するテンプレートです。
`Satisfy` は「充足する」という意味で、`allSatisfy` は「全部充足する」、`anySatisfy` は「いずれかが充足する」ことを表します。

要は、
* `allSatisfy!(F, T...)` は `F!(T[0]) && F!(T[1]) && ...` を意味します。
* `anySatisfy!(F, T...)` は `F!(T[0]) || F!(T[1]) || ...` を意味します。

`static assert(...)` の判定や、テンプレート条件でよく使います。

**使用例**

```d name=satisfy_example
import std.meta   : allSatisfy, anySatisfy;
import std.traits : isIntegral;

static assert( allSatisfy!(isIntegral, int, long));
static assert(!allSatisfy!(isIntegral, int, double));

static assert( anySatisfy!(isIntegral, string, int, double));
static assert(!anySatisfy!(isIntegral, string, double));
```


### 5. `ApplyRight` / `ApplyLeft`

テンプレートの「部分適用」をするためのテンプレートです。

`ApplyRight` / `ApplyLeft` は、テンプレートの一部引数を固定して「引数の少ないテンプレート」に変換します（部分適用）。
いわゆる「カリー化」なのですが、例を見た方が早いですね。

**使用例**（2引数の `isSame` を1引数にして `Filter` の条件として使う）

```d name=apply_example
import std.meta   : AliasSeq, Filter, ApplyRight, ApplyLeft;

template isSame(T1, T2) {
    enum isSame = is(T1 == T2);
}

// 判定対象の型リスト
alias Ts = AliasSeq!(int, double, long, int);

// isSame!(T1, T2) から isSame!(T, int) というTだけ受け取るテンプレートを作る
alias TgtInt1 = ApplyRight!(isSame, int);
alias OnlyInt1 = Filter!(TgtInt1, Ts);

// isSame!(T1, T2) から isSame!(int, U) というUだけ受け取るテンプレートを作る
alias TgtInt2 = ApplyLeft!(isSame, int);
alias OnlyInt2 = Filter!(TgtInt2, Ts);

static assert(is(OnlyInt1 == AliasSeq!(int, int)));
static assert(is(OnlyInt2 == AliasSeq!(int, int)));
```


### 6. `staticIndexOf`

型リストの中で、値が「何番目か」を取るためのテンプレートです。

`staticIndexOf!(x, Args...)` で、`x` が `Args` の中で何番目かを `enum` として返します。見つからない場合は `-1` になります。
メタプログラミングだと「ある型のメンバーフィールドを列挙して、その中で特定の型が何番目か」みたいな場面で使います。

**使用例**

```d name=staticindexof_example
import std.meta : AliasSeq, staticIndexOf;

alias Ts = AliasSeq!(int, double, string);

enum idxDouble = staticIndexOf!(double, Ts);
enum idxChar   = staticIndexOf!(char, Ts);

static assert(idxDouble == 1);
static assert(idxChar == -1);
```


## まとめ

`std.meta` はテンプレート引数に出てくるような型のリストを対象として、様々なメタプログラミングの手段を提供するモジュールです。
通常のプログラムと同様に `filter` や `map` の操作ができるので、独特なマクロシステムなど **メタプログラミング特有の思考** みたいなものは少なくて済みます。

次に `std.meta` が出てきたら、まずは `AliasSeq` を思い出して、 **「型の列を加工してるだけ」** と考えて読んでみてください。