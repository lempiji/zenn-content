import std.stdio;
import mylib2;

void main()
{
	TestActor actor = new CustomActor;
	execute_action(actor);
	
	TestActor2 actor2 = new CustomActor2;
	execute_action(actor2);

	PureFunctionActor actor3 = new CustomPureFunctionActor;
	execute_action(actor3);
}

extern(C++) class CustomActor : TestActor {
	override void action() const {
		import std.stdio;

		writeln("CustomActor!");
	}
}

extern(C++, struct) class CustomActor2 : TestActor2 {
	override void action() const {
		import std.stdio;

		writeln("CustomActor2!");
	}
}

extern(C++) class CustomPureFunctionActor : PureFunctionActor {
	override void action() const {
		import std.stdio;

		writeln("CustomPureFunctionActor");
	}
}