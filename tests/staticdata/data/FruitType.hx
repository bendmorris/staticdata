package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/fruit.yaml"], "fruit"))
@:enum
abstract FruitType(String) from String to String
{
	@:a public var name:String;
	@:a public var colors:Array<FruitColor>;
}
