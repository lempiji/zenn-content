---
title: "世にも奇妙なD言語"
emoji: "🎭"
type: "tech"
topics: ["dlang", "compiler"]
published: false
---

[![dlang-strange-in-dmd2112](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-strange-in-dmd2112.yml/badge.svg)](https://github.com/lempiji/zenn-content/actions/workflows/test-dlang-strange-in-dmd2112.yml)

ようこそ、奇妙な世界へ。

これからお見せするのは、見たことがあるようで何かがおかしい、最新のD言語のコードです。

色々な言語に似ているところが多いD言語ですが、そんな中でもあまり「見たことが無い」、しかし「なぜか読める、動く」、そんな奇妙さを感じてもらえればと思います。

ちなみにコードにそれほど意味はありませんのでサラッと読んでください。

動作確認しているコンパイラは dmd 2.112.0、単体でしっかり動くのでご安心ください。
解説は後半にあります。

## コード

```d global
import std;
import core.memory;

struct User
{
private:
    UUID _id;
    string _name;
    ubyte _age;

public:
    @disable this();

    this(UUID id, string name, ubyte age)
    {
        _id = id;
        _name = name;
        _age = age;
    }

    UUID id() => _id;
    string name() => _name;
    int age() => _age;

    void increaseAge()
    {
        _age++;
    }
}

void delete(scope ref User[] users, string name)
{
    users = users.filter!(u => u.name != name).array;
}

void main()
{
    immutable beforeGCStats = GC.stats();

    scope User[] users = [
        User(id: UUID(Clock.currTime()), name: "Alice", age: 30),
        User(id: UUID(Clock.currTime()), name: "Bob", age: 25),
        User(id: UUID(Clock.currTime()), name: "Charlie", age: 50)
    ];

    scope ref charie = users[2];
    charie.increaseAge();

    delete(name: "Bob", users: users);
    sort!"a.id > b.id"(users);

    scope buf = appender!string();
    buf.writeText(i"Name: $(users[0].name), Age: $(users[0].age)");
    buf.writeText("\n");
    buf.writeText(i"Name: $(users[1].name), Age: $(users[1].age)");
    writeln(buf[]);

    immutable afterGCStats = GC.stats();

    writefln!"| usedSize | freeSize | allocatedInCurrentThread |"();
    writefln!"|----------|----------|--------------------------|"();
    writefln!"| %=8s | %=8s | %=24s |"(beforeGCStats.tupleof);
    writefln!"| %=8s | %=8s | %=24s |"(afterGCStats.tupleof);
}
```

## 出力例

```console
Name: Charlie, Age: 51
Name: Alice, Age: 30
| usedSize | freeSize | allocatedInCurrentThread |
|----------|----------|--------------------------|
|    32    |  1048544 |            32            |
|   1424   |  1047152 |           1312           |
```

## 解説

さて、ここからは解説のお時間です。

先ほどのコードには、見慣れた顔をしておきながらこれまでの「当たり前」からはかけ離れたものたちが、**11個** 潜んでいました。

あなたはいくつ見つけられたでしょうか？

それでは一つずつ、扉を開けていきましょう。

---

### 第一夜「`auto` のいない世界」

```
scope User[] users = [ ... ];
scope ref charie = users[2];
scope buf = appender!string();
```

お気づきでしょうか。このコードには `auto` が一つもありません。

すべての変数宣言が `scope` で始まっています。D言語において `scope` は単なる型修飾子ではなく、**型推論を兼ねたストレージクラス**です。`auto` と同じように型を推論しつつ、「この変数はスコープの外に漏れ出さない」という契約をコンパイラに伝えます。

そしてその契約には、ちょっとした恩恵がついてきます。`scope` 宣言された配列変数に割り当てられた配列リテラルは、GCヒープではなく**スタックに確保される**のです。出力のGC統計を眺めると、その片鱗が見えるかもしれません。

この配列のスタック割り当ては、バージョン [2.102.0](https://qiita.com/lempiji/items/a7aa1ce5c719dbf578b0#%E5%BC%B7%E5%8C%96--scope-%E5%AE%A3%E8%A8%80%E3%81%95%E3%82%8C%E3%81%9F%E9%85%8D%E5%88%97%E5%A4%89%E6%95%B0%E3%81%AB%E5%89%B2%E3%82%8A%E5%BD%93%E3%81%A6%E3%82%89%E3%82%8C%E3%81%9F%E9%85%8D%E5%88%97%E3%83%AA%E3%83%86%E3%83%A9%E3%83%AB%E3%81%AF%E3%82%B9%E3%82%BF%E3%83%83%E3%82%AF%E3%81%AB%E7%A2%BA%E4%BF%9D%E3%81%95%E3%82%8C%E3%82%8B%E3%82%88%E3%81%86%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%97%E3%81%9F) で追加されました。

---

### 第二夜「時を刻むUUID」

```
User(id: UUID(Clock.currTime()), name: "Alice", age: 30),
```

UUIDといえばランダム生成――そう思い込んでいた方にとっては、`Clock.currTime()` を渡している光景は奇妙に映るでしょう。

これは **UUID v7** です。UUID v7はタイムスタンプベースのUUIDで、生成時刻に基づいた自然なソート順を持ちます。データベースの主キーとして使えば、ランダムなUUID v4よりもインデックスに優しいという利点があります。

D言語の `std.uuid` も時代の波に乗り、`SysTime` を受け取ってUUID v7を生成できるようになりました。バージョン [2.112.0](https://qiita.com/lempiji/items/7ba90329faad243335ee#stduuid-%E3%81%AB-uuid-v7-%E5%AF%BE%E5%BF%9C%E3%81%8C%E8%BF%BD%E5%8A%A0%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) からの新機能です。

---

### 第三夜「変数が参照になる日」

```
scope ref charie = users[2];
charie.increaseAge();
```

`ref` がローカル変数に付いています。C++なら珍しくもない光景ですが、D言語では長らくこれができませんでした。

`ref` 変数は、配列の要素やフィールドへの**エイリアス**です。ポインタのように間接的にアクセスしますが、`null` にはなりません。ここでは `users[2]` への参照を取り、`charie.increaseAge()` で元の配列上のCharlieの年齢が直接インクリメントされます。

この `ref` ローカル変数は、バージョン [2.111.0](https://qiita.com/lempiji/items/ccc639825a64bc149659#%E3%82%B9%E3%83%88%E3%83%AC%E3%83%BC%E3%82%B8%E3%82%AF%E3%83%A9%E3%82%B9-ref-%E3%81%A8-auto-ref-%E3%81%8C%E3%83%AD%E3%83%BC%E3%82%AB%E3%83%AB%E5%A4%89%E6%95%B0%E9%9D%99%E7%9A%84%E5%A4%89%E6%95%B0extern-%E5%A4%89%E6%95%B0%E3%82%B0%E3%83%AD%E3%83%BC%E3%83%90%E3%83%AB%E5%A4%89%E6%95%B0%E3%81%AB%E3%82%82%E9%81%A9%E7%94%A8%E5%8F%AF%E8%83%BD%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%97%E3%81%9F) で解禁されました。

---

### 第四夜「禁じられた名前」

```
void delete(scope ref User[] users, string name)
```

`delete`。C言語でもC++でもJavaでもJavaScriptでも予約語であるこの言葉が、**関数名として使われています**。

D言語の `delete` はかつてGCオブジェクトの手動解放に使われるキーワードでした。しかし、GC管理下のオブジェクトを手動でdeleteすることの危険性から、長い非推奨期間を経てついに廃止されました。予約語の束縛から解き放たれた `delete` は、今や自由の身。好きな関数に名前を付けられます。

バージョン [2.111.0](https://qiita.com/lempiji/items/ccc639825a64bc149659#delete-%E3%82%AD%E3%83%BC%E3%83%AF%E3%83%BC%E3%83%89%E3%81%8C%E5%BB%83%E6%AD%A2%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で予約語から正式に外されました。

---

### 第五夜「名前で呼んでくれ」

```
User(id: UUID(Clock.currTime()), name: "Alice", age: 30)
delete(name: "Bob", users: users);
```

`id:`, `name:`, `age:` ――呼び出し側に引数名が露出しています。PythonやSwiftでは馴染み深い名前付き引数が、D言語でもついに使えるようになりました。

注目すべきは `delete` の呼び出し。定義では `(scope ref User[] users, string name)` の順ですが、呼び出しでは `(name: "Bob", users: users)` と**順番が逆**です。名前付き引数は順序を自由に変えられるため、こうした書き方が可能です。可読性を高める場面は多いでしょう。

バージョン [2.108.0](https://qiita.com/lempiji/items/73e2af3d452ca21466e0#%E9%96%A2%E6%95%B0%E3%81%AE%E5%90%8D%E5%89%8D%E4%BB%98%E3%81%8D%E5%BC%95%E6%95%B0%E3%81%8C%E5%AE%9F%E8%A3%85%E3%81%95%E3%82%8C%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88%E5%8C%96%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で追加されました。

---

### 第六夜「書き込んでやろう」

```
buf.writeText(i"Name: $(users[0].name), Age: $(users[0].age)");
```

`appender` に対して `writeText` を呼んでいます。見慣れない名前ですが、これは `std.conv` に新しく追加された関数です。

OutputRange（ここでは `appender!string()`）に対して直接テキストを書き込みます。`std.format` の `formattedWrite` と似ていますが、`writeText` はフォーマット文字列を使わず、値をそのまま文字列化して書き込む点が異なります。文字列結合を繰り返すよりも効率的で、バッファへの直接書き込みの選択肢が増えました。

バージョン [2.112.0](https://qiita.com/lempiji/items/7ba90329faad243335ee#stdconv-%E3%81%AB-writetext--writewtext--writedtext-%E3%81%8C%E8%BF%BD%E5%8A%A0%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で追加されました。

---

### 第七夜「忍び込む式」

```
i"Name: $(users[0].name), Age: $(users[0].age)"
```

`i"..."` で始まる文字列リテラル。`$()` の中にD言語の式が直接書かれています。

これは **Interpolated Expression Sequences（IES、式の補間シーケンス）** と呼ばれる機能で、文字列リテラルの内部に式を埋め込むことができます。JavaScriptのテンプレートリテラルやC#の文字列補間と同じ発想ですが、D言語のIESは内部的にはタプルとして展開されるため、`writeln` や `writeText` など**OutputRangeを受け取る関数と自然に組み合わせられる**のが特徴です。

バージョン [2.108.0](https://qiita.com/lempiji/items/73e2af3d452ca21466e0#interpolated-expression-sequencesies%E5%BC%8F%E3%81%AE%E8%A3%9C%E9%96%93%E3%82%B7%E3%83%BC%E3%82%B1%E3%83%B3%E3%82%B9%E3%81%AE%E3%82%B5%E3%83%9D%E3%83%BC%E3%83%88%E3%82%92%E8%BF%BD%E5%8A%A0) で追加されました。

---

### 第八夜「中央に寄る数字」

```
writefln!"| %=8s | %=8s | %=24s |"(beforeGCStats.tupleof);
```

`%=8s`。見慣れたフォーマットの中に `=` が紛れ込んでいます。

これは**中央寄せ**のフォーマット指定子です。`%-8s` が左寄せ、`%8s` が右寄せなら、`%=8s` は中央寄せ。出力結果のテーブルを見れば、数値が列の中央に揃っている様子がわかるでしょう。テーブル形式のログやレポートを書く際に便利です。

バージョン [2.108.0](https://qiita.com/lempiji/items/73e2af3d452ca21466e0#%E3%82%BB%E3%83%B3%E3%82%BF%E3%83%AA%E3%83%B3%E3%82%B0%E3%83%95%E3%83%A9%E3%82%B0) で追加されました。

---

### 第九夜「どこかに行った `data`」

```
writeln(buf[]);
```

`appender` の中身を取り出すのに `.data` ではなく `[]` を使っています。

かつては `buf.data` が定番でしたが、`opSlice` のオーバーロードが入ったことで `buf[]` というスライス構文も使えるようになっています。短いだけでなく、D言語の配列や他のRange型と一貫した書き方ができる点で、こちらが推奨されています。

バージョン [2.088.0](https://qiita.com/lempiji/items/04b2cb5ce6da7d2f46d4#%E5%A4%89%E6%9B%B4-appender-%E3%82%84-refappender-%E3%81%AF-data-%E3%81%AE%E4%BB%A3%E3%82%8F%E3%82%8A%E3%81%AB-opslice-%E3%81%8C%E6%8E%A8%E5%A5%A8%E3%81%95%E3%82%8C%E3%81%BE%E3%81%99) から推奨されています。

---

### 第十夜「矢印」

```
UUID id() => _id;
string name() => _name;
int age() => _age;
```

`=>` で本体を書くメソッド定義。ラムダ式ではありません。

これは**短縮メソッド構文（Shortened Method Syntax）**です。本体が単一の式で済む場合に波括弧と `return` を省略でき、まるでプロパティ定義のように書けます。C#のexpression-bodied memberに近い感覚です。ゲッターのような短いメソッドで特に威力を発揮します。

バージョン [2.101.0](https://qiita.com/lempiji/items/52dc4785b7c51ca464b3#%E5%BC%B7%E5%8C%96--%E7%9F%AD%E7%B8%AE%E3%81%95%E3%82%8C%E3%81%9F%E3%83%A1%E3%82%BD%E3%83%83%E3%83%89%E6%A7%8B%E6%96%87%E3%81%8C%E3%83%87%E3%83%95%E3%82%A9%E3%83%AB%E3%83%88%E3%81%A7%E4%BD%BF%E7%94%A8%E3%81%A7%E3%81%8D%E3%82%8B%E3%82%88%E3%81%86%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%97%E3%81%9F) でデフォルト有効になりました。

---

### 第十一夜「足りない？」

```
writefln!"| %=8s | %=8s | %=24s |"(beforeGCStats.tupleof);
```

フォーマット指定子は3つ。なのに渡している引数は `beforeGCStats.tupleof` の一つだけ。足りないように見えますが、コンパイルエラーにはなりません。

種を明かせば `.tupleof` です。構造体に `.tupleof` を使うと、全フィールドが**コンパイル時タプル**として展開されます。`GC.Stats` は `usedSize`, `freeSize`, `allocatedInCurrentThread` の3フィールドを持つので、`.tupleof` で3つの値に展開され、フォーマット指定子とぴったり一致するというわけです。

この機能はD言語の初期から存在しており、いつからあるのか特定できませんでした。思い出せないのもまた奇妙で恐ろしいですね……

---

## まとめ

今では広く使われる機能もありますが、最新機能も実に便利であり、多用するとこれほどまでに違った景色を見ることができます。

今回この記事を書くに至ったのも、「変数全部 `scope` で宣言すればよくない？」などと思ったことが発端でした。
そして何の問題もなく書けてしまうのがD言語なのです。

新機能を見かけたら、ほどほどにしつつも積極的に使ってみると良いかと思います。

次に奇妙な世界の扉を開けてしまうのは、あなたかもしれません。
