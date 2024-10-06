module mylib2;
 import core.stdcpp.memory;

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
	
    class PureFunctionActor {
        abstract void action() const;
    }

    void execute_action(const PureFunctionActor obj);
}