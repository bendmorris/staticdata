package hxdata;

enum Value
{
	ConcreteValue(v:Dynamic);
	ArrayValue(v:Array<Value>);
	MapValue(v:Map<Value, Value>);
	LazyValue(s:String);
}
