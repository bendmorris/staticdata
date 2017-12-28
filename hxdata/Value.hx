package hxdata;

enum Value
{
	ConcreteValue(v:Dynamic);
	ArrayValue(v:Array<Value>);
	MapValue(v:Map<String, Value>);
	LazyValue(s:String);
}
