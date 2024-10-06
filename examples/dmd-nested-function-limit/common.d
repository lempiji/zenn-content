import std.range;
import std.traits;
import std.algorithm;
import std.functional;

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

unittest
{
    int[] arr = [1, 5, 8, 12, 20, 33, 42, 55, 68, 72, 88];
    
    // Test case where the predicate is true for the first element
    auto index1 = bsearch!"a > 0"(arr);
    assert(index1 == 0);
    
    // Test case where the predicate is true for the last element
    auto index2 = bsearch!"a > 88"(arr);
    assert(index2 == 10);
    
    // Test case where the predicate is true for all elements
    auto index3 = bsearch!"a > -1"(arr);
    assert(index3 == 0);
    
    // Test case where the predicate is false for all elements
    auto index4 = bsearch!"a > 100"(arr);
    assert(index4 == -1);
    
    // Test case where the array is empty
    int[] emptyArr;
    auto index5 = bsearch!"a > 0"(emptyArr);
    assert(index5 == -1);
}