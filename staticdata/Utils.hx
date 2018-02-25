package staticdata;

import sys.FileSystem;
using StringTools;

class Utils
{
	public static function findFiles(path:String, root:String=""):Array<String>
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
						for (r in findFiles(root + "/" + path, parts.join("/")))
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
