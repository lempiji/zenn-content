---
title: "D言語標準ライブラリ紹介：object"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: true
---

[![dlang-adc-2025-druntime-object](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-druntime-object.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-adc-2025-druntime-object.yml)

## はじめに

こちらは、Qiita D言語アドベントカレンダー 2025 の **10日目** の記事です。

https://qiita.com/advent-calendar/2025/dlang

こちら標準ライブラリをサクッと紹介するシリーズですが、今回は10日目で区切りが良いので、ちょっと趣向を変えて `object` モジュールを取り上げます。


## `object` 紹介

https://dlang.org/phobos/object.html

D言語の `object` モジュールは、**すべてのDプログラムで使える基本シンボル群** を提供し、クラス階層の最基底である `Object` などを含むモジュールです。

また、**`object` モジュールは暗黙に import されており**、直接インポートする方はまずいない特殊なモジュールです。
「普段わざわざ `import object;` しない」ですし、「`class Hoge : Object {}` とは書かない」ので、定義にジャンプして読む方も大変少ないと思います。

しかしコードを読んでいると頻繁に遭遇する / 実はいつでも使える、今回はそんな `object` の機能紹介です。特によく見かける・実は便利なものを中心に **7機能** 紹介します。

## 機能ミニ解説

### 1. `Throwable / Exception / Error`

D言語の例外機構（`throw`/`catch`）に関して、例外オブジェクトとして使える `Throwable` / `Exception` / `Error` という3つのクラスが提供されます。

これらには継承関係があり、ルートは `Throwable` で、その派生として

* `Exception`: **catchして処理してよい**（安全に扱える）エラー群の基底
* `Error`: **回復不能** なランタイムエラー群の基底

という構造になっています。

基本的には `Exception` の派生クラスを `throw` して、`catch` で捕まえて処理する形にします。
`throw` や `try-catch` については [公式ドキュメント](https://dlang.org/spec/errors.html) や [D言語Cookbook](https://dlang-jp.github.io/Cookbook/cookbook--exception_example.html) などを参照ください。

**使用例**

```d global name=exception_example
import std.stdio;

int parsePositive(string s)
{
    // 文字種の検証
    foreach (ch; s)
        if (ch < '0' || ch > '9')
            throw new Exception("not a number: " ~ s); // 想定されるエラー

    // 解析処理をして返すイメージ
    return 0;
}

void main()
{
    try
    {
        writeln(parsePositive("12")); // OK
        writeln(parsePositive("oops")); // ここで Exception
    }
    catch (Exception e)
    {
        writeln("recoverable error: ", e.msg);
    }
}
```

```d global name=error_example
import std.stdio;

void main()
{
    int[] arr = [1, 2, 3];
    try
    {
        arr[10] = 42; // 範囲外アクセスで ArrayIndexError 発生
    }
    catch (Error e)
    {
        // たとえば最上位でログに残して終了させる。無理な場合は諦める…
        writeln("fatal: ", e.msg);
        return;
    }
}
```

##### `noreturn`

`object` には bottom type と呼ばれる `noreturn` という型があります。これは文字通り「戻らない」ことを戻り値型として表す用途で使います。
たとえば「内部で無限ループする」「例外を投げて必ず中断する」といった関数の戻り値は `void` ではなく `noreturn` が適切です。

```d global name=noreturn_example
import std.stdio;

noreturn die(string msg)
{
    throw new Exception(msg);
}

void main()
{
    try
    {
        die("stop here");
    }
    catch (Exception e)
    {
        // サンプルとしてエラーを表示して正常終了させる
        import std.stdio : writeln;
        writeln(e.msg);
    }
}
```


### 2. `Object`（`toString / toHash / opEquals`）

`Object` は、D言語における **すべてのクラスの基底クラス** です。
クラスベースの設計をしているといくつか `override` したくなるメソッドがあり、特に頻出なものとして `toString` / `toHash` / `opEquals` があります。

1. `string toString()`: オブジェクトの文字列表現を返す（デバッグ表示やログ出力で使う）
2. `size_t toHash()`: オブジェクトの内容に基づくハッシュ値を返す（主に連想配列のキーを細かく制御する時に使う）
3. `bool opEquals(Object o)`: オブジェクトの内容比較を行う（`==` 演算子で使う）

**使用例**

```d global name=object_example
import std.stdio;

class User : Object
{
    string name;
    int age;

    this(string name, int age)
    {
        this.name = name;
        this.age = age;
    }

    // 文字列表現
    override string toString()
    {
        return "User(" ~ name ~ ")";
    }

    // 内容ハッシュ
    override size_t toHash() nothrow @trusted
    {
        // シンプルな組合せハッシュ
        size_t h = name.length;
        h = h * 31 + cast(size_t)age;
        return h;
    }

    // 型付き overload（内容比較の本体）
    bool opEquals(const User u) const
    {
        if (u is null) return false;
        return name == u.name && age == u.age;
    }

    // 汎用 override（Object から来た比較を型付き overload に流す）
    override bool opEquals(Object o)
    {
        return this.opEquals(cast(User)o);
    }
}

void main()
{
    auto a = new User("alice", 20);
    auto b = new User("alice", 20);
    auto c = new User("bob",   20);

    writeln(a.toString());   // User(alice)
    writeln(a == b);         // true（内容比較）
    writeln(a == c);         // false
    writeln(a.toHash());     // ハッシュ値
}
```


### 3. `dup / idup`

`dup` は **配列（スライス）のコピー** を作成するための関数で、非常によく見かけるものです。
私は以前 `dup` を「配列のプロパティとして定義された特殊な処理」というイメージで雰囲気だけで使っていましたが、実態は **`object` モジュールに定義されたただの `dup` 関数をUFCSで呼び出して使っている** と知って大変驚きがありました。

この `.dup` の目的は「不変配列を可変配列に変換する」ために使います。例えば `string` (`immutable(char)[]`) を `char[]` に変換、書き込み可能にする用途で使います。

対して、`.idup` は「可変配列を不変配列に変換する」ために使います。例えば `char[]` を `string` (`immutable(char)[]`) に変換する用途です。
こちらは使いまわされるバッファから、ある時点で定まった内容を固定しておきたいときに出てきます。

**使用例**

```d global name=dup_example
import std.stdio;

void main()
{
    string s = "hello world";

    // 文字列を“編集用バッファ”にする（string -> char[]）
    char[] buf = s.dup;
    char[] buf2 = dup(s); // 実は関数呼び出しスタイルでもOK

    foreach (ref c; buf)
        if (c == ' ') c = '_';

    writeln(buf); // hello_world

    // 可変配列を不変配列にする、バッファを固定化する（char[] -> string）
    string fixed = buf.idup;
    buf[0] = 'H'; // bufを書き換えてもfixedには影響しない
    writeln(fixed); // hello_world
}
```


### 4. `get / require`

`get` / `require` はどちらも連想配列（Associative Array）から値を取り出す時に使える関数です。キーが存在すればそのまま取得、キーが無ければ既定値を得る、というものです。

使い方はどちらもほぼ同じですが、実際の挙動には若干の違いがあります。

* `get`: キーがあれば値、なければ `defaultValue` を返す（AAは変更しない）
* `require`: キーがあれば値、なければ指定した値または初期値を格納して返す（AAが変更される）

重いデータのキャッシュは `require` が向いていて、軽いデフォルト値なら `get` が向いています。
ちなみにどちらも初期値の部分は `lazy` 引数となっており、必要時のみ評価されます。

**使用例**

```d global name=get_require_example
import std.stdio;

void main()
{
    int[string] score = ["alice": 10];

    writeln(score["alice"]); // 10
    // writeln(score["bob"]); // ArrayIndexError 発生

    writeln(score.get("alice", 0)); // 10
    writeln(score.get("bob",   0)); // 0（存在しないので default）

    // getだと、scoreに"bob"は存在しない
    writeln("bob" in score); // false

    // requireだと、存在しなければ初期値を格納して返す
    writeln(score.require("bob", 42)); // 42（初期値を格納して返す）
    writeln(("bob" in score) !is null); // true（キーが存在するようになった）

    writeln(score.require("charlie")); // 0（省略時は値型の初期値を格納して返す）
    writeln(("charlie" in score) !is null); // true
}
```


### 5. `update`

`update` は連想配列における値の作成処理と更新処理を渡して、「キーが無ければ `create`、あれば `update`」を呼び分けます。要するに `if (key in aa) { /* 更新 */ } else { /* 初期化 */ }` を書く代わりに使える関数です。

`update` 側の処理は **`ref` で値を更新する関数** か、**値を返して差し替える関数** のいずれかで指定できます。ただし、コピー等のコストを考えると **`ref` 引数で更新する関数を渡すスタイルが推奨** です。

**使用例**（アクセスカウンタ、無ければ1、あれば+1）

```d global name=update_example
import std.stdio;

void countUpdate(ref int[string] hits, string key)
{
    hits.update(
        key,
        () => 1,                 // create: 初回
        (ref int v) { v += 1; }  // update: 2回目以降
    );
}

void main()
{
    int[string] hits;

    string key = "index.html";

    countUpdate(hits, key);
    countUpdate(hits, key);

    writeln(hits[key]); // 2
}
```


### 6. `byKeyValue`

`byKeyValue` は連想配列（Associative Array、以下AA）のキーと値のペアをレンジとして取得するメソッドです。 

普段連想配列を順番に処理しようと思うと `foreach` を書きますが、これを様々なアルゴリズムと連携させるためのアダプターとなるのが `byKeyValue` です。

**使用例**

```d global name=byKeyValue_example
import std.algorithm : filter, map;
import std.array : array;
import std.stdio;

void main()
{
    int[string] aa = ["k1": 10, "k2": 20, "k3": 30];

    // 普通の foreach でキー・値ペアを処理する
    string[] keys = [];
    foreach (kv; aa.byKeyValue)
    {
        if (kv.value >= 20)
            keys ~= kv.key;
    }
    writeln(keys); // [k2, k3]

    // byKeyValue を挟めば、レンジとして処理できる
    string[] keysOverEq20 = aa.byKeyValue
        .filter!(kv => kv.value >= 20)
        .map!(kv => kv.key)
        .array;

    writeln(keysOverEq20); // [k2, k3]
}
```


### 7. `TypeInfo / typeid`

`TypeInfo` は「実行時型情報（通称RTTI、Run-Time Type Information）」で、オブジェクトから `typeid` 式（TypeidExpression）を通じて実際の変数の型を取得できるものです。
たとえばあらゆるクラスのインスタンスは `Object` 型の変数に格納できるわけですが、実行時型情報を使うと「実際にはどのクラスのインスタンスか？」を調べることができます。

クラスに対しては `TypeInfo_Class` 、インターフェースに対しては `TypeInfo_Interface` があり、モジュールに対する `TypeInfo_Module` もあります。それぞれ `name` で名前が取れたりします。他にどのような情報が取れるかはドキュメントを参照してください。

**使用例**

```d global name=typeinfo_example
import std.stdio;

class Base {}
class ChildA : Base {}
class ChildB : Base {}

void handle(Object o)
{
    // 期待する動的型か？
    if (typeid(o) is typeid(ChildA))
    {
        writeln("it's ChildA (via typeid) : ", typeid(o).toString());
        auto c = cast(ChildA)o; // この後 ChildA 前提で扱う
        return;
    }

    // cast してみて null チェックする方法もある
    if (auto c = cast(ChildB)o)
    {
        writeln("it's ChildB (via cast)");
        return;
    }

    writeln("unknown type");
}

void main()
{
    handle(new ChildA());
    handle(new ChildB());
    handle(new Base());
}
```



### まとめ

`object` は暗黙的にインポートされるモジュールで、例外・Objectなど普段無意識に使っているものが定義された特殊なモジュールです。

覚えておきたいところとしては、**例外階層 / `Object` の比較・ハッシュ / `.dup/.idup` / AAの `get/require/update`** あたりでしょうか。
`byKeyValue` と `TypeInfo/typeid` は「必要な人は必要」枠だけど、知ってるとコード読解が速くなる・書ける幅が広がる、という感じです。

他にも紹介しきれてない要素（`destroy` / `imported`）などがあるので、気になる方は公式ドキュメントを読んでみてください。

https://dlang.org/library/object.html
