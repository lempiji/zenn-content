#pragma once

namespace mylib2 {
	class TestActor {
	public:
		virtual void action() const; // 仮想関数
	};

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

	class PureFunctionActor {
	public:
		virtual void action() const = 0;
	};

	void execute_action(class mylib2::PureFunctionActor const* const obj) {
		obj->action();
	}
}
