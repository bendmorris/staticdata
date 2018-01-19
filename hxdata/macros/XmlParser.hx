package hxdata.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.xml.Fast;
import hxdata.Value;
using hxdata.macros.MacroUtil;
using hxdata.macros.ValueTools;
using StringTools;

class XmlParser implements DataParser
{
	public function new() {}

	public function parse(context:DataContext, path:String)
	{
		var pos = Context.currentPos();
		var data = sys.io.File.getContent(path);
		var xml = Xml.parse(data);
		var fast = new Fast(xml.firstElement());

		for (node in getNodes(fast, context.nodeName))
		{
			++context.nodeCount;
			var id:String = node.has.id ? node.att.id : context.nodeName + (++context.autoId);
			switch (DataContext.getValue(ComplexTypeTools.toType(macro :String), id))
			{
				case ConcreteValue(s): {}
				default:
					throw 'Id field must contain only concrete values; found "$id"';
			}

			var name = id.titleCase();
			var value = node.has.value ? DataContext.getValue(ComplexTypeTools.toType(context.abstractComplexType), node.att.value) : ConcreteValue(id);
			context.ordered.push(value);
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
				if (val != null) context.values[field][value] = val;
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
							indexDef.items.push(value);
							added = true;
							break;
						}
					}
					if (!added)
					{
						context.indexes[field].push({
							value: val,
							items: [value],
						});
					}
				}
			}
		}
	}

	static function getValueFromNode(ct:ComplexType, fieldNames:Array<String>, node:Fast):Null<Value>
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
							var key = findOneOf(childNode, ["key", "type"]);
							var val = childNode.has.value ? childNode.att.value : childNode.innerHTML;
							values[ConcreteValue(key)] = DataContext.getValue(pt, val);
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

	static function findValues(node:Fast, fieldNames:Array<String>, array:Bool=false):Array<String>
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

	static function getNodes(fast:Fast, nodeName:String):Array<Fast>
	{
		if (nodeName.indexOf(".") > -1)
		{
			var parts = nodeName.split(".");
			var rest = parts.slice(1).join(".");
			return [for (child in fast.nodes.resolve(parts[0])) for (node in getNodes(child, rest)) node];
		}
		else return [for (node in fast.nodes.resolve(nodeName)) node];
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
}
