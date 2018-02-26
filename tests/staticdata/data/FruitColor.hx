package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/fruit.yaml"], "colors"))
@:enum
abstract FruitColor(UInt) from UInt to UInt
{
	@:a public var name:String;
}
