package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/test_model2.yaml"], "test_model2"))
@:enum
abstract TestModel2(String) from String to String
{
	@:a(mod3.id) public var mod3:TestModel3;
}
