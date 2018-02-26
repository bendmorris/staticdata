package staticdata;

import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.xml.Fast;
import staticdata.Value;
using staticdata.MacroUtil;
using staticdata.ValueTools;
using StringTools;

/**
 * Used to define an enum abstract with variants from an XML data file.
 */
class DataModel
{
	public static function parse(dataContext:DataContext, filename:String)
	{
		filename = Context.resolvePath(filename);

		var parsers:Map<String, DataParser.IDataParser> = new Map();
		parsers[".xml"] = new XmlParser();
		#if yaml parsers[".yaml"] = new YamlParser(); #end

		for (extension in parsers.keys())
		{
			if (filename.endsWith(extension))
			{
				return parsers[extension].parse(dataContext, filename);
			}
		}
		throw 'Unrecognized file format: $filename';
	}

	public static function build(?dataFiles:Array<String>, ?nodeName:String)
	{
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

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
					default: throw "Unsupported type for DataModel: " + type;
				}
			default:
				throw "Unsupported type for DataModel: " + type;
		}

		// find the data files to parse
		if (dataFiles == null) dataFiles = new Array();
		var pathMeta = meta.extract(":dataPath");
		if (pathMeta.length > 0)
		{
			for (m in pathMeta)
			{
				var p = m.params;
				if (p == null) throw "Empty @:dataPath on DataModel " + abstractType.name;
				else if (p[0].ident() != null) dataFiles.push(p[0].ident());
				else throw "Bad @:dataPath on DataModel " + abstractType.name + ": " + p[0].expr;
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
					if (p == null) throw "Empty @:dataNode on DataModel " + abstractType.name;
					nodeName = p[0].ident();
					break;
				}
			}
		}

		var files:Array<String> = new Array();
		for (dataFile in dataFiles)
		{
			var paths:Array<String>;
			if (dataFile.indexOf("*") > -1)
			{
				paths = Utils.findFiles(Path.normalize(dataFile));
			}
			else paths = [dataFile];
			for (path in paths)
			{
				files.push(path);
			}
		}
		if (files.length == 0)
		{
			throw "No data files specified for DataModel " + abstractType.name + "; search paths: " + dataFiles.join(", ");
		}

		var context:DataContext = new DataContext(nodeName, abstractType, fields);
		for (file in files)
		{
			parse(context, file);
		}

		context.build();
		return context.newFields;
	}
}
