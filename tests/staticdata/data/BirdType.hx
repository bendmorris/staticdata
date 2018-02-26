package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/birds.yaml"], "birds"))
@:enum
abstract BirdType(Int) from Int to Int
{
	@:a public var name:String = "???";
}
