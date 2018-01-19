package hxdata;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import yaml.Yaml;
import yaml.Parser;
import yaml.util.ObjectMap;
import hxdata.Value;
using StringTools;
using hxdata.MacroUtil;
using hxdata.ValueTools;
using hxdata.YamlTools;

class YamlParser implements DataParser
{
	public function new() {}

	public function parse(context:DataContext, path:String)
	{
		var pos = Context.currentPos().label('hxdata:$path');
		var data = sys.io.File.getContent(path);
		var yaml:AnyObjectMap = Yaml.parse(data);
		yaml.addParents();

		for (node in getNodes(yaml, context.nodeName))
		{
			++context.nodeCount;
			var id:String = node.exists("id") ? node.get("id") : context.nodeName + (++context.autoId);
			switch (DataContext.getValue(ComplexTypeTools.toType(macro :String), id))
			{
				case ConcreteValue(s): {}
				default:
					throw 'Id field must contain only concrete values; found "$id"';
			}

			var name = id.titleCase();
			var ident = FieldValue(context.abstractType.name, name);
			var value:Value;
			if (node.exists("value"))
			{
				value = DataContext.getValue(ComplexTypeTools.toType(context.abstractComplexType), node.get("value"), false);
			}
			else
			{
				value = context.defaultValue(id);
			}
			context.ordered.push(ident);
			context.newFields.push({
				name: name,
				doc: null,
				meta: MacroUtil.enumMeta,
				access: [],
				kind: FVar(context.abstractComplexType, macro ${value.valToExpr()}),
				pos: pos,
			});

			for (field in context.dataFields.keys())
			{
				var ct = DataContext.getFieldType(field);
				var fieldNames = context.dataFields[field];
				var val = getValueFromNode(ct, fieldNames, node);
				if (val != null) context.values[field][ident] = val;
			}

			for (field in context.indexFields.keys())
			{
				var ct = DataContext.getIndexType(field);
				var indexNames = context.indexFields[field];
				var val = getValueFromNode(ct, indexNames, node);
				if (val != null)
				{
					var added:Bool = false;
					for (indexDef in context.indexes[field])
					{
						if (indexDef.value.valToStr() == val.valToStr())
						{
							indexDef.items.push(ident);
							added = true;
							break;
						}
					}
					if (!added)
					{
						context.indexes[field].push({
							value: val,
							items: [ident],
						});
					}
				}
			}
		}
	}

	static function getValueFromNode(ct:ComplexType, fieldNames:Array<String>, node:AnyObjectMap):Null<Value>
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
					var ptKey = ComplexTypeTools.toType(switch (c.toString())
					{
						case "haxe.ds.IntMap": macro : Int;
						default: macro : String;
					});
					switch (t)
					{
						case TAbstract(a, params):
							if (a.toString() == "Map")
							{
								ptKey = params[0];
							}
						default: {}
					}
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

	static function find(node:AnyObjectMap, fieldNames:Array<String>):Array<Dynamic>
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

	static function getNodes(node:AnyObjectMap, nodeName:String):Array<AnyObjectMap>
	{
		if (nodeName.indexOf(".") > -1)
		{
			var parts = nodeName.split(".");
			var rest = parts.slice(1).join(".");
			return [for (child in node.getChildren(parts[0])) for (node in getNodes(child, rest)) node];
		}
		else
		{
			return [for (child in node.getChildren(nodeName)) child];
		}
	}
}
