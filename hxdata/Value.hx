package hxdata;

import haxe.macro.Expr;

enum Value
{
	ConcreteValue(v:Dynamic);
	ArrayValue(v:Array<Value>);
	MapValue(v:Map<Value, Value>);
	LazyValue(s:String);
	FieldValue(ident:String, field:String);
}
