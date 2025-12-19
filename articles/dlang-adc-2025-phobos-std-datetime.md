---
title: "D言語標準ライブラリ紹介：std.datetime"
emoji: "📚"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["dlang", "library"]
published: false
---

## はじめに

この記事は **Qiita「D言語 Advent Calendar 2025」9日目** の記事です。

https://qiita.com/advent-calendar/2025/dlang

Phobosのモジュールを「サクッと・よく使うところ中心に」紹介するシリーズとして、今回は `std.datetime` を取り上げます。

## `std.datetime` 紹介

https://dlang.org/phobos/std_datetime.html

`std.datetime` は、Dの **日時（時刻点）・タイムゾーン・時間間隔（Duration）** といったデータと、**計測（StopWatch）** をひとまとめに扱えるモジュールです。

いくつかのサブモジュールがありますが、基本は `std.datetime` 本体のインポートで大体使えます。使用頻度の割に使えないものもあるので、後程紹介します。

この記事では、使用頻度や遭遇率が高い順に **7機能** 紹介します。

## 機能別ミニ解説

### 1. `Clock` / `SysTime`

`Clock` 型は時刻取得に関する時計型で、`Clock.currTime()` という現在日時を取得する関数を提供します。この `Clock.currTime()` は現在時刻を `SysTime` という日時データとして取得するものです。

`SysTime` は **タイムゾーン込みの日時** を表し、システム時刻をそのまま表現できます。
ログのタイムスタンプなど、何かの瞬間を表す点としては `SysTime` としておけば安全です。

**使用例**

```d global name=clock_systime_example
import std.stdio;
import std.datetime : Clock, SysTime;

void main()
{
    SysTime now = Clock.currTime();
    writeln(now);
}
```


### 2. `UTC` / `LocalTime`

`SysTime` と合わせて使うのが `UTC()` と `LocalTime()` です。これらはタイムゾーンを表す型で、`SysTime` の表示や解釈に影響します。日本なら `UTC+9` ですね。

`Clock.currTime()` の引数に好きなタイムゾーンを渡すと、そのタイムゾーンでの現在時刻を取得できます。
また、相互変換も `SysTime` の `toLocalTime()` / `toUTC()` メソッドで可能です。


**使用例**

```d global name=utc_localtime_example
import std.stdio;
import std.datetime : Clock, UTC;

void main()
{
    auto localNow = Clock.currTime(); // 既定はローカルタイムゾーン
    auto utcNow   = Clock.currTime(UTC()); // 指定すれば任意のタイムゾーン

    writeln(localNow);
    writeln(utcNow);

    auto localNow2 = utcNow.toLocalTime(); // UTC→ローカル変換
    auto utcNow2   = localNow.toUTC(); // ローカル→UTC変換
}
```


### 3. `DateTime` / `Date` / `TimeOfDay`

`Date` は日付、`TimeOfDay` は時刻（時分秒）、`DateTime` はその複合で日時型です。
共通点は **タイムゾーンの概念が無い** こと、つまり地域を問わない「カレンダー上の時点」を表す型です。

値の作り方がちょっとややこしいのですが、`DateTime/Date/TimeOfDay` はすべて `SysTime` からキャストで変換して作ることができます。
`Date/TimeOfDay` は `DateTime` の `date` / `timeOfDay` プロパティから作れます。
また、各型はコンストラクタで個別に作ることもできます。
以下具体例です。

**使用例**

```d global name=datetime_example
import std.stdio;
import std.datetime : Clock, Date, TimeOfDay, DateTime;

void main()
{
    // 現在時刻を取得してDateTime/Date/TimeOfDayを取り出す
    DateTime dt = cast(DateTime) Clock.currTime();
    auto d = dt.date;
    auto t = dt.timeOfDay;

    writeln(d);
    writeln(t);
    writeln(dt);
}
```


### 4. `toISOExtString` / `fromISOExtString`

`toISOExtString()` は `SysTime` や `DateTime` の値を「ISO 8601 の拡張形式」（`YYYY-MM-DDTHH:MM:SS`）へ整形するメソッドです。逆に `fromISOExtString()` はそれをパースして戻します。
日本人的には他の文字列変換よりも読みやすいのでおすすめです。

ちなみに結果の文字列はタイムゾーンで変わるところがあり、`SysTime` 側の `toISOExtString()` では、UTCなら末尾に `Z` が付き、ローカルタイムゾーンだと何も付きません。

**使用例**

```d global name=isoextstring_example
import std.datetime : DateTime;

void main()
{
    auto dt  = DateTime(2012, 2, 29, 23, 59, 59);
    auto s   = dt.toISOExtString();
    auto dt2 = DateTime.fromISOExtString(s);

    assert(dt2 == dt);
}
```


### 5. `Duration`

`Duration` は「3秒」「250ミリ秒」みたいな **時間の長さ** を表す型です。
分かりやすいところでは様々な設定値、タイムアウトでもリトライ間隔でも使いどころは大変多いです。

`std.datetime` の世界では、日付型の差分でだいたい `Duration` が出てきますし、日時型に対する可算減算で直感的に時刻調整ができます。
また、`30.seconds` や `1.minutes` のようにリテラル風に書くこともできる機能があり、ちょっとしたスクリプトで使えると満足度が高くなるのでおすすめです。

**使用例**

```d global name=duration_example
import std.stdio;
import std.datetime; // Clock, DateTime, weeks

void main()
{
    auto now = Clock.currTime();

    // 2週間後はいつ？
    auto later = now + 2.weeks;
    writeln("2 weeks later: ", later.toISOExtString());
    
    // 2000年1月1日からの経過時間を計算
    auto from = SysTime(DateTime(2000, 1, 1, 0, 0, 0));
    auto diff = now - from; // SysTime同士の差分はDuration
    writeln("Duration since Y2K: ", diff);

    // 何日間？
    writeln("Days since Y2K: ", diff.total!"days");
}
```


### 6. `StopWatch`

`StopWatch` は **精度よく処理時間を測るため** の型です。これまでの `Clock` ではなく、計測向けの高精度タイマーを使って「開始→停止→経過取得」ができます。使いまわしのためのリセットも可能です。

ベンチマークを書くのに計測部分で必須なほか、一定時間処理するような時には経過時間を算出するのにも使えます。

注意としては、`StopWatch` は **`std.datetime` だけでは使用できず、`std.datetime.stopwatch` の public import が必要** ということです。

**使用例**

```d global name=stopwatch_example
import std.stdio;
import std.datetime.stopwatch : StopWatch; // 明示的なサブモジュールのimport

void main()
{
    StopWatch sw;

    sw.start();
    foreach (i; 0 .. 1_000_000) {}
    sw.stop();

    writeln(sw.peek());
    writeln(sw.peek().total!"msecs"); // 経過時間を合計ミリ秒で取得
}
```


### 7. `toUnixTime` / `fromUnixTime`

`SysTime` には、Unix time（1970-01-01 UTC からの秒）との相互変換が可能なAPIとして、`toUnixTime()` / `fromUnixTime()` があります。罠っぽいですが `DateTime` にはありません。

CやOSのAPI、データベース、他言語との境界で Unix time を扱うことがありますが、そういうときに便利です。

**使用例**

```d
import std.datetime;

void main()
{
    long unix = 1_700_000_000;          // 例：epoch秒

    SysTime t = SysTime.fromUnixTime(unix); // Unix time → SysTime
    long unix2 = t.toUnixTime();        // SysTime → Unix time
    assert(unix2 == unix);
}
```

---

## まとめ

というわけで、`std.datetime` の紹介でした。
「**特定の日時（SysTime）**」「**カレンダー値（DateTime）**」「**時間間隔（Duration）**」の3つを押さえれば基本的な利用は大体問題なくなります。

良く使うので覚えておきたいところは以下になります。

* 時刻の取得は `Clock.currTime()`、日時は `SysTime` で扱うのが基本
* タイムゾーンに悩んだら `UTC()` を渡す
* カレンダー的な日付の意味なら `DateTime` / `Date` / `TimeOfDay`
* 文字列化は `toISOExtString` / `fromISOExtString` が読みやすい
* 時間の長さは `Duration`
* 処理時間は `StopWatch` (`public import std.datetime.stopwatch` が必要)
* epoch秒と行き来するなら `SysTime` の `toUnixTime()` / `fromUnixTime()`

公式ドキュメントも参考に、ぜひ `std.datetime` を活用してみてください。

https://dlang.org/phobos/std_datetime.html