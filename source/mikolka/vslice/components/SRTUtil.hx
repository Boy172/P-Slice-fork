package mikolka.vslice.components;

class SubtitleEntry
{
	public var id:Int;
	public var start:Float;
	public var end:Float;
	public var text:String;

	public function new(number:Int = 0, start:Float = 0, end:Float = 0, text:String = "")
	{
		this.id = number;
		this.start = start;
		this.end = end;
		this.text = text;
	}
}

class SRTParser
{
	public static var convertBracesToAngles:Bool = true;

	static final timeArrowPatterns:Array<String> = ["-->", "->", "—>", "–>"];

	public static function parseFromString(s:String):Array<SubtitleEntry>
	{
		var out:Array<SubtitleEntry> = [];
		if (s == null) return out;

		var normalized:String = s.split("\r\n").join("\n").split("\r").join("\n");
		if (normalized.length > 0 && normalized.charCodeAt(0) == 0xFEFF) normalized = normalized.substr(1);

		for (block in normalized.split("\n\n"))
		{
			var trimmed:String = SubtitleUtils.trimText(block);
			if (trimmed.length == 0) continue;

			var lines:Array<String> = trimmed.split("\n");
			var idx:Int = 0;
			var number:Int = 0;

			if (SubtitleUtils.isNumeric(lines[0]))
			{
				number = Std.parseInt(SubtitleUtils.trimText(lines[0]));
				idx = 1;
			}
			if (idx >= lines.length) continue;

			var times = parseTimeLine(lines[idx]);
			idx++;
			if (times == null) continue;

			var text:String = lines.slice(idx).join("\n");
			if (convertBracesToAngles) text = text.split("{").join("<").split("}").join(">");

			out.push(new SubtitleEntry(number, times.start, times.end, text));
		}

		out.sort(SubtitleUtils.sortLines);
		return out;
	}

	public static function parseTimeLine(line:String):Null<{start:Float, end:Float}>
	{
		var left:String = null;
		var right:String = null;

		for (arrow in timeArrowPatterns)
		{
			var parts:Array<String> = line.split(arrow);
			if (parts.length == 2)
			{
				left = SubtitleUtils.trimText(parts[0]);
				right = SubtitleUtils.trimText(parts[1]);
				break;
			}
		}

		if (left == null || right == null) return null;

		var s:Float = parseTimecode(left);
		var e:Float = parseTimecode(right);
		if (s < 0 || e < 0) return null;

		return {start: s, end: e};
	}

	public static function parseTimecode(t:String):Float
	{
		var parts:Array<String> = SubtitleUtils.trimText(t).split(",").join(".").split(":");
		if (parts.length != 3) return -1;

		var hh:Null<Int> = Std.parseInt(parts[0]);
		var mm:Null<Int> = Std.parseInt(parts[1]);
		var secParts:Array<String> = parts[2].split(".");
		var ss:Null<Int> = Std.parseInt(secParts[0]);
		if (hh == null || mm == null || ss == null) return -1;

		var ms:Int = 0;
		if (secParts.length > 1)
		{
			var frac:String = secParts[1];
			if (frac.length > 3) frac = frac.substr(0, 3);
			while (frac.length < 3) frac += "0";
			var parsed:Null<Int> = Std.parseInt(frac);
			if (parsed != null) ms = parsed;
		}

		return (hh * 3600 + mm * 60 + ss) * 1000 + ms;
	}
}

class SubtitleUtils
{
	public static function trimText(s:String):String
	{
		if (s == null) return "";
		var a:Int = 0;
		var b:Int = s.length;
		while (a < b && isSpace(s.charCodeAt(a))) a++;
		while (b > a && isSpace(s.charCodeAt(b - 1))) b--;
		return s.substr(a, b - a);
	}

	static inline function isSpace(c:Null<Int>):Bool
	{
		return c == 32 || c == 9 || c == 10 || c == 13;
	}

	public static function isNumeric(s:String):Bool
	{
		var t:String = trimText(s);
		if (t.length == 0) return false;
		for (i in 0...t.length)
		{
			var code:Int = t.charCodeAt(i);
			if (code < '0'.code || code > '9'.code) return false;
		}
		return true;
	}

	public static function sortLines(a:SubtitleEntry, b:SubtitleEntry):Int
	{
		if (a.id != b.id) return a.id < b.id ? -1 : 1;
		if (a.start != b.start) return a.start < b.start ? -1 : 1;
		return 0;
	}
}
