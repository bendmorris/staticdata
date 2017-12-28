package hxdata.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import hxdata.Value;
using hxdata.macros.MacroUtil;
using hxdata.macros.ValueTools;
using StringTools;

typedef IndexDef = {
	var value:Value;
	var items:Array<String>;
}

class DataContext
{
	public static function getValue(t:Type, s:Dynamic):Value
	{
		if (Std.is(s, String))
		{
			var s:String = cast s;
			if (s.startsWith("`") && s.endsWith("`"))
			{
				return LazyValue(s.substr(1, s.length - 2));
			}
			else
			{
				t = TypeTools.followWithAbstracts(t);
				return ConcreteValue(switch (TypeTools.toString(t))
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
				});
			}
		}
		else return ConcreteValue(s);
	}

	public static function getFieldType(field:Field):ComplexType
	{
		return switch (field.kind)
		{
			case FVar(t, e): t;
			default: throw "Unsupported field type: " + field;
		}
	}

	public static function getIndexType(field:Field):ComplexType
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

	public static function getFieldDefaultValue(field:Field):Expr
	{
		return switch (field.kind)
		{
			case FVar(t, e): e;
			default: throw "Unsupported field type: " + field;
		}
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

	public var nodeName:String;
	public var abstractType:AbstractType;
	public var abstractComplexType:ComplexType;
	public var newFields:Array<Field> = new Array();

	public var ordered:Array<Dynamic> = new Array();
	public var autoId:Int = 0;
	public var nodeCount:Int = 0;

	public var indexes:Map<Field, Array<IndexDef>>;
	public var values:Map<Field, Map<String, Value>>;

	// find the fields to generate
	// these fields will generate read-only fields with getters to retrieve the value for each variant
	public var dataFields:Map<Field, Array<String>> = new Map();
	// fields marked with @:inlineField will always use a switch with the getter inlined
	public var inlineFields:Map<Field, Bool> = new Map();
	// fields marked with @:index will build index maps based on the specified attribute
	public var indexFields:Map<Field, Array<String>> = new Map();
	// one or more processing functions which will be called on the value
	public var fieldProcessors:Map<Field, Array<Expr>> = new Map();

	public function new(nodeName:String, abstractType:AbstractType, fields:Array<Field>)
	{
		this.nodeName = nodeName;
		this.abstractType = abstractType;
		abstractComplexType = TPath({name: abstractType.name, pack: abstractType.pack, params: null});

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
					dataFields[field] = fieldNames;
				}
				else if (m.name == ':index')
				{
					if (dataFields.exists(field)) throw '@:index field cannot have a @:a tag (${abstractType.name}::${field.name})';
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
					break;
				}
				else if (m.name == ':inlineField')
				{
					if (!dataFields.exists(field)) throw '@:inlineField field needs a @:a tag first (${abstractType.name}::${field.name})';
					inlineFields[field] = true;
				}
				else if (m.name == ':f')
				{
					if (!fieldProcessors.exists(field))
					{
						fieldProcessors[field] = new Array();
					}
					for (p in m.params)
					{
						fieldProcessors[field].push(p);
					}
				}
			}
			if (!isSpecialField)
			{
				newFields.push(field);
			}
		}

		indexes = [
			for (field in indexFields.keys()) field => new Array()
		];
		values = [
			for (field in dataFields.keys()) field => new Map()
		];
	}

	public function build()
	{
		if (nodeCount == 0)
		{
			throw "No valid nodes found for DataEnum " + abstractType.name;
		}

		var pos = Context.currentPos(),
			typeName = abstractType.name;

		newFields.insert(0, {
			name: "ordered",
			doc: null,
			meta: [],
			access: [AStatic, APublic],
			kind: FVar(
				TPath({name: "Array", pack: [], params: [TPType(abstractComplexType)], sub: null}),
				ordered.toExpr()
			),
			pos: pos,
		});

		var arrayIndexAdded:Bool = false;
		for (field in dataFields.keys())
		{
			var fieldType = getFieldType(field);
			var defaultValue = getFieldDefaultValue(field);
			var vals:Map<String, Value> = values[field];
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
						MapValue(vals).valToExpr(field.pos)
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
						pos: pos,
					});
					var indexGetter = EReturn(ESwitch(
						macro this,
						[for (i in 0 ... ordered.length) {
							values: [ordered[i].toExpr()],
							expr: macro $v{i},
						}],
						defaultValue == null ? macro {throw 'unsupported value: ' + this;} : defaultValue
					).at(pos)).at(pos);
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
						pos: pos,
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
							for (v in ordered) vals.exists(v) ? vals[v].valToExpr(field.pos) : defaultValue
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
					var val = ExprTools.toString(vals[key].valToExpr(field.pos));
					if (!dupes.exists(val)) dupes[val] = new Array();
					dupes[val].push(key);
				}
				inline function process(expr:Expr)
				{
					if (fieldProcessors.exists(field))
					{
						for (fieldProcessor in fieldProcessors[field])
						{
							expr = ECall(fieldProcessor, [expr]).at(field.pos);
						}
						return expr;
					}
					else
					{
						return expr;
					}
				}
				var getter = EReturn(ESwitch(
					macro this,
					[for (v in dupes.keys()) {
						values: [for (key in dupes[v]) key.toExpr()],
						expr: process(Context.parse(v, field.pos)),
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
						macro ${indexDef.value.valToExpr(field.pos)} => ${indexDef.items.toExpr()}
					])).at(field.pos)),
				pos: field.pos,
			});
		}
	}
}
