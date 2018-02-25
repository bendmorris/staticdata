package staticdata;

import yaml.util.ObjectMap;

class YamlTools
{
	public static function getChildren(node:AnyObjectMap, name:String):Array<AnyObjectMap>
	{
		if (!node.exists(name)) return [];
		else
		{
			var result = node.get(name);
			if (Std.is(result, Array)) return result;
			else return [result];
		}
	}

	public static function addParents(node:AnyObjectMap)
	{
		for (key in node.keys())
		{
			if (key == "__parent") continue;
			var val = node.get(key);
			if (Std.is(val, AnyObjectMap))
			{
				val.set("__parent", node);
				addParents(val);
			}
			else if (Std.is(val, Array))
			{
				var val:Array<Dynamic> = cast val;
				for (v in val)
				{
					if (Std.is(v, AnyObjectMap))
					{
						v.set("__parent", node);
						addParents(v);
					}
				}
			}
		}
	}
}
