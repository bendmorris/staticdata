package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/upgrades.yaml"], "category.upgrades"))
@:enum
abstract UpgradeType(String) from String to String
{
	@:a("^id") public var category:UpgradeCategory;
	@:a public var name:String;
	@:a public var cost:Int = 0;
}
