// MyLib2.cpp : スタティック ライブラリ用の関数を定義します。
//

#include "pch.h"
#include "framework.h"
#include "mylib2.h"
#include <iostream>

void mylib2::TestActor::action() const
{
	std::cout << "TestActor" << std::endl;
}

void mylib2::TestActor2::action() const
{
	std::cout << "TestActor2" << std::endl;
}
