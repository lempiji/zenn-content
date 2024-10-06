module crush_nestfunc;

import common;
import std;

void main()
{
    // testCrunshNestfunc(7000);
    auto result = iota(6300, 7000).bsearch!testCrunshNestfunc;
    writeln(result);
}

string makeNestedFuncSource(size_t nestLevel)
{
    string source;
    source ~= "auto test() {\n";
    foreach (i; 0 .. nestLevel)
    {
        source ~= "auto f" ~ i.to!string ~ "() {\n";
    }
    source ~= "return 0;\n";
    foreach_reverse (i; 0 .. nestLevel)
    {
        source ~= "}\n";
        source ~= "return f" ~ i.to!string ~ "();\n";
    }
    source ~= "}\n";
    return source;
}

bool testCrunshNestfunc(size_t nestLevel)
{
    write("nestLevel: ", nestLevel, " => ");
    auto source = makeNestedFuncSource(nestLevel);
    {
        auto f = File("nestedFunc.d", "w");
        f.writeln(source);
        f.writeln("void main() {");
        f.writeln("import std.stdio;");
        f.writeln("writeln(test());");
        f.writeln("}");
    }
    scope (exit) std.file.remove("nestedFunc.d");

    try
    {
        auto p = spawnShell("ldc2 -run nestedFunc.d");
        auto statusCode = p.wait();
        writeln(statusCode == 0 ? "OK" : "NG");
        return statusCode != 0;
    }
    catch (Exception e)
    {
        write("NG");
        return true;
    }
}