package staticdata;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import yaml.Yaml;
import yaml.Parser;
import yaml.util.ObjectMap;
import staticdata.Value;
using StringTools;
using staticdata.MacroUtil;
using staticdata.ValueTools;
using staticdata.YamlTools;

class YamlParser extends DataParser<AnyObjectMap>
{
	public function new() {}

	override public function parse(context:DataContext, path:String)
	{
		var data = sys.io.File.getContent(path);
		var yaml:AnyObjectMap = Yaml.parse(data);
		yaml.addParents();

		processNodes(context, path, getNodes(yaml, context.nodeName));
	}

	override function getValueFromNode(ct:ComplexType, fieldNames:Array<String>, node:AnyObjectMap):Null<Value>
	{
		var t = TypeTools.follow(ComplexTypeTools.toType(ct));

		function findSingleValue()
		{
			var f = find(node, fieldNames);
			if (f.length > 0)
			{
				return DataContext.getValue(t, f[0]);
			}
			return null;
		}

		switch (TypeTools.followWithAbstracts(t))
		{
			case TAbstract(a, params): switch (a.toString())
			{
				case "Int", "UInt", "Bool", "Float":
					return findSingleValue();
				default:
					throw "Unsupported value type: " + TypeTools.toString(t);
			}
			case TInst(c, params): switch (c.toString())
			{
				case "String", "Int", "UInt", "Bool", "Float":
					return findSingleValue();

				case "Array":
					var pt = params[0];
					var values:Array<Value> = new Array();
					var vals:Array<Dynamic> = cast find(node, fieldNames);
					if (vals != null)
					{
						for (v in vals)
						{
							values.push(DataContext.getValue(pt, v));
						}
					}
					return ArrayValue(values);

				case "haxe.ds.StringMap", "haxe.ds.IntMap":
					var ptKey = mapKeyType(c, t);
					var values:Map<Value, Value> = new Map();
					var pt = params[0];
					var val = find(node, fieldNames)[0];
					if (val != null)
					{
						var map:AnyObjectMap = cast val;
						for (key in map.keys())
						{
							if (key == "__parent") continue;
							var typedKey = DataContext.getValue(ptKey, key);
							values[typedKey] = DataContext.getValue(pt, map.get(key));
						}
					}
					return MapValue(values);

				default:
					throw "Unsupported value type: " + TypeTools.toString(t);
			}

			default:
				var val = findSingleValue();
				if (val == null) throw 'No value found for $t $fieldNames';
				return val;
		}
	}

	function find(node:AnyObjectMap, fieldNames:Array<String>):Array<Dynamic>
	{
		var values:Array<Dynamic> = new Array();
		for (fieldName in fieldNames)
		{
			if (fieldName.indexOf(".") > -1)
			{
				var parts = fieldName.split("."),
					rest = parts.slice(1).join(".");
				for (node in getNodes(node, parts[0]))
				{
					for (value in find(node, [rest]))
					{
						values.push(value);
					}
				}
			}
			while (fieldName.startsWith('^') && node != null)
			{
				fieldName = fieldName.substr(1);
				node = node.get("__parent");
			}
			if (node != null && node.exists(fieldName))
			{
				if (Std.is(node.get(fieldName), Array))
				{
					var a:Array<Dynamic> = cast node.get(fieldName);
					for (val in a) values.push(val);
				}
				else values.push(node.get(fieldName));
			}
		}
		return values;
	}

	override function getChildren(node:AnyObjectMap, name:String):Array<AnyObjectMap>
	{
		return node.getChildren(name);
	}

	override function exists(node:AnyObjectMap, key:String):Bool
	{
		return node.exists(key);
	}

	override function get(node:AnyObjectMap, key:String):Dynamic
	{
		return node.get(key);
	}
}
