package hxdata.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import hxdata.Value;
using hxdata.macros.MacroUtil;

class ValueTools
{
	public static function valToExpr(value:Value, ?pos:Position):Expr
	{
		if (pos == null) pos = Context.currentPos();
		return switch (value)
		{
			case ConcreteValue(v):
				v.toExpr(pos);
			case ArrayValue(v):
				EArrayDecl([for (val in v) valToExpr(val, pos)]).at(pos);
			case MapValue(v):
				(Lambda.count(v) > 0)
					? EArrayDecl([for (key in v.keys()) macro $v{key} => ${valToExpr(v[key], pos)}]).at(pos)
					: macro new Map();
			case LazyValue(s):
				Context.parse(s, pos);
		}
	}

	public static function valToStr(value:Value):String
	{
		return ExprTools.toString(valToExpr(value));
	}
}
