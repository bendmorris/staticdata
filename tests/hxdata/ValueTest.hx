package hxdata;

import haxe.macro.Expr;
import hxdata.Value;
using hxdata.macros.MacroUtil;
using hxdata.macros.ValueTools;

class ValueTest extends TestCase
{
	static var MY_VAL = 123;

	static macro function lazyStr(s:String):Expr
	{
		return EConst(CString(LazyValue(s).valToStr())).at();
	}

	static macro function lazyVal(s:String):Expr
	{
		return LazyValue(s).valToExpr();
	}

	public function testLazyStringify()
	{
		assertEquals("1", lazyStr("1"));
		assertEquals("false", lazyStr("false"));
		assertEquals('"abc"', lazyStr("'abc'"));
	}

	public function testLazyExprify()
	{
		assertEquals(1, lazyVal("1"));
		assertEquals(false, lazyVal("false"));
		assertEquals("abc", lazyVal("'abc'"));
		assertEquals(MY_VAL, lazyVal("ValueTest.MY_VAL"));
	}
}
