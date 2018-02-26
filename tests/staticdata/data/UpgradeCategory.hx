package staticdata.data;

@:build(staticdata.DataModel.build(["tests/data/upgrades.yaml"], "category"))
@:enum
abstract UpgradeCategory(String) from String to String
{
	@:a public var icon:Null<String> = null;
	@:a(upgrades.id) public var upgrades:Array<UpgradeType>;
}
