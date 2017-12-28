package hxdata;

import hxdata.data.TestModel1;

class DataEnumTest extends TestCase
{
	public function testFields()
	{
		assertEquals("xml_abc", TestModel1.XmlAbc);
		assertEquals("xml_def_ghi", TestModel1.XmlDefGhi);
		//assertEquals("json_abc", TestModel1.JsonAbc);
		//assertEquals("json_def_ghi", TestModel1.JsonDefGhi);
		assertEquals("yaml_abc", TestModel1.YamlAbc);
		assertEquals("yaml_def_ghi", TestModel1.YamlDefGhi);
		assertArrayEquals(
			[
				TestModel1.XmlAbc, TestModel1.XmlDefGhi,
				//TestModel1.JsonAbc, TestModel1.JsonDefGhi,
				TestModel1.YamlAbc, TestModel1.YamlDefGhi
			],
			TestModel1.ordered
		);

		// XML
		assertEquals(1, TestModel1.XmlAbc.field1);
		assertEquals("defaultval", TestModel1.XmlAbc.field2);
		assertArrayEquals([3, 2, 1], TestModel1.XmlAbc.field3);
		assertMapEquals(new Map(), TestModel1.XmlAbc.field4);
		assertEquals("xml_parentId", TestModel1.XmlAbc.field5);

		assertEquals(0, TestModel1.XmlDefGhi.field1);
		assertEquals("customval", TestModel1.XmlDefGhi.field2);
		assertArrayEquals([], TestModel1.XmlDefGhi.field3);
		assertMapEquals(["apple" => true, "banana" => false], TestModel1.XmlDefGhi.field4);
		assertEquals("xml_parentId", TestModel1.XmlDefGhi.field5);

		/*// JSON
		assertEquals(1, TestModel1.JsonAbc.field1);
		assertEquals("defaultval", TestModel1.JsonAbc.field2);
		assertArrayEquals([3, 2, 1], TestModel1.JsonAbc.field3);
		assertMapEquals(new Map(), TestModel1.JsonAbc.field4);
		assertEquals("json_parentId", TestModel1.JsonAbc.field5);

		assertEquals(0, TestModel1.JsonDefGhi.field1);
		assertEquals("customval", TestModel1.JsonDefGhi.field2);
		assertArrayEquals([], TestModel1.JsonDefGhi.field3);
		assertMapEquals(["apple" => true, "banana" => false], TestModel1.JsonDefGhi.field4);
		assertEquals("json_parentId", TestModel1.JsonDefGhi.field5);*/

		// YAML
		assertEquals(1, TestModel1.YamlAbc.field1);
		assertEquals("defaultval", TestModel1.YamlAbc.field2);
		assertArrayEquals([3, 2, 1], TestModel1.YamlAbc.field3);
		assertMapEquals(new Map(), TestModel1.YamlAbc.field4);
		assertEquals("yaml_parentId", TestModel1.YamlAbc.field5);

		assertEquals(0, TestModel1.YamlDefGhi.field1);
		assertEquals("customval", TestModel1.YamlDefGhi.field2);
		assertArrayEquals([], TestModel1.YamlDefGhi.field3);
		assertMapEquals(["apple" => true, "banana" => false], TestModel1.YamlDefGhi.field4);
		assertEquals("yaml_parentId", TestModel1.YamlDefGhi.field5);
	}
}
