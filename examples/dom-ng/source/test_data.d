module test_data;

struct Main
{
	NodeA a;
	NodeA2 a2;
}

struct NodeA
{
	NodeB b;
}

struct NodeA2
{
	double d;
	NodeB b;
}

struct NodeB
{
	int i;
	float f;
}

Main m;