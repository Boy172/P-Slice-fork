package mikolka.vslice.components;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;

class VSliceBoldText extends FlxSpriteGroup
{
	static inline var ATLAS_PATH:String = 'fonts/bold';
	static inline var SPACE_WIDTH:Float = 40;
	static inline var BASE_HEIGHT:Float = 70;
	static inline var LINE_SPACING:Float = 80;
	static inline var TOP_ALIGNED:String = "'\"^*";
	static inline var MIDDLE_ALIGNED:String = "-=+~<>";

	static final SPECIAL_FRAMES:Map<String, String> = [
		'&' => '-andpersand-',
		"'" => '-apostraphie-',
		'\\' => '-back slash-',
		',' => '-comma-',
		'-' => '-dash-',
		'!' => '-exclamation point-',
		'/' => '-forward slash-',
		'>' => '-greater than-',
		'<' => '-less than-',
		'.' => '-period-',
		'?' => '-question mark-'
	];

	static final ACCENTS:Map<String, String> = [
		'á' => 'a', 'à' => 'a', 'â' => 'a', 'ä' => 'a', 'ã' => 'a',
		'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e',
		'í' => 'i', 'ì' => 'i', 'î' => 'i', 'ï' => 'i',
		'ó' => 'o', 'ò' => 'o', 'ô' => 'o', 'ö' => 'o', 'õ' => 'o',
		'ú' => 'u', 'ù' => 'u', 'û' => 'u', 'ü' => 'u',
		'ñ' => 'n', 'ç' => 'c',
		'Á' => 'A', 'À' => 'A', 'Â' => 'A', 'Ä' => 'A', 'Ã' => 'A',
		'É' => 'E', 'È' => 'E', 'Ê' => 'E', 'Ë' => 'E',
		'Í' => 'I', 'Ì' => 'I', 'Î' => 'I', 'Ï' => 'I',
		'Ó' => 'O', 'Ò' => 'O', 'Ô' => 'O', 'Ö' => 'O', 'Õ' => 'O',
		'Ú' => 'U', 'Ù' => 'U', 'Û' => 'U', 'Ü' => 'U',
		'Ñ' => 'N', 'Ç' => 'C'
	];

	public var text(default, set):String;
	public var textScale(default, set):Float = 1;

	public function new(x:Float = 0, y:Float = 0, text:String = '', textScale:Float = 1)
	{
		super(x, y);
		this.textScale = textScale;
		this.text = text;
	}

	function set_textScale(value:Float):Float
	{
		if (value <= 0) value = 1;
		if (textScale == value) return value;
		textScale = value;
		if (text != null) rebuild();
		return value;
	}

	public function fitTo(maxWidth:Float):Void
	{
		if (maxWidth <= 0 || width <= maxWidth) return;
		textScale = textScale * (maxWidth / width);
	}

	public function setTint(value:FlxColor):Void
	{
		for (member in members)
			if (member != null) member.color = value;
	}

	function set_text(value:String):String
	{
		if (value == null) value = '';
		if (text == value) return value;
		text = value;
		rebuild();
		return value;
	}

	function rebuild():Void
	{
		while (members.length > 0)
		{
			var old:FlxSprite = members[0];
			remove(old, true);
			old.destroy();
		}

		if (text.length == 0) return;

		var atlas:FlxAtlasFrames = Paths.getSparrowAtlas(ATLAS_PATH);
		var clean:String = normalize(text);
		var cursorX:Float = 0;
		var cursorY:Float = 0;

		for (i in 0...clean.length)
		{
			var char:String = clean.charAt(i);

			if (char == '\n')
			{
				cursorX = 0;
				cursorY += LINE_SPACING * textScale;
				continue;
			}

			if (char == ' ')
			{
				cursorX += SPACE_WIDTH * textScale;
				continue;
			}

			var prefix:String = SPECIAL_FRAMES.exists(char) ? SPECIAL_FRAMES.get(char) : char;
			if (atlas.getByName(prefix + '0000') == null) continue;

			var letter:FlxSprite = new FlxSprite();
			letter.frames = atlas;
			letter.animation.addByPrefix('idle', prefix, 24, true);
			if (!letter.animation.exists('idle'))
			{
				letter.destroy();
				continue;
			}
			letter.animation.play('idle');
			letter.updateHitbox();
			letter.antialiasing = ClientPrefs.data.antialiasing;

			var rawHeight:Float = letter.height;
			var offsetY:Float = BASE_HEIGHT - rawHeight;
			if (TOP_ALIGNED.indexOf(char) != -1) offsetY = 0;
			else if (MIDDLE_ALIGNED.indexOf(char) != -1) offsetY = (BASE_HEIGHT - rawHeight) / 2;
			offsetY *= textScale;

			if (textScale != 1)
			{
				letter.scale.set(textScale, textScale);
				letter.updateHitbox();
			}

			letter.setPosition(cursorX, cursorY + offsetY);
			cursorX += letter.width;
			add(letter);
		}
	}

	static function normalize(value:String):String
	{
		var result:String = value;
		for (accent => replacement in ACCENTS)
			result = result.split(accent).join(replacement);
		return result.toUpperCase();
	}
}
