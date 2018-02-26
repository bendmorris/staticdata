package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/dogs.yaml"], "breed"))
@:enum
abstract DogBreed(String) from String to String
{
	@:index(color) public static var byColor:Map<UInt, Array<DogBreed>>;

	@:a public var name:String = "???";
	@:a(synonym) public var synonyms:Array<String>;
	@:a public var color:UInt;
	@:a(stat) public var stats:Map<String, Int>;
}
