---
title: "D言語の新キーワード __rvalue 解説（dmd 2.111.0）"
emoji: "🚀"
type: "tech"
topics: ["dlang", "compiler", "performance"]
published: false
---

## はじめに

dmd 2.111.0 で **新キーワード `__rvalue`** が追加されました。これは `__rvalue(expr)` という **primary expression** として導入され、**本来 lvalue な式も rvalue として扱わせる** ためのものです。

この機能の狙いは「`ref` overload の選択」「move ctor / move assignment の有効化」「ライブラリ primitive（`move` / `forward`）実装の足場」を **言語機能として提供する** ことにあります。

本記事は、**コピー／ムーブ／破棄順序を理解・コントロールしたいプログラマーの方々向け** に、仕様と実験結果の両方から「どこまでコントロールしうるか」を整理して、実務的なガイドラインの基礎をまとめます。

前提となるコピーについては別記事「D言語におけるコピーを少しだけ理解する」にまとめていますので以下を参照ください。

https://zenn.dev/lempiji/articles/dlang-adc-2025-copy-behavior

ちなみに以下 `lvalue/rvalue` はC++と同じ概念となるため説明は省きます。
また、関数引数の `ref` 有無については、`ref` ありの参照渡しの方を **by-ref**、`ref` なしの値渡しに見える方を **by-value** と呼ぶことにします。

## tl;dr

* `__rvalue` は **「式を rvalue として扱わせる」** ための新キーワード（dmd 2.111.0〜）。
  * 「ムーブを実行する」機能ではなく、**オーバーロード解決・コピー/ムーブ経路の選択に影響するもの**。

* 用法は2つ（どちらも「呼び出し式の value category を変える」）
  1. `__rvalue(expr)`：`expr` の評価結果は同じだが **rvalue 扱い**にする（by-ref から by-value へ寄せる、move ctor / rvalue 向け `opAssign` を選ばせる、等）。
  2. `ref` 戻り値関数への `__rvalue` 属性：`ref` で返していても、**呼び出し側の式を rvalue 扱い**にする（＝`ref` 変数へ束縛できない、`ref` overload に吸われない）。`move/forward` の足場として想定されている。

* 目に見える影響（要点）

  * `foo(ref T)` と `foo(T)` があるとき
    * `foo(x)`（lvalue）→ `ref` 側が優先
    * `foo(T())` / `foo(__rvalue(x))`（rvalue扱い）→ value 側が優先
  * `opAssign(ref T)` と rvalue を受ける `opAssign`（例：`opAssign(scope T)`）があるとき
    * `x = y` → `ref` 側
    * `x = T()` / `x = __rvalue(y)` → rvalue 側が選ばれる

* 重要な注意点

  * `consumeByValue(T t)` のような **by-value 受け取りでも、実装上「実体コピー／move ctor 呼び出し」が保証されない**。
    * dmd 2.111.0（Windows / `-run` 相当）では、`consumeByValue(__rvalue(a))` が **引数 `t` と元の `a` が同一ストレージを指すように見える（alias に見える）** ケースがあった。（本来期待される rvalue を使った最適化の恩恵とも言えるが、debugビルドでも有効）
  * by-value の経路では、**「呼び出し後に source を使ってよいか」** に注意する必要がある。
    * `move(x)` や `__rvalue(x)` を渡した時点で **x は 「消費された（moved-from になり得る）」 とみなして扱う**。
  * moved-from でも **後でデストラクタが走る**（仕様・ChangeLog ともに明示）ので、ムーブ実装は **moved-from を benign（破棄しても安全）な状態に戻す** のが必須。
    * `move` を使う限りは `T.init` になると想定して、その状態での安全性を必ず保つ。

* forwarding の結論

  * `auto ref` で受けた引数は、関数内では **名前付き変数＝lvalue に見える** ため、そのまま別関数へ渡すと `ref` overload に吸われやすい。これは forward 問題の定番として注意が必要。
  * value category を保って転送したいなら、原則 `core.lifetime.forward`（書き方は `forward!args`）を使う。
  * 呼び元で「所有権を移す」という意図なら `core.lifetime.move` を使う（`__rvalue` の直叩きは後始末が抜けやすい）。


## 検証環境

* OS: Windows 11
* コンパイラ: `dmd 2.111.0`
* 実行: `dmd -run *.d` （最適化 `-release` なし）


## `__rvalue` とは何か？

言語仕様としては新しく追加された「キーワード」であり、仕様として2つの用法があります。

### 1. `__rvalue(expression)`

`__rvalue(e)` という式としての用法があります。
式の **評価結果は `e` と同じ** ですが、**オーバーロードの解決では rvalue として扱う** ようになります。

[ChangeLog](https://dlang.org/changelog/2.111.0.html#dmd.rvalue) でも例として、`foo(S)` / `foo(ref S)` のうち **`__rvalue(s)` で by-value overload を選べる** ことが示されています。

> 重要: `__rvalue` 自体が「ムーブ動作（資源移動）を実行する」わけではありません。
> **「rvalue として扱う」** ことで、結果として move ctor / move assignment が **選ばれうる** だけです。

### 2. `__rvalue` 関数属性（`ref` 戻り値を rvalue 扱いにする）

`ref` で返す関数に `__rvalue` 属性を付けると、**呼び出し側でその `ref` 結果を rvalue 扱い** にできます。

[ChangeLog](https://dlang.org/changelog/2.111.0.html#dmd.rvalue) では `move` の実装例として明示されています。

この機能があることで、

* 「実体は参照で返す（コピーしない）」
* しかし「呼び出し側のオーバーロード選択上は rvalue にしたい（値渡しの実装を選びたい）」

という **やや矛盾した要件** を、言語的に表現できます。

実際に書いて動かしてみましょう。

## 実験1： `__rvalue(expr)` の影響

まずは簡単なところから実験していきます。
関数のオーバーロードで by-ref 引数と by-value 引数がある場合に、`__rvalue` がどう影響するかを見てみます。

### 期待する動作

仕様を簡潔に表すと以下のはずです。確かめてみましょう。

* lvalue を渡す → `foo(ref T)` が優先
* rvalue を渡す（temporary など）→ `foo(T)` が優先
* `__rvalue(lvalue)` を渡す → `foo(T)` を優先（**重要**）

### ソース

```d global name=exp01_param_overload
// exp01_param_overload.d
import std.stdio;

struct T { int v; }

void foo(T)(T x)     { writeln("foo(T)    (by value)"); }
void foo(T)(ref T x) { writeln("foo(ref T)"); }

void main()
{
    writeln("=== Parameter overload selection ===");
    T x = T(1);

    foo(x);               // 期待: foo(ref T)
    foo(__rvalue(x));     // 期待: foo(T)
    foo(T(2));            // 期待: foo(T)
}
```

### 実測

仕様通り、期待通りです。
`__rvalue` で by-value のほうを上手く選択できています。

```
=== Parameter overload selection ===
foo(ref T)
foo(T)    (by value)
foo(T)    (by value)
```

**結論:** `__rvalue` はまず **オーバーロード選択のスイッチ** として機能する


## 実験2： `ref` 戻り値関数に `__rvalue` 属性を付ける影響

次の実験です。
用法の2番目、`ref` 戻り値関数に `__rvalue` 属性を付けた場合の挙動を確認します。

### やりたいこと

1. `produceRef()` は `ref` を返す `__rvalue` なしの実装
2. `produceRefRvalue()` は `ref` を返しつつ `__rvalue` 属性を付けて **呼び出し側では rvalue 扱い** にしたい。

### ソース

```d global name=exp02_ref_return
// exp02_ref_return.d
import std.stdio;

struct T { int v; }

ref T produceRef()
{
    static T stored = T(10);
    writeln("produceRef()");
    return stored;
}

ref T produceRefRvalue() __rvalue
{
    static T stored = T(20);
    writeln("produceRefRvalue() __rvalue");
    return stored;
}

void foo(T)(T x)     { writeln("foo(T)"); }
void foo(T)(ref T x) { writeln("foo(ref T)"); }

void main()
{
    writeln("=== ref return vs __rvalue ref return ===");
    foo(produceRef());        // 期待: foo(ref T)
    foo(produceRefRvalue());  // 期待: foo(T)

    enum canBindRef       = __traits(compiles, { ref T a = produceRef(); });
    enum canBindRvalueRef = __traits(compiles, { ref T a = produceRefRvalue(); });

    writeln("bind ref <- produceRef(): ", canBindRef);             // 期待: true
    writeln("bind ref <- produceRefRvalue(): ", canBindRvalueRef); // 期待: false
}
```

### 実測

```
=== ref return vs __rvalue ref return ===
produceRef()
foo(ref T)
produceRefRvalue() __rvalue
foo(T)
bind ref <- produceRef(): true
bind ref <- produceRefRvalue(): false
```

こちらも期待通りでした。

しかしcanBindの確認から、「`ref` 戻り値を `__rvalue` 属性付きで返すと、`ref` 変数に束縛できなくなる」という動作もわかりました。
ここまで来ると、ほとんど `ref` がないのと変わらないような扱いに見えてきます。


## 仕様確認： ムーブコンストラクタとは何か、`__rvalue` とどう関係するか

次の実験の前に、**D言語における move constructor（ムーブコンストラクタ、以下 move ctor）の仕様** を整理します。
Dの構造体におけるmove ctorは、「特別扱いされるコンストラクタ」として仕様に定義があります。

https://dlang.org/spec/struct.html?utm_source=chatgpt.com#struct-move-constructor

ポイントだけ抜き出すと以下の通りです。

* コンストラクタが move ctor と認識される条件（抜粋）
  * 第一引数が `ref` でない
  * 第一引数の型が `typeof(this)` と同型（修飾は可）

* **move ctor の第一引数は rvalue しか受けない**
  * lvalue を渡したいなら `__rvalue(expr)` で強制できる（注：このために `__rvalue` がある）

* move ctor を定義したら **copy ctor も定義せよ**

* move ctor と **postblit を同居させるな**（注意として明示）

さらに仕様は「暗黙のムーブコンストラクタ呼び出しが行われるケース」として以下2つを挙げています。

1. `A b = __rvalue(a);`
2. `fun(__rvalue(a));`（by-value 引数）

ここからまた実験して確認していきます。

## 実験3： 「良い move / 悪い move」とデストラクタの確認

move ctorの挙動で重要なのは、**ムーブ後に moved-from （ムーブ済み）のオブジェクトがどうなるか** です。

D言語仕様では **「moved-from オブジェクトもデストラクタは呼ばれる」** と明示されています。
つまりムーブされた側は最低限デストラクタが呼べる程度に安全な状態に戻す必要があります。
この戻した状態を **benign** （= 良性・無害）と呼びます。

そこでムーブ時に状態を元に戻す構造体と戻さない構造体を両方用意して、実際にムーブしたオブジェクトの状態やデストラクタの動作を確認してみます。

### ソース

```d global name=exp03_move_dtor
// exp03_move_good_bad.d
import std.conv : to;
import std.stdio;

// 「ユニーク資源」のつもりで、idを解放するログだけ出す
struct UniqueGood
{
    int id;
    bool owns;

    this(int id) { this.id = id; owns = true;  writeln("UniqueGood.ctor id=", id); }

    // move ctor
    this(return scope UniqueGood rhs)
    {
        writeln("UniqueGood.move from id=", rhs.id);
        id = rhs.id;
        owns = rhs.owns;

        // benign化（重要）
        rhs.id = 0;
        rhs.owns = false;
    }

    // copy ctor（呼ばれないが、仕様に反しないよう念のため）
    this(ref const UniqueGood rhs) { writeln("UniqueGood.copy from id=", rhs.id); id = rhs.id; owns = rhs.owns; }

    ~this()
    {
        if (owns) writeln("UniqueGood.dtor release id=", id);
        else      writeln("UniqueGood.dtor noop (moved-from)");
    }
}

// 
struct UniqueBad
{
    int id;
    bool owns;

    this(int id) { this.id = id; owns = true; writeln("UniqueBad.ctor id=", id); }

    // move ctor（悪い例：benign化しない）
    this(return scope UniqueBad rhs)
    {
        writeln("UniqueBad.move from id=", rhs.id);
        id = rhs.id;
        owns = rhs.owns;

        // rvalueとして渡されたrhsを安全な状態に変更しない（←これが抜けていると事故のもと）
    }

    ~this()
    {
        if (owns) writeln("UniqueBad.dtor release id=", id, "  <-- DOUBLE RELEASE RISK");
        else      writeln("UniqueBad.dtor noop");
    }
}

void main()
{
    writeln("=== Good move (benign) ===");
    {
        UniqueGood a = UniqueGood(1);
        UniqueGood b = __rvalue(a);
        // ここで a は moved-from になっている
    }

    writeln("\n=== Bad move (not benign) ===");
    {
        UniqueBad a = UniqueBad(2);
        UniqueBad b = __rvalue(a);
        // a/b 両方が owns=true のまま → ログ上「二重解放相当」
    }
}
```

### 実測

```
=== Good move (benign) ===
UniqueGood.ctor id=1
UniqueGood.move from id=1
UniqueGood.dtor noop (moved-from)
UniqueGood.dtor release id=1
UniqueGood.dtor noop (moved-from)

=== Bad move (not benign) ===
UniqueBad.ctor id=2
UniqueBad.dtor release id=2  <-- DOUBLE RELEASE RISK
UniqueBad.dtor release id=2  <-- DOUBLE RELEASE RISK
```

ここで確認しておくべき点は2つです。

### (A) 「moved-from でもデストラクタは呼ばれる」は仕様

[ChangeLog](https://dlang.org/changelog/2.111.0.html?utm_source=chatgpt.com#dmd.rvalue) にも **"moved object will still be destructed"** と明示されており、ムーブ後にデストラクタが走る前提で実装せよ、と言っています。
上記実験でも、`UniqueGood` 側は dtor の "release" が1度だけ出ており、適切に1度だけ解放されています。

### (B) 「良い move」は「moved-from を benign にする」

先ほどの `UniqueGood` はムーブコンストラクタ内で rvalue の `id` と `owns` を初期化してデストラクタが走っても安全にしています。
逆に `UniqueBad` のように何もせず、moved-from 側が所有権を持っていると誤認したままになると、同一資源を2回解放する危険があります。

## 実験4： by-value 引数に `__rvalue(lvalue)` を渡したとき

ムーブコンストラクタの仕様を確認したので、次は **「by-value 引数に `__rvalue(lvalue)` を渡したとき」** の挙動を確認します。

気になるのは、関数引数でもムーブコンストラクタが呼ばれるかどうかです。
ある意味 rvalue の存在意義として、ここは `__rvalue` の危険性と効率性が **いちばんハッキリ出るポイント** です。

結論から言うと、**`__rvalue(a)` を by-value 引数に渡す時は「move ctor が呼ばれる」とは限りません**。
代わりに **by-value 引数が呼び出し元と同一メモリ位置を参照（alias）** することで受け渡しが行われ、処理が効率化されます。

順番に確認していきます。

### ソース1

まずは素直に move ctor が呼ばれるかどうかを確認します。

```d global name=exp04_by_value_timing
// exp04_by_value_timing.d
import std.conv : to;
import std.stdio;

struct Tr
{
    int id;
    bool owns;

    this(int id) { this.id = id; owns = true; writeln("Tr.ctor id=", id); }

    this(return scope Tr rhs)
    {
        writeln("Tr.move from id=", rhs.id);
        id = rhs.id;
        owns = rhs.owns;
        rhs.id = -1;
        rhs.owns = false;
    }

    this(ref const Tr rhs)
    {
        writeln("Tr.copy from id=", rhs.id);
        id = rhs.id;
        owns = rhs.owns; // 本当ならもう少し工夫が必要
    }

    ~this()
    {
        if (owns) writeln("Tr.dtor release id=", id);
        else      writeln("Tr.dtor noop (moved-from) id=", id);
    }
}

void consumeByValue(Tr t)
{
    writeln("consumeByValue got id=", t.id);
}

void main()
{
    writeln("=== by-value with lvalue (copy) ===");
    {
        Tr a = Tr(10);
        consumeByValue(a);
        writeln("after call, a.id=", a.id, " owns=", a.owns);
    }

    writeln("\n=== by-value with __rvalue(lvalue) (move) ===");
    {
        Tr a = Tr(20);
        consumeByValue(__rvalue(a));
        writeln("after call, a.id=", a.id, " owns=", a.owns, "  (moved-from expected)");
    }
}
```

### 実測1

結果は以下の通りでした。

```
=== by-value with lvalue (copy) ===
Tr.ctor id=10
Tr.copy from id=10
consumeByValue got id=10
Tr.dtor release id=10
after call, a.id=10 owns=true
Tr.dtor release id=10

=== by-value with __rvalue(lvalue) (move) ===
Tr.ctor id=20
consumeByValue got id=20
Tr.dtor release id=20
after call, a.id=20 owns=true  (moved-from expected)
Tr.dtor release id=20
```

それぞれ確認してみると以下がわかります。

* `consumeByValue(a)` では copy ctor が呼び出され、直感通り「別インスタンス」が `consumeByValue` 側に作られている。
* `consumeByValue(__rvalue(a))` では **move ctor が呼ばれず**、それでも `consumeByValue` の引数 `t` のデストラクタが走っている。

この時点だと「move ctor が省略された？」くらいの解釈ですが、もう少し詳しく見ると何が起きているかわかります。

### ソース2

`main` のスコープで、呼び出し元 `a` と呼び出し先の引数 `t` のアドレスを出力してみます。

```d global name=exp04b_alias_check
// exp04b_alias_check.d
import std.stdio;

struct Tr
{
    int id;
    this(int id) { this.id = id; writeln("Tr.ctor id=", id); }

    // move ctor
    this(return scope Tr rhs)
    {
        writeln("Tr.move from id=", rhs.id);
        id = rhs.id;
        rhs.id = -1;
    }

    // copy ctor
    this(ref return scope const Tr rhs)
    {
        writeln("Tr.copy from id=", rhs.id);
        id = rhs.id;
    }

    ~this() { writeln("Tr.dtor id=", id); }
}

void consumeByValue(Tr t)
{
    writeln("callee: &t = ", cast(void*)&t, "  t.id=", t.id);
    t.id += 1000;
    writeln("callee: t.id++ => ", t.id);
}

void main()
{
    Tr a = Tr(20);
    writeln("caller: &a = ", cast(void*)&a, "  a.id=", a.id);

    consumeByValue(__rvalue(a));

    writeln("after:  a.id=", a.id);
}
```

### 実測2

結果は以下の通りです。アドレスが全部同じですね。

```
caller: &a = 91E52FF300  a.id=20
callee: &t = 91E52FF300  t.id=20
callee: t.id++ => 1020
Tr.dtor id=1020
after:  a.id=1020
Tr.dtor id=1020
```

ここで着目したいポイントは3つです。

1. **`&a` と `&t` が同一**
   by-value のはずの `Tr t` が、呼び出し元 `a` と同じアドレスを指しています。
   つまりこのケースでは、dmd が `consumeByValue(Tr)` を **実装上 “hidden ref（参照渡し相当）”** として扱っていると解釈できます。

2. callee で `t.id` を変えると **caller の `a.id` も変わる**
   `after: a.id=1020` になっているのは、代入が呼び出し元に影響し、実質参照として扱われていることを示しています。

3. デストラクタが **2回** 走っている
   callee の終了で `t` のデストラクタが走り、さらに呼び出し側(main)のスコープ終端で `a` のデストラクタが走っています。
   しかし `t` と `a` は同一実体なので、結果として **同一ストレージに対してデストラクタが2回** 呼ばれています。


### ここから言えること

まずこの結果は、「by-value 引数に `__rvalue` を渡したら move ctor が走る」という話が否定されています。

* `__rvalue` は「式を rvalue 扱いにするだけ」で、**ムーブコンストラクタの呼び出しを保証しない**。
* ある関数引数が by-value 引数であっても、実装上「実体コピー」ではなく「参照渡し相当（alias）」に化けることがある。
* `consumeByValue(__rvalue(a))` は、この alias 実装と組み合わさることで、結果として **関数内部で呼び出し側のデストラクタを呼ぶ**。

つまり何も対策をしないと二重破棄のリスクがあります。
`malloc` など低レベル操作を伴っていれば、メモリの double free バグに直結してしまいます。

そのような危険性を下げるために、守るべきポイントをまとめます。

* **`__rvalue(x)` を渡した時点で、`x` は「死んだもの」として扱う**
    * 関数に渡すとデストラクタが呼ばれるため、以降 `x` は使えない（rvalueの基本ルール）
* ムーブ可能な型は、**適切なタイミングで moved-from のデストラクタが走っても壊れない（benign = 良性・無害） 状態に戻す**
    * 典型: `T.init` の状態で安全にしておく（後述の `move/forward` に関連）
    * 実験6/7でこの部分を確認します

## 実験5： `opAssign` overload と `__rvalue`

危険性と効率について実験したので、次は **ムーブ代入（move assignment）** の挙動を確認します。
D言語仕様ではムーブ代入の特別扱いは明示されていませんが、**`opAssign` overload の選択に `__rvalue` が影響するか** を見てみます。

### 期待する動作

* lvalue 代入 → `opAssign(ref T)` が選ばれる
* rvalue 代入（temporary など）→ `opAssign(T)` が選ばれる
* `__rvalue(lvalue)` 代入 → `opAssign(T)` が選ばれる

### ソース

```d global name=exp05_opassign_overload
// exp05_opassign_overload.d
import std.stdio;

struct A
{
    int id;

    this(int id) { this.id = id; writeln("A.ctor id=", id); }

    // lvalue 代入
    ref A opAssign(ref A rhs)
    {
        writeln("opAssign(ref A)   from id=", rhs.id);
        id = rhs.id;
        return this;
    }

    // rvalue 代入
    ref A opAssign(A rhs)
    {
        writeln("opAssign(A) from id=", rhs.id);
        id = rhs.id;
        return this;
    }
}

void main()
{
    writeln("=== opAssign overload selection ===");
    A x = A(1);
    A y = A(2);

    writeln("-- x = y --");
    x = y;              // 期待: opAssign(ref A)

    writeln("-- x = __rvalue(y) --");
    x = __rvalue(y);    // 期待: opAssign(A)

    writeln("-- x = A(3) --");
    x = A(3);           // 期待: opAssign(A)
}
```

### 実測

結果は期待通り、`__rvalue` が影響していることがわかります。

```
=== opAssign overload selection ===
A.ctor id=1
A.ctor id=2
-- x = y --
opAssign(ref A)   from id=2
-- x = __rvalue(y) --
opAssign(A) from id=2
-- x = A(3) --
A.ctor id=3
opAssign(A) from id=3
```

**整理:**

* `x = y` は lvalue 代入なので `opAssign(ref A)` が選ばれる
* `x = __rvalue(y)` と `x = A(3)` は rvalue 扱いなので `opAssign(A)` が選ばれる


## 実験6： `auto ref` 引数と `__rvalue` の組み合わせ

ここまで色々実験しましたが、最後に組み合わせるのは `auto ref` です。
`auto ref` は **lvalue なら `ref`、rvalue なら by-value** で受け取るテンプレート引数修飾子です。

更にそこから別の関数に渡す「**forwarding（転送）**」の例も合わせて確認していきます。

非常に難解ではあるんですが、ぜひとも結果がどうなるか想像しながらご確認ください。
これが理解できれば恐らく rvalue マスターです。

### ソース

```d global name=exp06_auto_ref_forward
// exp06_auto_ref_forward.d
import std.stdio;

struct T { int v; }

// __rvalue で切り替える予定の終端になる関数
void sink(T)(T x)     { writeln("sink(T)    (by value)"); }
void sink(T)(ref T x) { writeln("sink(ref T)"); }

// auto ref で受け取ってそのまま渡す関数
void forwardLValue(T)(auto ref T x)
{
    writeln("forwardLValue:");
    sink(x); // x は式としては lvalue に見える
}

// auto ref で受け取って __rvalue 化して渡す関数
void forwardRvalue(T)(auto ref T x)
{
    writeln("forwardRvalue:");
    sink(__rvalue(x)); // 強制的に rvalue 化して sink(T x) 側を期待
}

void main()
{
    writeln("=== auto ref forwarding ===");
    T a = T(1);

    writeln("\n-- call with lvalue --");
    forwardLValue(a);
    forwardRvalue(a);

    writeln("\n-- call with __rvalue(lvalue) --");
    forwardLValue(__rvalue(a));
    forwardRvalue(__rvalue(a));

    writeln("\n-- call with temporary --");
    forwardLValue(T(2));
    forwardRvalue(T(2));
}
```

### 実測

以下結果ですが、1個1個を比較するよりも、全体流して見たほうがわかりやすいと思います。

```
=== auto ref forwarding ===

-- call with lvalue --
forwardLValue:
sink(ref T)
forwardRvalue:
sink(T)    (by value)

-- call with __rvalue(lvalue) --
forwardLValue:
sink(ref T)
forwardRvalue:
sink(T)    (by value)

-- call with temporary --
forwardLValue:
sink(ref T)
forwardRvalue:
sink(T)    (by value)
```

はい。 **3つとも結果が同じ** でした。

内部で `__rvalue` を使うほうは期待通り by-value で動いていますが、**`forwardLValue` のほうはすべて `sink(ref T)` に吸われてしまっています**。

実はこちら、 `core.lifetime.forward` のドキュメントにほぼ同型の例が載っていて、`forward` を使うと上手く `T / ref T` のオーバーロードを切り替えられる、という形でその有効性を示すサンプルがあります。

https://dlang.org/phobos/core_lifetime.html#.forward

もう一度見てみると、使わなければ by-ref、`__rvalue` を付ければ by-value、という綺麗に対称的な振り分けになっていることがわかります。

これはつまり `__rvalue` を **forwarding の文脈で使うのは難しいので、`core.lifetime.forward` を使いましょう** ということでした。

## 実験7: `core.lifetime.move` と `core.lifetime.forward` の動作確認

`__rvalue` の動作を理解した上で、D標準ライブラリの `core.lifetime` モジュールにある `move` と `forward` の動作を確認しておきます。

### ソース1

まずは `core.lifetime.move/forward` による `auto ref`の動作確認です。

```d global name=exp07_core_lifetime
// exp07_core_lifetime.d
import core.lifetime : move, forward;
import std.stdio;

struct Tr
{
    int id;
    this(int id) { this.id = id; writeln("Tr.ctor id=", id); }

    // move ctor
    this(return scope Tr rhs)
    {
        writeln("Tr.move from id=", rhs.id);
        id = rhs.id;
        rhs.id = -1;
    }

    // copy ctor
    this(ref return scope const Tr rhs)
    {
        writeln("Tr.copy from id=", rhs.id);
        id = rhs.id;
    }

    ~this() { writeln("Tr.dtor id=", id); }
}

// __rvalue で切り替える予定の終端になる関数
void sink(T)(T x)     { writeln("sink(T)    (by value)"); }
void sink(T)(ref T x) { writeln("sink(ref T)"); }

// auto ref で受け取ってそのまま渡す関数
void forwardCoreLifetime(T)(auto ref T x)
{
    writeln("forwardCoreLifetime:");
    sink(forward!(x)); // テンプレート引数として渡すことに注意
    writeln("after sink in forwardCoreLifetime");
}

void main()
{
    writeln("=== auto ref forwarding ===");

    writeln("\n-- call with lvalue --");
    {
        Tr a = Tr(10);
        forwardCoreLifetime(a); // auto ref + forward で安全
    }

    writeln("\n-- call with __rvalue(lvalue) --");
    {
        Tr b = Tr(20);
        forwardCoreLifetime(__rvalue(b)); // auto ref + forward で安全だが move 推奨
    }

    writeln("\n-- call with core.lifetime.move --");
    {
        Tr c = Tr(30);
        forwardCoreLifetime(move(c)); // auto ref + forward で安全
    }

    writeln("\n-- done --");
}
```

### 実測2

結果です。

```
=== auto ref forwarding ===

-- call with lvalue --
Tr.ctor id=10
forwardCoreLifetime:
sink(ref T)
after sink in forwardCoreLifetime
Tr.dtor id=10

-- call with __rvalue(lvalue) --
Tr.ctor id=20
forwardCoreLifetime:
sink(T)    (by value)
Tr.dtor id=20
after sink in forwardCoreLifetime
Tr.dtor id=0
Tr.dtor id=0

-- call with core.lifetime.move --
Tr.ctor id=30
forwardCoreLifetime:
sink(T)    (by value)
Tr.dtor id=30
after sink in forwardCoreLifetime
Tr.dtor id=0
Tr.dtor id=0

-- done --
```

`forwardCoreLifetime` の中で `forward!(x)` を使うと、**呼び元のカテゴリに基づいて by-ref と by-value が呼び分けられる** ということがわかります。
また、デストラクタの呼び出し回数もそれぞれ1回限りで正しく動いています。（id=0 は moved-from の状態）

### ソース2

次に `core.lifetime.move` と `opAssign` overload の組み合わせを確認します。

```d global name=exp08_core_lifetime_move_opassign
// exp08_core_lifetime_move_opassign.d
import core.lifetime : move;
import std.stdio;

struct A
{
    int id;

    this(int id) { this.id = id; writeln("A.ctor id=", id); }

    ref A opAssign(ref A rhs)
    {
        writeln("opAssign(ref)   from id=", rhs.id);
        id = rhs.id;
        return this;
    }

    ref A opAssign(scope A rhs)
    {
        writeln("opAssign(scope) from id=", rhs.id);
        id = rhs.id;
        return this;
    }

    ~this() { writeln("A.dtor id=", id); }
}

void main()
{
    writeln("=== opAssign overload selection ===");

    writeln("-- x = y --");
    {
        A x = A(1);
        A y = A(2);
        x = y;              // 期待: opAssign(ref)
    }

    writeln("-- x = __rvalue(y) --");
    {
        A x = A(1);
        A y = A(2);
        x = __rvalue(y);    // 期待: opAssign(scope)
    }

    writeln("-- x = move(y) --");
    {
        A x = A(1);
        A y = A(4);
        x = move(y);        // 期待: opAssign(scope)
    }

    writeln("-- done --");
}
```

### 実測2

結果です。

```
=== opAssign overload selection ===
-- x = y --
A.ctor id=1
A.ctor id=2
opAssign(ref)   from id=2
A.dtor id=2
A.dtor id=2
-- x = __rvalue(y) --
A.ctor id=1
A.ctor id=2
opAssign(scope) from id=2
A.dtor id=2
A.dtor id=2
A.dtor id=2
-- x = move(y) --
A.ctor id=1
A.ctor id=4
opAssign(scope) from id=4
A.dtor id=4
A.dtor id=0
A.dtor id=4
-- done --
```

結果は期待通り、`move(y)` も `__rvalue(y)` も同じく `opAssign(scope)` が選ばれています。

また dtor 呼び出しは `move(y)` の場合だけ、`y` が moved-from になっているため id=0 で呼ばれています。
`__rvalue` の場合は `y` は元のままなので id=2 で呼ばれており、**`__rvalue` だと二重解放リスクがあり危険** です。


## 実務ガイドライン

以下、実験結果を踏まえて **`__rvalue` を使う際の実務的な注意点・ガイドライン** をまとめます。

### 1. ユーザー向け API で `__rvalue` を前提としない（原則：`move` / `forward` を使わせる）

`__rvalue` は **言語プリミティブ** であって、安全な所有権移譲を完結させる仕組みではありません。
ChangeLog でも「ライブラリ primitive を実装するための internal tool」として位置づけられており、ユーザーに求める類のものではありません。

* 所有権を「移したい」：`core.lifetime.move` を使う
  * `move` は状況に応じて source を `.init` に戻す（特に destructor/postblit を持つ struct で重要）など、**後始末を含む契約**になっています。
* value category を「保って転送したい」：`core.lifetime.forward` を使う
  * `auto ref` + そのまま呼び出し、が壊れる典型例まで含めてドキュメント化されています。

> `__rvalue` を直接使うのは、**言語/ライブラリ基盤側（低レベル）で “転送・ムーブ” の最小部品として扱うとき**が中心、という整理が安全です。

### 2. move ctor / rvalue 向け `opAssign` を書くなら「moved-from を benign」にする

ChangeLog が明言している通り、**moved object もデストラクタが呼ばれます**。
よって moved-from を「破棄しても安全」へ戻すのは、最適化等ではなく **契約・制約** です。

* 典型パターン：ハンドル/ポインタを `0/null`、所有フラグを落とす、または `T.init` 相当に戻す
* moved-from を「まだ使える」と期待しない（使うなら moved-from 契約を明記して最小限に）

### 3. postblit と move ctor（および rvalue reference 的な経路）を混ぜない

仕様にも「同じ struct に postblit と move ctor を併用するな」と明確に書かれています。
さらに設計意図としても「move ctor / rvalue は postblit の置き換えで、両立させる努力はしていない」という見解が示されています。 

現実のコードベースでは移行期があるので、実務的には postblit か move ctor かどちらかにハッキリ揃えるのが適切です。

* **postblit 系の設計でいく**：`__rvalue` / move ctor に頼らない（rvalue 経路を開かない）
* **move ctor 系でいく**：postblit を排除（少なくとも同居は避ける）

### 4. 「move ctor が呼ばれる／呼ばれない」を正しさの前提にしない

実験4で見た通り、`__rvalue` を渡したときに **「どの ctor が呼ばれるか」 は実装次第です**。
これは最適化・呼出規約・省略（elision）・コンパイラ差の影響を強く受ける領域です。

どう転んでも安全にするには **「所有権を渡したら source を使わない」** と **「moved-from を benign にする」** の2点です。

### 5. `core.lifetime.move` を使うなら「自己参照ポインタ」と `opPostMove` を意識する

`move` には、**内部ポインタが自分自身を指す型は `opPostMove` （move独自フック）がないとムーブできない** という事前条件があります。（[moveドキュメント](https://dlang.org/phobos/core_lifetime.html#.move)）

> 典型例: `struct Node { Node* next; }` のような自己参照ポインタ

これは恐らく実行すればほぼ必ず落ちる類の制約ですが、それでも見落とすと危険なので、型設計の段階で決めたり単体テストで潰せると良い部分です。


## まとめ

長くなりましたがまとめです。

* `__rvalue` は「式を rvalue 扱いに変換する」新キーワードで、**オーバーロード解決・move ctor / rvalue 向け `opAssign` の経路選択を可能にする**。
* `ref` 戻り値関数に付ける `__rvalue` 属性は、**「参照で返す」 と「呼び出し式は rvalue 扱いにしたい」** を同時に満たすための仕掛けで、`move/forward` 実装の足場として想定されている。
* `__rvalue` は安全装置ではない。特に `__rvalue(x)` を渡した経路では、実装都合で move ctor 呼び出しが省略されたり、「見かけ上 by-value でも参照のように振る舞う」という挙動がある。
* 実務では、`__rvalue` を直接使うより、契約が明文化された `core.lifetime.move` / `core.lifetime.forward` を使うのが安全で、特に `forward` は `auto ref` の「そのまま渡すと全部 lvalue 化する」問題に対する定石になっている。
* move ctor を採用するなら postblit との同居は避ける。これは仕様上も設計意図上も「混ぜるな危険」の領域。

長くなりましたが、以上、dmd 2.111.0 で導入された `__rvalue` の実験と解説でした。

`__rvalue` を正しく使いこなして、安全かつ効率的なプログラミングを実現しましょう！
しかしぶっちゃけ `__rvalue` の直接使用は推奨されないと思います！しっかり `move` / `forward` を使え！