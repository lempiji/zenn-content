---
title: "D言語標準ライブラリ紹介：std.typecons"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: true
---

[![dlang-adc-2025-phobos-std-typecons](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-typecons.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-phobos-std-typecons.yml)

## はじめに

この記事は、Qiita D言語 Advent Calendar 2025 の5日目の記事です。

https://qiita.com/advent-calendar/2025/dlang

サクッと読める標準ライブラリ紹介シリーズ、今回は `std.typecons` を取り上げます。

## `std.typecons` 紹介

https://dlang.org/phobos/std_typecons.html

`std.typecons` は、既存の型を包んで加工することで「安全性」や「機能性」を向上させる「型」がまとまっているモジュールです。
名前は「type constructors（型を作るもの）」の略称となっています。

今回は標準ライブラリでよく目にしたり、実アプリで役立つ **7機能** を紹介していきます。


## 型別ミニ解説

### 1. `Tuple`

**複数の値をひとまとめにするレコード型**です。構造体を作るのが面倒なとき、関数の「複数戻り値」を返したいときに非常に便利です。
`tuple(...)` という関数で引数型に合わせた `Tuple` 型を簡単に構築できます。構築したタプルは添字アクセス（`t[0]`）もできますし、**名前付きフィールド**（`t.index`）にもできます。

**使用例**

```d global name=tuple_example
import std.typecons : tuple;
import std.stdio : writeln;

void main()
{
    // 単純なタプル
    auto t = tuple(10, "hello", 3.14);

    writeln(t[0]); // 10
    writeln(t[1]); // hello
    writeln(t[2]); // 3.14

    // 名前付きTuple
    auto r = tuple!("status", "elapsedMs", "msg")(200, 12.5, "OK");

    writeln(r.status);     // 200
    writeln(r.elapsedMs);  // 12.5
    writeln(r.msg);        // OK

    // 添字でもアクセス可能
    writeln(r[0]); // 200
}
```


### 2. `Nullable`

構造体など `null` にならない型を元にして、**「値がある / ない」を表現する** ための型です。
`Tuple / tuple` の関係と同様に構築用関数があり、`nullable` 関数で値から簡単に `Nullable` を作れます。

デフォルト構築で `null` 状態になり、`isNull` / `get` / `nullify` で操作します。

**使用例**

```d global name=nullable_example
import std.typecons : Nullable, nullable;
import std.stdio : writeln;
import std.conv : to;

Nullable!int parseTimeoutMs(string s)
{
    if (s.length == 0)
        return Nullable!int.init; // null

    return nullable(s.to!int); // 値あり
}

void main()
{
    Nullable!int t = Nullable!int.init; // 明示的に null で構築
    writeln(t.isNull);         // true
    writeln(t.get(3000));      // 既定値付きで取得（引数なしでnullだと例外）

    t = 1500;
    writeln(t.isNull);         // false
    writeln(t.get());          // 1500

    t.nullify();
    writeln(t.isNull);         // true
}
```


### 3. `SafeRefCounted`

既存の構造体から **参照カウントで共有所有する** ための型です。色々な変数から共有リソースにアクセスできるようにして、参照が無くなった時点で自動的に破棄されます。C++の `shared_ptr` に近いイメージですね。
これも `safeRefCounted` という関数で値から `SafeRefCounted` を初期化できます。

また、**コピーできない値をヒープへmoveして共有** といった用途にも使えます。
コピーやスコープアウトで参照カウントが増減するので、実装が気になる方は[ソース](https://github.com/dlang/phobos/blob/master/std/typecons.d)を覗いてみてください。（結構複雑ですが）

ちなみに以前は `RefCounted` という類似機能がありましたが、現在は非推奨、`SafeRefCounted` を使うよう案内されていますのでご注意ください。


**使用例**

```d global name=safe_ref_counted_example
import std.typecons : safeRefCounted;
import std.stdio : writeln;

struct Connection
{
    string host;
    this(string host) { this.host = host; }
    ~this() { writeln("close ", host); }
}

void main()
{
    // シンプルに初期値から共有参照を作る例
    auto sref = safeRefCounted(Connection("example.com"));
    auto sref2 = sref; // 参照ハンドルをコピー（参照カウント増加）

    writeln(sref.host);                  // payloadへアクセス
    writeln(sref.refCountedStore.refCount); // 2
}
```


### 4. `Unique`

既存の型をラップして、**所有権が1つだけ** であることを表明する型です。C++の `unique_ptr` に近いイメージです。
`Unique` 型のインスタンスはコピーできず、明示的な `move` セマンティクスでしか扱えません。

諸州兼の移動は基本的に `release` プロパティで行い、移動後の元のインスタンスは空になります。
`std.algorithm` や `core.lifetime` の `move` 関数とも連携できます。迷ったら `release` で十分です。

**使用例**

```d global name=unique_example
import std.typecons : Unique;
import std.stdio : writeln;

class Conn { void ping() { writeln("ping"); } }

void borrowExample(ref Unique!Conn u) // refありで借用（所有権は移らない）
{
    u.ping();
}
void consumeExample(Unique!Conn u) // refなしで消費（所有権を移動）
{
    u.ping();
}

void main()
{
    Unique!Conn u = new Conn; // 初期化は原則変数にnewして値を入れるこの形
    u.ping();

    borrowExample(u); // refで借用（所有権は移らない）
    assert(!u.isEmpty); // 借用後も元は空でない

    consumeExample(u.release); // 所有権を移動
    assert(u.isEmpty); // 移した後は空
}
```


### 5. `Flag`（`Yes` / `No`）

`Flag` は **“名前付きbool”** を作るための仕組みで、`Yes.xxx` / `No.xxx` の形で使える **読みやすいオプション引数？** を作るテンプレートです。
ぶっちゃけ日本語基準では全然読みやすくないと思うんですが、標準ライブラリには結構出てくるので覚えておくといつか役に立つ系です。

**使用例**

```d global name=flag_example
import std.typecons : Flag, Yes, No;
import std.stdio : writeln;

void download(string url, Flag!"verbose" verbose = No.verbose)
{
    if (verbose) writeln("GET ", url);
    // ...
}

void main()
{
    download("https://example.com");
    download("https://example.com", Yes.verbose);
}
```

### 6. `BitFlags`

C言語なんかでよく見る、**enumのビットOR組み合わせ**を、型安全に扱うための構造体です。
テンプレとも言える `enum` を定義してから `BitFlags!EnumType` として使います。
ビットORは `|` で追加し、`&` やプロパティアクセスで判定できます。

**使用例**

```d global name=bitflags_example
import std.typecons : BitFlags;
import std.stdio : writeln;

enum Perm
{
    Read  = 1 << 0, // よく見るビットシフト式の定義
    Write = 1 << 1,
    Exec  = 1 << 2,
}

void main()
{
    BitFlags!Perm p;             // ビットが立ってない（0扱い）

    p |= Perm.Read | Perm.Write; // ビットを立てる
    assert(p.Read);              // プロパティアクセスでビットが立ってるか判定
    assert(p & Perm.Write);      // & でも判定可能

    // Readだけ落とす（~はビット反転）
    p &= ~BitFlags!Perm(Perm.Read);
    assert(!p.Read && p.Write);
}
```


### 7. `Typedef`

`Typedef` は **既存の型を機能性はそのまま「別物の型」を作る**ための仕組みです。
`alias` と違って「同じ型扱い」されない、というのがポイントです。
IDや単位（ms/bytesなど）を取り違えたくない場面で便利です。

**使用例**

```d global name=typedef_example
import std.typecons : Typedef;
import std.stdio : writeln;

alias UserId  = Typedef!(int, int.init, "UserId");
alias OrderId = Typedef!(int, int.init, "OrderId");

void deleteUser(UserId id)
{
    writeln("delete user: ", id);
}

void main()
{
    UserId u = UserId(10);
    OrderId o = OrderId(10);

    deleteUser(u);
    // deleteUser(o); // コンパイルエラー（中身はintだが型としては違う）
}
```


# まとめ

`std.typecons` は既存の型を加工して「安全性」や「機能性」を向上させるための型群がまとまったモジュールです。
今回の7個は、特に **Tuple/Nullable/Flag/BitFlags** あたりが **便利** かつ **遭遇率高め** です。
実用的にはリソース管理の面で **SafeRefCounted** と **Unique** を使いこなしたいですね。
