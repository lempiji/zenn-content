---
title: "C++のライブラリを直接使おう（その２）"
emoji: "🌊"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "cpp", "Windows",]
published: true
---

# 1. はじめに

この記事は、D言語とC++の連携を書き記す記事の第2弾です。

前回の記事では、D言語とC++の連携の基本を説明し、`extern(C++)` の使い方や`string`、`vector`、`unique_ptr` などのよく使われる型を相互に利用する方法を紹介しました。
今回は、前回の手順で作成した環境をもとに進めていきます。

@[card](https://zenn.dev/lempiji/articles/7b620b0f007e1a)


また、今回扱う内容は、D言語とC++の連携に関する以下の2点です。

1. C++で宣言されたクラスや構造体をD言語で継承する
2. C++で宣言された仮想関数をD言語でオーバーライドする

継承や仮想関数はC++では一般的な機能ですが、この部分で連携できる言語は少なく、D言語の強力なアピールポイントの一つです。

いくつか注意点がありますが、この記事を通じてD言語の強力さを感じていただけたらうれしいです！

使っているサンプルのソースコードは以下のリポジトリにありますので適宜参照してください。

@[card](https://github.com/lempiji/example-cpp-d-2)

それでは、さっそく始めます！


# 2. C++のコードを解説(今回扱うサンプル)

まずは、今回扱うC++のサンプルコードについて簡単に説明します。
今回は以下のコードを使って、C++のクラスと継承、仮想関数を主に扱っていきます。

```cpp
namespace mylib2 {
    // クラス
	class TestActor {
	public:
		virtual void action() const; // 仮想関数
	};

    // 構造体
	struct TestActor2 {
	public:
		virtual void action() const; // 仮想関数
	};

	void execute_action(class mylib2::TestActor const* const obj) {
		obj->action(); // 仮想関数の呼び出し、継承されていれば動作が変わるポイント
	}

	void execute_action(struct mylib2::TestActor2 const* const obj) {
		obj->action(); // 仮想関数の呼び出し、継承されていれば動作が変わるポイント
	}
}
```

このサンプルコードでは、`mylib2` という名前空間に `TestActor` クラスと `TestActor2` 構造体が定義されています。それぞれに同じ名前の `action()` という仮想関数が定義されており、これが後ほどD言語側でオーバーライド（書き換え）されるポイントとなります。
（ここでは実装を省略していますが、サンプルプロジェクトでは書いてあります）

また、2つの `execute_action()` 関数が定義されており、それぞれが `TestActor` 型と `TestActor2` 型のオブジェクトを受け取り、そのオブジェクトの `action()` メソッドを呼び出します。「D言語でクラスが適切に継承されると、C++で定義された `execute_action` の中で呼び出し結果が変わる」という点が特に重要です。

__補足:引数のconst修飾と推移的const__

このサンプルコードでは、`execute_action()` 関数の引数宣言が少し複雑に感じるかもしれません。これは後でD言語から呼び出す際に「推移的const（transitive const）」の性質を考慮する必要があるため、あらかじめD言語の言語機能に合わせた記述となっているからです。（このC++側の書き方は自動的に得られるので、後ほど解説します）

D言語には、「`const(T)`」という宣言を行うと、その型の持つすべてのデータに再帰的に`const`が適用される「推移性」という性質があります。
言い換えれば、ある型に`const`修飾を行うと、「その型で扱う限り、そのオブジェクトを通じて到達できる範囲のすべてのデータが変更できない」ということを意味します。


D言語で `const` 修飾が引数に使われると、「関数がそのオブジェクトを変更しない」という制約を表現しています。（コーディング次第で例外はありますが）
推移性のある `const` 修飾は、この性質を明示する上で非常に便利な機能です。

それでは、サンプルコードの全体像を踏まえ、次のセクションではD言語側でこのC++コードを利用する方法を詳しく解説していきます。
C++とD言語の連携が「思っている以上に簡単だ」と感じていただけると思います。

# 3. Dのコードを解説

## 3-1. ライブラリ定義

では本記事の中核となる「D言語からC++ライブラリを利用するために必要なDのコード」について解説していきます。

まずはじめに、C++ライブラリをD言語から利用するために、C++のクラスや関数をD言語で再定義する必要があります。このステップが特に重要で、正確な定義がないとリンクエラーが発生したりするので注意が必要です。


以下の例では、先程のC++コードで定義された `TestActor`、`TestActor2` クラスおよび `execute_action` 関数をD言語で再定義しています。

__C++に対応する定義__

```d:mylib2.d
module mylib2;

extern (C++, mylib2)
{
    class TestActor {
        void action() const;
    }

	// 構造体は追加のexternが必要
    extern (C++, struct) class TestActor2 {
        void action() const;
    }

    void execute_action(const TestActor obj);
    void execute_action(const TestActor2 obj);
}
```

このサンプルで重要となる記述は、`extern (C++, mylib2)` の部分です。これは「以降の定義がC++の `mylib2` 名前空間に属する」という意味です。
`TestActor` クラスはいつものD言語と同様に定義していますが、`TestActor2` は構造体であるため、追加で `extern (C++, struct)` が必要です。

また、C++コードで `const` がついた関数や引数も、D言語側でも `const` を付けて定義しています。かなりシンプルに記述できていますが、これは、D言語の推移的constの性質を考慮して、C++側のコードであらかじめ `const` を調整しておいたためです。正確な記述がない場合、リンクエラーが発生することもあるため注意が必要です。

次のセクションで、D言語側でこの定義を利用し、クラスを継承し、仮想関数をオーバーライドする方法について解説していきます。

## 3-2. クラスや構造体をD言語で継承する方法

それでは、D言語でC++のクラスを継承する方法について見ていきます。
先程のC++コードで定義された `TestActor` クラスをD言語側で継承し、オーバーライドしたメソッドが実行されるまでのサンプルコードを以下に示します。

__クラス継承サンプル__

C++で定義されたクラスをD言語で継承する場合、以下の手順で行います。継承の書き方はC++とほぼ同じです。

1. C++のクラスとして扱うため、 `extern(C++)` をクラス定義に付与します。
2. 継承元のクラス名を `:` の後ろに記述します。
3. `override` のキーワードを使って、継承した `virtual` なメソッドをオーバーライドします。

以下は、上記手順に従って `TestActor` クラスを継承し、D言語でオーバーライドしたサンプルコードです。

```d
import mylib2;

extern(C++) class CustomActor : TestActor {
	override void action() const {
		import std.stdio;

		writeln("CustomActor!");
	}
}

void main()
{
	TestActor actor = new CustomActor;
	execute_action(actor);
}
```

このコードでは、`TestActor` クラスを継承する `CustomActor` クラスを定義しています。`CustomActor` クラスで `action()` メソッドをオーバーライドして、実行されたメソッドを確認するためにクラス名を出力しています。
あとは、このクラスのオブジェクトを作成、`execute_action` 関数で `CustomActor` クラスのオブジェクトを引数に渡して動きを確認します。


同様に、先程のC++コードで定義された `TestActor2` 構造体も、D言語で継承できます。以下に、`TestActor2` 構造体を継承した `CustomActor2` 構造体のサンプルコードを示します。

__構造体継承サンプル__

C++で定義された構造体も同様に、D言語側で定義して継承できます。以下に、`TestActor2` 構造体を継承した `CustomActor2` 構造体のサンプルコードを示します。

```d
import mylib2;

extern(C++, struct) class CustomActor2 : TestActor2 {
	override void action() const {
		import std.stdio;

		writeln("CustomActor2!");
	}
}

void main()
{
	TestActor2 actor2 = new CustomActor2;
	execute_action(actor2);
}
```

このコードもクラスの場合とさほど変わりません。
ただし1つ違う点として、 `extern(C++, struct)` という記述が増えていることが挙げられます。
D言語ではクラスしか継承構造を持つことができないため、「C++では `struct` だった」という情報を示すために追加の属性を付与します。

```console:出力
CustomActor!
CustomActor2!
```

ここまでが、D言語からC++のクラスや構造体を継承してオーバーライドする基本的な方法です。

継承を利用することで、C++側で定義されたクラスや構造体をD言語側でもほぼ同じように利用できます。また、オーバーライドしたメソッドを利用することで、継承したC++クラスの動作をカスタマイズすることも可能です。


# 4. 純粋仮想関数(abstract)の扱い方

D言語では、C++で定義されたクラスや構造体を継承し、さらに純粋仮想関数（`abstract`）もオーバーライドできます。

純粋仮想関数とは、C++で宣言された仮想関数のうち、関数本体が実装されていないものです。

D言語で純粋仮想関数を扱うには、以下の点に注意する必要があります。

1. 型定義には `abstract` を __つけない__
2. `= 0;` を付けた仮想関数には `abstract` を __つける__

では、このルールに基づいて、実際の変換コードを書いていきます。

例えば、以下のC++のサンプルコードでは、`PureFunctionActor` クラスに純粋仮想関数 `action()` が定義されています。

```cpp
namespace mylib2 {
	class PureFunctionActor {
	public:
		virtual void action() const = 0; // 純粋仮想関数
	};
}
```

この場合、D言語で `PureFunctionActor` クラスを継承して、関数をオーバーライドするためには、以下のように定義します。

```d
module mylib2;

extern (C++, mylib2)
{
    // 型定義には abstract が不要
    class PureFunctionActor {
        // メソッドには abstract が必要
        abstract void action() const;
    }
}
```

また、D言語で定義したクラスをC++のコードにそのまま渡すことができます。

```d
import mylib2;

extern(C++) class CustomPureFunctionActor : PureFunctionActor {
	override void action() const {
		import std.stdio;

		writeln("CustomPureFunctionActor");
	}
}

void main()
{
	PureFunctionActor actor3 = new CustomPureFunctionActor;
	execute_action(actor3);
}
```

```console:出力
CustomPureFunctionActor
```

D言語からC++のライブラリを利用する場合は純粋仮想関数の扱いに注意が必要です。
しかし、実際にはC++のコードと非常によく似た書き方で記述でき、連携も容易になっています。


# 5. リンクエラーを解決するためにC++の宣言を見直す例

ここまで、継承やオーバーライドができることを確認できましたので、少し話を変えて実践的なアプローチについても説明します。

C++とD言語の連携では、多くの場合、C++ソースコードが手元にあり、それをD言語から利用したい状況だと思います。
しかし、C++の表現能力は一般的にD言語より高いため、場合によってはC++側の調整が必要になることもあります。

これは逆に言うと、D言語で利用する際のシグネチャは自由度が制限されている、ということです。

つまり、D言語の定義を先に行うことで、C++側の対応する定義がスムーズに行える、ということになります。
実践ではこの順番で作業することにより、D言語の定義からC++側の記述を検討して、整合性を保つ逆アプローチとして活用できます。

具体的には、リンクエラーが発生した際に、「エラーメッセージに記載されている内容をそのままコピーする」というシンプルな方法が非常に有効です。
（メッセージは恐らく環境やリンカに依存するため、ここではWindows上でVisual Studioがインストールされていることを前提として説明します）

実際に試してみると、今回のサンプルで使った「引数が `const(T)` になる予定の関数」のような場合、「C++側に対応する定義が見つからない」という意味で次のようなメッセージが表示されます。

```d:D言語で期待する定義
module mylib2;

extern (C++, mylib2)
{
    class TestActor {
        void action() const;
    }

    void execute_action(const TestActor obj); // この定義がC++側で定義されていない、あるいは若干異なるためマッチしない状況を考えます
}
```

```:リンク時のエラーメッセージ
example-cpp-d2.obj : error LNK2001: 外部シンボル "void __cdecl mylib2::execute_action(class mylib2::TestActor const * const)" (?execute_action@mylib2@@YAXQEBVTestActor@1@@Z) は未解決です
```

このメッセージを読んでみると、`void __cdecl mylib2::execute_action(class mylib2::TestActor const * const)` というC++のシグネチャらしきものが書かれています。
これは、このシグネチャが見つからなかったためリンクエラーが発生している、という内容です。つまり、「D言語のシグネチャをC++風に読み替えたもの」とも言えます。

ここまで来ればあとは簡単で、コピペしてこう、です。

```cpp:変更イメージ
void execute_action(class mylib2::TestActor* const obj); // 元定義がこうだったとして
void execute_action(class mylib2::TestActor const* const obj); // リンクエラーからコピペしてこう書き換える
```

なお、`__cdecl` の部分は `extern(C++)` の指示であるため定義の検討では無視できます。

書き換えが許される場合もあればそうでない場合もありますが、D言語の定義を先に書くことで、比較的簡単にラッパーが作成できます。

ここまでの内容を参考に、ぜひD言語でC++のライブラリを利用してみてください！

# 6. 参考リンク

とりあえず機械的に置き換えたい、といった状況のために参考リンク（公式）を整理しておきます。

@[card](https://dlang.org/spec/cpp_interface.html)

特にデータ型の対応表はこちらです。

@[card](https://dlang.org/spec/cpp_interface.html#data-type-compatibility)


# 6. まとめ

以上、C++とD言語の連携で課題となる継承や仮想関数のオーバーライドに関する情報整理でした。

D言語公式ドキュメントを見ると、昔から「できる」と書かれていますが、実際にやった公開事例が見られなかったので今回挑戦してみました。
最近はC言語のソースをそのまま取り込む「ImportC」という機能が強化され続けていますが、C++とも直接連携できる、というのはかなり強みなのではないかと思っています。

実際やってみると、前回記事が思ったより細かく書かれていたため、特に詰まるところもなく我ながらとても助けられたように思います。

https://zenn.dev/lempiji/articles/7b620b0f007e1a

ちなみに今回の内容については一度下記ツイートでつぶやいているのですが、ゼロから書いて数十分で動くところまでは到達し、この記事のサンプルもほとんど1時間くらいで完成していました。

https://twitter.com/lempiji/status/1642184601891405824?s=20

一方で文章に関しては流行りのChatGPTと相談しながら試行錯誤していたのもあり、慣れずにかなり時間が掛かってしまったと思います。
今後はより素早く読みやすい文章が書けるかなと思いますので、改めて記事を書いていきたいと思います。

というわけで、今後ともD言語をよろしくお願いいたします！
