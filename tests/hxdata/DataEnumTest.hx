package hxdata;

import hxdata.data.TestModel1;

class DataEnumTest extends TestCase
{
	public function testFields()
	{
		assertEquals("abc", TestModel1.Abc);
		assertEquals("def_ghi", TestModel1.DefGhi);
		assertArrayEquals([TestModel1.Abc, TestModel1.DefGhi], TestModel1.ordered);

		assertEquals(1, TestModel1.Abc.field1);
		assertEquals("defaultval", TestModel1.Abc.field2);
		assertArrayEquals([3, 2, 1], TestModel1.Abc.field3);
		assertMapEquals(new Map(), TestModel1.Abc.field4);
		assertEquals("parentId", TestModel1.Abc.field5);

		assertEquals(0, TestModel1.DefGhi.field1);
		assertEquals("customval", TestModel1.DefGhi.field2);
		assertArrayEquals([], TestModel1.DefGhi.field3);
		assertMapEquals(["apple" => true, "banana" => false], TestModel1.DefGhi.field4);
		assertEquals("parentId", TestModel1.DefGhi.field5);
	}
}
