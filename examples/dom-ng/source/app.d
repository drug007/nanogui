int main(string[] args)
{
	import unit_threaded;

	return args.runTests!(
		"test3",
		"test2",
		"test_fiber",
	);
}
