package xmldata.macros;

import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.xml.Fast;
import sys.FileSystem;
using xmldata.macros.MacroUtil;
using StringTools;

typedef IndexDef = {
	var value:Dynamic;
	var items:Array<String>;
}

/**
 * Used to define an enum abstract with variants from an XML data file.
 */
class DataEnum
{
	public static function build(?dataFiles:Array<String>, ?nodeName:String)
	{
		var fields = Context.getBuildFields();
		var newFields:Array<Field> = new Array();

		// figure out what type we're building
		var type = Context.getLocalType();
		var meta:MetaAccess,
			typeName:String,
			abstractType:AbstractType;
		switch (type)
		{
			case TInst(t, params):
				var classType = t.get();
				switch (classType.kind)
				{
					case KAbstractImpl(a):
						abstractType = a.get();
						typeName = abstractType.name;
						meta = abstractType.meta;
					default: throw "Unsupported type for DataEnum: " + type;
				}
			default:
				throw "Unsupported type for DataEnum: " + type;
		}
		var abstractComplexType = TPath({name: typeName, pack: abstractType.pack, params: null});

		// find the data files to parse
		if (dataFiles == null) dataFiles = new Array();
		var pathMeta = meta.extract(":dataPath");
		if (pathMeta.length > 0)
		{
			for (m in pathMeta)
			{
				var p = m.params;
				if (p == null) throw "Empty @:dataPath on DataEnum " + abstractType.name;
				else if (p[0].ident() != null) dataFiles.push(p[0].ident());
				else throw "Bad @:dataPath on DataEnum " + abstractType.name + ": " + p[0].expr;
			}
		}
		if (nodeName == null)
		{
			var nodeNameMeta = meta.extract(":dataNode");
			if (nodeNameMeta.length == 0) nodeName = typeName.snakeCase();
			else
			{
				for (m in nodeNameMeta)
				{
					var p = m.params;
					if (p == null) throw "Empty @:dataNode on DataEnum " + abstractType.name;
					nodeName = p[0].ident();
					break;
				}
			}
		}

		var fasts:Array<Fast> = new Array();
		for (dataFile in dataFiles)
		{
			var paths:Array<String>;
			if (dataFile.indexOf("*") > -1)
			{
				paths = expandPath(Path.normalize(dataFile));
			}
			else paths = [dataFile];
			for (path in paths)
			{
				#if debug
				trace('${abstractType.name}: parsing data from $path');
				#end
				var data = sys.io.File.getContent(Context.resolvePath(path));
				var xml = Xml.parse(data);
				fasts.push(new Fast(xml.firstElement()));
			}
		}
		if (fasts.length == 0)
		{
			throw "No data files specified for DataEnum " + abstractType.name + "; search paths: " + dataFiles.join(", ");
		}

		// find the fields to generate
		// these fields will generate read-only fields with getters to retrieve the value for each variant
		var xmlFields:Map<Field, Array<String>> = new Map();
		// fields marked with @:inlineField will always use a switch with the getter inlined
		var inlineFields:Map<Field, Bool> = new Map();
		// fields marked with @:index will build index maps based on the specified attribute
		var indexFields:Map<Field, Array<String>> = new Map();
		for (field in fields)
		{
			var isSpecialField:Bool = false;
			for (m in field.meta)
			{
				if (m.name == ':a')
				{
					isSpecialField = true;
					var fieldNames:Array<String> = new Array();
					inline function addFieldName(s:String)
					{
						if (fieldNames.indexOf(s) == -1) fieldNames.push(s);
					}
					for (param in m.params)
					{
						var i = param.ident();
						if (i != null) addFieldName(i);
					}
					addFieldName(field.name);
					addFieldName(field.name.camelCase());
					addFieldName(field.name.snakeCase());
					xmlFields[field] = fieldNames;
					break;
				}
				else if (m.name == ':index')
				{
					isSpecialField = true;
					var indexNames:Array<String> = new Array();
					inline function addIndexName(s:String)
					{
						if (indexNames.indexOf(s) == -1) indexNames.push(s);
					}
					for (param in m.params)
					{
						var i = param.ident();
						if (i == null) throw "Unrecognized index field: " + param;
						addIndexName(i);
					}
					addIndexName(field.name);
					addIndexName(field.name.camelCase());
					addIndexName(field.name.snakeCase());
					indexFields[field] = indexNames;
				}
				else if (m.name == ':inlineField')
				{
					if (!xmlFields.exists(field)) throw '@:inlineField field needs a @:a tag first (${abstractType.name}::${field.name})';
					inlineFields[field] = true;
				}
			}
			if (!isSpecialField)
			{
				newFields.push(field);
			}
		}

		var ordered:Array<Dynamic> = new Array();
		var indexes:Map<Field, Array<IndexDef>> = [
			for (field in indexFields.keys()) field => new Array()
		];
		var values:Map<Field, Map<String, Dynamic>> = [
			for (field in xmlFields.keys()) field => new Map()
		];
		var autoId:Int = 0;
		var nodeCount:Int = 0;
		for (fast in fasts)
		{
			for (node in getNodes(fast, nodeName))
			{
				++nodeCount;
				var id:String = node.has.id ? node.att.id : nodeName + (++autoId);
				var name = id.titleCase();
				var value = node.has.value ? node.att.value : id;
				ordered.push(value);
				newFields.push({
					name: name,
					doc: null,
					meta: MacroUtil.enumMeta,
					access: [],
					kind: FVar(abstractComplexType, macro $v{value}),
					pos: Context.currentPos(),
				});

				for (field in xmlFields.keys())
				{
					var ct = getFieldType(field);
					var fieldNames = xmlFields[field];
					var val = getValueFromNode(ct, fieldNames, node);
					if (val != null) values[field][value] = val;
				}

				for (field in indexFields.keys())
				{
					var ct = getIndexType(field);
					var indexNames = indexFields[field];
					var val = getValueFromNode(ct, indexNames, node);
					if (val != null)
					{
						var added:Bool = false;
						for (indexDef in indexes[field])
						{
							if (indexDef.value == val)
							{
								indexDef.items.push(value);
								added = true;
								break;
							}
						}
						if (!added)
						{
							indexes[field].push({
								value: val,
								items: [value],
							});
						}
					}
				}
			}
		}

		if (nodeCount == 0)
		{
			throw "No valid nodes found for DataEnum " + abstractType.name;
		}

		newFields.insert(0, {
			name: "ordered",
			doc: null,
			meta: [],
			access: [AStatic, APublic],
			kind: FVar(
				TPath({name: "Array", pack: [], params: [TPType(abstractComplexType)], sub: null}),
				ordered.toExpr()
			),
			pos: Context.currentPos(),
		});

		var arrayIndexAdded:Bool = false;
		for (field in xmlFields.keys())
		{
			var fieldType = getFieldType(field);
			var defaultValue = getFieldDefaultValue(field);
			var vals:Map<String, Dynamic> = values[field];
			if (defaultValue == null)
			{
				for (v in ordered)
				{
					if (!vals.exists(v))
					{
						throw 'missing field ${field.name} for value $v, and no default value is specified';
					}
				}
			}

			newFields.push({
				name: field.name,
				doc: null,
				meta: [],
				access: field.access,
				kind: FProp("get", "never", fieldType, null),
				pos: field.pos,
			});

			var isInline = inlineFields.exists(field),
				useMap = !isInline && useMap(fieldType),
				valCount = Lambda.count(vals),
				sparse = valCount > 128 && valCount < Math.sqrt(ordered.length);
			if (useMap && sparse)
			{
				// for sparse objects, use a Map
				var mapField = "__" + field.name;
				newFields.push({
					name: mapField,
					doc: null,
					meta: [],
					access: [AStatic],
					kind: FVar(TPath({name: "Map", pack: [], params: [TPType(abstractComplexType), TPType(fieldType)], sub: null}), (
						[for (v in vals) v].length > 0 ? vals.toExpr(field.pos) : macro new Map()
					)),
					pos: field.pos,
				});
				newFields.push({
					name: "get_" + field.name,
					doc: null,
					meta: [],
					access: [AInline],
					kind: FFun({
						args: [],
						expr:
						(defaultValue == null) ?
						macro {
							return $i{mapField}[this];
						} :
						macro {
							return $i{mapField}.exists(this) ? $i{mapField}[this] : ${defaultValue};
						},
						params: null,
						ret: fieldType,
					}),
					pos: field.pos,
				});
			}
			else if (useMap)
			{
				// for non-sparse keys use an Array lookup
				if (!arrayIndexAdded)
				{
					// add the index
					arrayIndexAdded = true;
					newFields.push({
						name: "__dataIndex",
						doc: null,
						meta: [],
						access: [],
						kind: FProp("get", "never", macro : Int, null),
						pos: Context.currentPos(),
					});
					var indexGetter = EReturn(ESwitch(
						macro this,
						[for (i in 0 ... ordered.length) {
							values: [ordered[i].toExpr()],
							expr: macro $v{i},
						}],
						defaultValue == null ? macro {throw 'unsupported value: ' + this;} : defaultValue
					).at(Context.currentPos())).at(Context.currentPos());
					newFields.push({
						name: "get___dataIndex",
						doc: null,
						meta: [],
						access: [],
						kind: FFun({
							args: [],
							expr: indexGetter,
							params: null,
							ret: macro : Int,
						}),
						pos: Context.currentPos(),
					});
				}
				var mapField = "__" + field.name;
				newFields.push({
					name: mapField,
					doc: null,
					meta: [],
					access: [AStatic],
					kind: FVar(TPath({name: "Array", pack: [], params: [TPType(fieldType)], sub: null}), (
						EArrayDecl([
							for (v in ordered) vals.exists(v) ? vals[v].toExpr(field.pos) : defaultValue
						]).at(field.pos)
					)),
					pos: field.pos,
				});
				newFields.push({
					name: "get_" + field.name,
					doc: null,
					meta: [],
					access: [AInline],
					kind: FFun({
						args: [],
						expr:
						macro {
							return $i{mapField}[__dataIndex];
						},
						params: null,
						ret: fieldType,
					}),
					pos: field.pos,
				});
			}
			else
			{
				// for simple or inline types, use a switch
				var dupes:Map<String, Array<String>> = new Map();
				for (key in vals.keys())
				{
					var val = ExprTools.toString(vals[key].toExpr(field.pos));
					if (!dupes.exists(val)) dupes[val] = new Array();
					dupes[val].push(key);
				}
				var getter = EReturn(ESwitch(
					macro this,
					[for (v in dupes.keys()) {
						values: [for (key in dupes[v]) key.toExpr()],
						expr: Context.parse(v, field.pos),
					}],
					defaultValue == null ? macro {throw 'unsupported value: ' + this;} : defaultValue
				).at(field.pos)).at(field.pos);

				newFields.push({
					name: "get_" + field.name,
					doc: null,
					meta: [],
					access: isInline ? [AInline] : [],
					kind: FFun({
						args: [],
						expr: getter,
						params: null,
						ret: fieldType,
					}),
					pos: field.pos,
				});
			}
		}

		for (field in indexes.keys())
		{
			var index:Array<IndexDef> = indexes[field];
			var ct = getIndexType(field);

			newFields.push({
				name: field.name,
				doc: null,
				meta: [],
				access: field.access,
				kind: FVar(TPath({name: "Map", pack: [], params: [
						TPType(ct),
						TPType(TPath({name: "Array", pack: [], params: [TPType(abstractComplexType)]}))
					], sub: null}),
					(EArrayDecl([
						for (indexDef in index)
						macro ${indexDef.value.toExpr()} => ${indexDef.items.toExpr()}
					])).at(field.pos)),
				pos: field.pos,
			});
		}

		return newFields;
	}

	static function getValueFromNode(ct:ComplexType, fieldNames:Array<String>, node:Fast):Null<Dynamic>
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
					return findSingleValue();
				case "Array":
					var pt = params[0];
					return [for (value in findValues(node, fieldNames, true)) getValue(pt, value)];
				case "haxe.ds.StringMap":
					var values:Map<String, Dynamic> = new Map();
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
								values[key] = getValue(pt, val);
							}
						}
						for (childNode in node.nodes.resolve(fieldName))
						{
							var key = childNode.att.type;
							var val = childNode.has.value ? childNode.att.value : childNode.innerHTML;
							values[key] = getValue(pt, val);
						}
					}
					return values;
				default:
					throw "Unsupported value type: " + TypeTools.toString(t);
			}

			default:
				var val = findSingleValue();
				if (val == null) return null;
				else return getValue(t, val);
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

	static function getValue(t:Type, s:String):Dynamic
	{
		t = TypeTools.followWithAbstracts(t);
		return switch (TypeTools.toString(t))
		{
			case "String": s;
			case "Int", "UInt": Std.parseInt(s);
			case "Float": Std.parseFloat(s);
			case "Bool": switch (s)
			{
				case "true": true;
				case "false": false;
				default: throw "Unsupported Bool value " + s;
			};
			default: throw "Unsupported value type: " + TypeTools.toString(t);
		}
	}

	static function getFieldType(field:Field):ComplexType
	{
		return switch (field.kind)
		{
			case FVar(t, e): t;
			default: throw "Unsupported field type: " + field;
		}
	}

	static function getIndexType(field:Field):ComplexType
	{
		var ct = getFieldType(field);
		var t = ComplexTypeTools.toType(ct);
		switch (t)
		{
			case TInst(t, params):
				switch (t.get().name)
				{
					case "haxe.ds.StringMap": return macro : String;
					case "haxe.ds.IntMap": return macro : Int;
				}
			case TAbstract(t, params):
				switch (t.get().name)
				{
					case "Map": return TypeTools.toComplexType(params[0]);
				}
			default: {}
		}
		throw "Unsupported index field type: " + t;
	}

	static function getFieldDefaultValue(field:Field):Expr
	{
		return switch (field.kind)
		{
			case FVar(t, e): e;
			default: throw "Unsupported field type: " + field;
		}
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

	static function useMap(ct:ComplexType)
	{
		var t = TypeTools.followWithAbstracts(ComplexTypeTools.toType(ct));

		return switch (TypeTools.toString(t))
		{
			case "String", "Int", "UInt", "Float", "Bool": false;
			default: true;
		}
	}

	static function expandPath(path:String, root:String=""):Array<String>
	{
		var parts = path.split("/");
		var result = new Array();
		var lastIsLiteral:Bool = true;
		while (parts.length > 0)
		{
			var curPart = parts.shift();
			if (curPart.indexOf("*") > -1)
			{
				var re = new EReg("^" + curPart.replace(".", "\\.").replace("*", ".*") + "$", "g");
				var contents = FileSystem.readDirectory(root);
				for (path in contents)
				{
					if (re.match(path))
					{
						for (r in expandPath(root + "/" + path, parts.join("/")))
						{
							result.push(r);
						}
					}
				}
				lastIsLiteral = false;
			}
			else
			{
				if (root != "") root += "/";
				root += curPart;
				lastIsLiteral = true;
			}
		}
		if (lastIsLiteral) result.push(root);
		return result;
	}
}
