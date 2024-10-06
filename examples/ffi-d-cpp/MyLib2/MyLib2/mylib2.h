#pragma once

namespace mylib2 {
	class TestActor {
	public:
		virtual void action() const; // ���z�֐�
	};

	struct TestActor2 {
	public:
		virtual void action() const; // ���z�֐�
	};

	void execute_action(class mylib2::TestActor const* const obj) {
		obj->action(); // ���z�֐��̌Ăяo���A�p������Ă���Γ��삪�ς��|�C���g
	}

	void execute_action(struct mylib2::TestActor2 const* const obj) {
		obj->action(); // ���z�֐��̌Ăяo���A�p������Ă���Γ��삪�ς��|�C���g
	}

	class PureFunctionActor {
	public:
		virtual void action() const = 0;
	};

	void execute_action(class mylib2::PureFunctionActor const* const obj) {
		obj->action();
	}
}
