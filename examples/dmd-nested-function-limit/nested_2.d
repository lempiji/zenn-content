auto test() {
    auto f0() {
        auto f1() {
            return 0;
        }
        return f1();
    }
    return f0();
}

void main() {
    import std.stdio;
    writeln(test());
}
