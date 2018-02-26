class Test extends haxe.unit.TestRunner
{
	static function main()
	{
		#if !macro
		var r = new haxe.unit.TestRunner();
		r.add(new staticdata.ValueTest());
		r.add(new staticdata.DataModelTest());
		r.add(new staticdata.ExamplesTest());
		r.run();
		#end
	}

	public static function assertArrayEquals<T>(t:TestCase, a1:Array<T>, a2:Array<T>)
	{
		t.assertEquals(a1.length, a2.length);
		for (i in 0 ... a1.length)
		{
			t.assertEquals(a1[i], a2[i]);
		}
	}

	public static function assertMapEquals<K, V>(t:TestCase, m1:Map<K, V>, m2:Map<K, V>)
	{
		t.assertEquals([for (k in m1.keys()) k].length, [for (k in m2.keys()) k].length);
		for (key in m1.keys())
		{
			t.assertTrue(m2.exists(key));
			t.assertEquals(m1.get(key), m2.get(key));
		}
	}
}
