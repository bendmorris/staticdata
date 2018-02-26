package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/test_model2.yaml"], "test_model2.mod3"))
@:enum
abstract TestModel3(Int) from Int to Int
{
	@:index(name) public static var byName:Map<String, Array<TestModel3>>;
	@:index(color) public static var byColor:Map<String, Array<TestModel3>>;

	@:a public var name:String;
	@:a public var color:String;
}
