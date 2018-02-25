package staticdata;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import staticdata.Value;
using StringTools;
using staticdata.MacroUtil;
using staticdata.ValueTools;
using staticdata.YamlTools;

interface IDataParser
{
	public function parse(context:DataContext, path:String):Void;
}

class DataParser<T> implements IDataParser
{
	public function parse(context:DataContext, path:String):Void
	{
		throw "not yet implemented";
	}

	function getNodes(node:T, nodeName:String):Array<T>
	{
		if (nodeName.indexOf(".") > -1)
		{
			var parts = nodeName.split(".");
			var rest = parts.slice(1).join(".");
			return [for (child in getChildren(node, parts[0])) for (node in getNodes(child, rest)) node];
		}
		else return [for (child in getChildren(node, nodeName)) child];
	}

	function getChildren(node:T, name:String):Array<T> throw "not yet implemented";
	function exists(node:T, key:String):Bool throw "not yet implemented";
	function get(node:T, key:String):Dynamic throw "not yet implemented";
	function getValueFromNode(ct:ComplexType, fieldNames:Array<String>, node:T):Null<Value> throw "not yet implemented";

	function mapKeyType(c:Ref<ClassType>, t:Type)
	{
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
		return ptKey;
	}

	function processNodes(context:DataContext, path:String, nodes:Array<T>)
	{
		var pos = Context.currentPos().label('staticdata:$path');

		for (node in nodes)
		{
			++context.nodeCount;
			var id:String = exists(node, "id") ? get(node, "id") : context.nodeName + (++context.autoId);
			switch (DataContext.getValue(ComplexTypeTools.toType(macro :String), id))
			{
				case ConcreteValue(s): {}
				default:
					throw 'Id field must contain only concrete values; found "$id"';
			}

			var name = id.titleCase();
			var ident = FieldValue(context.abstractType.name, name);
			var value:Value;
			if (exists(node, "value"))
			{
				value = DataContext.getValue(ComplexTypeTools.toType(context.abstractComplexType), get(node, "value"), false);
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
}
