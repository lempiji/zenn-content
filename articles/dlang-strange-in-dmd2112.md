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

見たことが無い機能、見たことが無い関数、そんなものがまだまだたくさんあります。

意図して埋めた奇妙な点は **11個** ありました。

どこが奇妙に感じたでしょうか？
最近追加された機能、フラグが外れて標準で使えるようになった機能を中心に解説していきます。

### 意図した奇妙な点

1. 変数宣言をすべて `scope` で行っている。
   - `auto` の代わりに、全面的に `scope` としました。変数がスコープを抜けるときに自動的に破棄されることを保証し、配列をスタックに割り当てる効果もあります。
   - 配列のスタック割り当ては、バージョン [2.102.0](https://qiita.com/lempiji/items/a7aa1ce5c719dbf578b0#%E5%BC%B7%E5%8C%96--scope-%E5%AE%A3%E8%A8%80%E3%81%95%E3%82%8C%E3%81%9F%E9%85%8D%E5%88%97%E5%A4%89%E6%95%B0%E3%81%AB%E5%89%B2%E3%82%8A%E5%BD%93%E3%81%A6%E3%82%89%E3%82%8C%E3%81%9F%E9%85%8D%E5%88%97%E3%83%AA%E3%83%86%E3%83%A9%E3%83%AB%E3%81%AF%E3%82%B9%E3%82%BF%E3%83%83%E3%82%AF%E3%81%AB%E7%A2%BA%E4%BF%9D%E3%81%95%E3%82%8C%E3%82%8B%E3%82%88%E3%81%86%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%97%E3%81%9F) で追加された機能です。
2. `UUID` の引数に `Clock.currTime()` を使っている。
   - UUIDは通常ランダムな値を生成するために使用されますが、ここではUUID v7を使うために現在の時間を引数にしています。これによってIDが生成時刻に基づいてソートできるようになります。
   - このUUID v7対応はは、バージョンは [2.112.0](https://qiita.com/lempiji/items/7ba90329faad243335ee#stduuid-%E3%81%AB-uuid-v7-%E5%AF%BE%E5%BF%9C%E3%81%8C%E8%BF%BD%E5%8A%A0%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で追加された機能です。
3. 変数の宣言に `ref` を使っている。
   - `ref` は変数が参照になることを表します。これにより、ポインタを経由したかのように書き換えができます。
   - この `ref` 変数は、バージョン [2.111.0](https://qiita.com/lempiji/items/ccc639825a64bc149659#%E3%82%B9%E3%83%88%E3%83%AC%E3%83%BC%E3%82%B8%E3%82%AF%E3%83%A9%E3%82%B9-ref-%E3%81%A8-auto-ref-%E3%81%8C%E3%83%AD%E3%83%BC%E3%82%AB%E3%83%AB%E5%A4%89%E6%95%B0%E9%9D%99%E7%9A%84%E5%A4%89%E6%95%B0extern-%E5%A4%89%E6%95%B0%E3%82%B0%E3%83%AD%E3%83%BC%E3%83%90%E3%83%AB%E5%A4%89%E6%95%B0%E3%81%AB%E3%82%82%E9%81%A9%E7%94%A8%E5%8F%AF%E8%83%BD%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%97%E3%81%9F) で追加された機能です。
4. `delete` 関数が定義されている。
   - `delete` は最近まで予約語でした。
   - バージョン [2.111.0](https://qiita.com/lempiji/items/ccc639825a64bc149659#delete-%E3%82%AD%E3%83%BC%E3%83%AF%E3%83%BC%E3%83%89%E3%81%8C%E5%BB%83%E6%AD%A2%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で予約語から外され、関数名などで使えるようになりました。
5. `User` のコンストラクタや `delete` 関数の呼び出しで引数を名前付きで呼び出している。
   - 名前付き引数が使用できます。これにより引数の順序を入れ替えても呼び出せるようになります。
   - バージョン [2.108.0](https://qiita.com/lempiji/items/73e2af3d452ca21466e0#%E9%96%A2%E6%95%B0%E3%81%AE%E5%90%8D%E5%89%8D%E4%BB%98%E3%81%8D%E5%BC%95%E6%95%B0%E3%81%8C%E5%AE%9F%E8%A3%85%E3%81%95%E3%82%8C%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88%E5%8C%96%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で追加された機能です。
6. `appender` に対して `writeText` を呼び出している。
   - `writeText` は OutputRange に対してテキストを書き込むための関数です。これにより、文字列を効率的に構築できます。
   - バージョン [2.112.0](https://qiita.com/lempiji/items/7ba90329faad243335ee#stdconv-%E3%81%AB-writetext--writewtext--writedtext-%E3%81%8C%E8%BF%BD%E5%8A%A0%E3%81%95%E3%82%8C%E3%81%BE%E3%81%97%E3%81%9F) で追加された機能です。
7. `i"..."` という形式の文字列リテラルを使用している。
   - Interpolated Expression Sequences（式の補間シーケンス）を使用して、文字列内に変数の値を埋め込んでいます。
   - バージョン [2.108](https://qiita.com/lempiji/items/73e2af3d452ca21466e0#interpolated-expression-sequencesies%E5%BC%8F%E3%81%AE%E8%A3%9C%E9%96%93%E3%82%B7%E3%83%BC%E3%82%B1%E3%83%B3%E3%82%B9%E3%81%AE%E3%82%B5%E3%83%9D%E3%83%BC%E3%83%88%E3%82%92%E8%BF%BD%E5%8A%A0) で追加された機能です。
8. テーブル出力の形式に `%=8s` などのフォーマット指定子を使用している。
   - これは最近追加された中央寄せのフォーマット指定子で、テーブルの列を整えるために使用しています。（数値は右寄せにしましょう）
   - バージョン [2.108](https://qiita.com/lempiji/items/73e2af3d452ca21466e0#interpolated-expression-sequencesies%E5%BC%8F%E3%81%AE%E8%A3%9C%E9%96%93%E3%82%B7%E3%83%BC%E3%82%B1%E3%83%B3%E3%82%B9%E3%81%AE%E3%82%B5%E3%83%9D%E3%83%BC%E3%83%88%E3%82%92%E8%BF%BD%E5%8A%A0) で追加された機能です。
9. `buf[]` のような形式で `appender` の内容を取得している。
   - 従来は `buf.data` のようにして内容を取得していましたが、最近はスライスを取る `[]` 演算子で内容を取得することができます。
   - バージョン [2.088.0](https://qiita.com/lempiji/items/04b2cb5ce6da7d2f46d4#%E5%A4%89%E6%9B%B4-appender-%E3%82%84-refappender-%E3%81%AF-data-%E3%81%AE%E4%BB%A3%E3%82%8F%E3%82%8A%E3%81%AB-opslice-%E3%81%8C%E6%8E%A8%E5%A5%A8%E3%81%95%E3%82%8C%E3%81%BE%E3%81%99) で追加された機能です。
10.  `UUID id() => _id;` のような形式の関数定義を使用している。
   - これは関数の本体が単一の式である場合に使用できる短縮メソッド構文です。
   - バージョン [2.101.0](https://qiita.com/lempiji/items/52dc4785b7c51ca464b3#%E5%BC%B7%E5%8C%96--%E7%9F%AD%E7%B8%AE%E3%81%95%E3%82%8C%E3%81%9F%E3%83%A1%E3%82%BD%E3%83%83%E3%83%89%E6%A7%8B%E6%96%87%E3%81%8C%E3%83%87%E3%83%95%E3%82%A9%E3%83%AB%E3%83%88%E3%81%A7%E4%BD%BF%E7%94%A8%E3%81%A7%E3%81%8D%E3%82%8B%E3%82%88%E3%81%86%E3%81%AB%E3%81%AA%E3%82%8A%E3%81%BE%E3%81%97%E3%81%9F) で追加された機能です。
11. `writefln!"..."` では3つ指定するべき値が、`stats.tupleof` で1つしか指定されていない
    - `stats.tupleof` は構造体のフィールドをタプルとして返す機能で、これを使うと構造体の全フィールドを一度にフォーマット指定子に渡すことができます。
    - ずっと前から存在する機能で、いつからあるのか特定できませんでした。

## まとめ

色々な機能強化があり、今はこれほどまでに違った景色を見ることができます。

次に奇妙な世界の扉を開けてしまうのは、あなたかもしれません。
