package hxdata;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.xml.Fast;
import hxdata.Value;
using hxdata.MacroUtil;
using hxdata.ValueTools;
using StringTools;

class XmlParser extends DataParser<Fast>
{
	public function new() {}

	override public function parse(context:DataContext, path:String)
	{
		var data = sys.io.File.getContent(path);
		var xml = Xml.parse(data);
		var fast = new Fast(xml.firstElement());

		processNodes(context, path, getNodes(fast, context.nodeName));
	}

	override function getValueFromNode(ct:ComplexType, fieldNames:Array<String>, node:Fast):Null<Value>
	{
		var t = TypeTools.followWithAbstracts(ComplexTypeTools.toType(ct));

		inline function findSingleValue()
		{
			var values = findValues(node, fieldNames, false);
			return values.length > 0 ? values[0] : null;
		}

		switch (t)
		{
			case TInst(c, params): switch (c.toString())
			{
				case "String":
					var v = findSingleValue();
					return v == null ? null : DataContext.getValue(t, v);
				case "Array":
					var pt = params[0];
					return ArrayValue([for (value in findValues(node, fieldNames, true)) DataContext.getValue(pt, value)]);
				case "haxe.ds.StringMap":
					var ptKey = mapKeyType(c, t);
					var values:Map<Value, Value> = new Map();
					var pt = params[0];
					for (fieldName in fieldNames)
					{
						for (att in node.x.attributes())
						{
							if (att.startsWith(fieldName + ":") ||
								att.startsWith(fieldName + "-"))
							{
								var key = att.substr(fieldName.length + 1);
								var val = node.att.resolve(att);
								values[ConcreteValue(key)] = DataContext.getValue(pt, val);
							}
						}
						for (childNode in node.nodes.resolve(fieldName))
						{
							var key = DataContext.getValue(ptKey, findOneOf(childNode, ["key", "type"]));
							var val = childNode.has.value ? childNode.att.value : childNode.innerHTML;
							values[key] = DataContext.getValue(pt, val);
						}
					}
					return MapValue(values);
				default:
					throw "Unsupported value type: " + TypeTools.toString(t);
			}

			default:
				var val = findSingleValue();
				return (val == null) ? null : DataContext.getValue(t, val);
		}
	}

	function findValues(node:Fast, fieldNames:Array<String>, array:Bool=false):Array<String>
	{
		var values:Array<String> = new Array();
		for (fieldName in fieldNames)
		{
			if (fieldName.indexOf(".") > -1)
			{
				var parts = fieldName.split("."),
					rest = parts.slice(1).join(".");
				for (node in getNodes(node, parts[0]))
				{
					for (value in findValues(node, [rest], array))
					{
						values.push(value);
					}
				}
				continue;
			}
			while (fieldName.startsWith('^'))
			{
				fieldName = fieldName.substr(1);
				node = new Fast(node.x.parent);
			}
			if (node.has.resolve(fieldName))
			{
				if (array)
				{
					for (v in node.att.resolve(fieldName).split(",")) values.push(v);
				}
				else values.push(node.att.resolve(fieldName));
			}
			else if (node.hasNode.resolve(fieldName))
			{
				for (childNode in node.nodes.resolve(fieldName))
				{
					if (childNode.has.value) values.push(childNode.att.value);
					else if (childNode.innerHTML.length > 0) values.push(childNode.innerHTML);
				}
			}
		}
		return values;
	}

	static function findOneOf(node:Fast, atts:Array<String>)
	{
		for (att in atts)
		{
			if (node.has.resolve(att))
			{
				return node.att.resolve(att);
			}
		}
		throw "Couldn't find a supported attribute (" + atts.join(", ") + ")";
	}

	override function getChildren(node:Fast, name:String):Array<Fast>
	{
		return [for (child in node.nodes.resolve(name)) child];
	}

	override function exists(node:Fast, key:String):Bool
	{
		return node.has.resolve(key);
	}

	override function get(node:Fast, key:String):Dynamic
	{
		return node.att.resolve(key);
	}
}
