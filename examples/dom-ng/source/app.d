int main(string[] args)
{
	import unit_threaded;

	return args.runTests!(
		"test",
		"test2",
		"test_fiber",
	);
}
