package mikolka.vslice.components;

import backend.Difficulty;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import mikolka.funkin.custom.NativeFileSystem;
import mikolka.vslice.components.SRTUtil.SRTParser;
import mikolka.vslice.components.SRTUtil.SubtitleEntry;

class Subtitles extends FlxSpriteGroup
{
	var subtitleText:SubtitlesText;
	var background:FlxSprite;
	var subtitlesData:Array<SubtitleEntry>;
	var assignedSound:FlxSound;
	var currentText:String = '';

	public var offsets(default, set):Array<Float> = [0, 0];
	public var alignment(default, set):SubtitlesAlignment = SubtitlesAlignment.SUBTITLES_BOTTOM;

	public function new(x:Float = 0, y:Float = 0, alignment:SubtitlesAlignment = SubtitlesAlignment.SUBTITLES_BOTTOM)
	{
		super(0, 0);

		this.offsets = [x, y];
		this.alignment = alignment;

		background = new FlxSprite(0, 0);
		background.makeGraphic(1, 1, FlxColor.BLACK);
		background.alpha = 0.5;
		add(background);

		subtitleText = new SubtitlesText(0, 0, 30, Paths.font('vcr.ttf'));
		add(subtitleText);

		setText('', true);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (assignedSound == null || subtitlesData == null) return;

		var time:Float = assignedSound.time;
		var combined:String = '';
		var found:Bool = false;

		for (data in subtitlesData)
		{
			if (time >= data.start && time <= data.end)
			{
				combined = found ? data.text + '\n' + combined : data.text;
				found = true;
			}
		}

		if (found) setText(combined);
		else setText('', true);
	}

	public function assignSubtitles(song:String, sound:FlxSound):Void
	{
		setText('', true);
		subtitlesData = null;
		assignedSound = null;

		if (sound == null) return;

		var path:String = findFile(song);
		if (path == null) return;

		var raw:String = NativeFileSystem.getContent(path);
		if (raw == null) return;

		var data:Array<SubtitleEntry> = SRTParser.parseFromString(raw);
		if (data.length == 0) return;

		subtitlesData = data;
		assignedSound = sound;
	}

	static function findFile(song:String):Null<String>
	{
		var diff:String = Difficulty.getString();
		var variation:String = diff == null ? '' : Paths.formatToSongPath(diff);
		var bases:Array<String> = [
			'songs/$song/subtitles/song-lyrics',
			'data/songs/$song/subtitles/song-lyrics',
			'data/$song/subtitles/song-lyrics',
			'data/$song/song-lyrics'
		];

		for (base in bases)
		{
			var names:Array<String> = variation.length > 0 ? ['$base-$variation.srt', '$base.srt'] : ['$base.srt'];
			for (name in names)
			{
				var path:String = Paths.getPath(name);
				if (NativeFileSystem.exists(path)) return path;
			}
		}

		return null;
	}

	function setText(text:String, hide:Bool = false):Void
	{
		visible = !hide;

		if (currentText == text) return;
		currentText = text;

		subtitleText.text = text;

		background.scale.set(Math.max(1, Math.ceil(subtitleText.width)), Math.max(1, Math.ceil(subtitleText.height)));
		background.updateHitbox();

		updatePosition();
	}

	function updatePosition():Void
	{
		if (subtitleText == null) return;

		x = (FlxG.width - subtitleText.width) / 2 + offsets[0];

		switch (alignment)
		{
			case SubtitlesAlignment.SUBTITLES_TOP:
				y = offsets[1];
			case SubtitlesAlignment.SUBTITLES_BOTTOM:
				y = FlxG.height - subtitleText.height - offsets[1];
		}
	}

	function set_alignment(value:SubtitlesAlignment):SubtitlesAlignment
	{
		alignment = value;
		updatePosition();
		return alignment;
	}

	function set_offsets(value:Array<Float>):Array<Float>
	{
		offsets = value;
		updatePosition();
		return offsets;
	}
}

class SubtitlesText extends FlxText
{
	public function new(x:Float = 0, y:Float = 0, size:Int, font:String)
	{
		super(x, y, 0, '', size);

		this.font = font;
		this.size = size;
		this.alignment = FlxTextAlign.CENTER;
	}

	override function set_text(Text:String):String
	{
		text = Text;
		if (textField != null)
		{
			var ot:String = textField.htmlText;
			textField.htmlText = Text;
			_regen = (textField.htmlText != ot) || _regen;
		}
		return Text;
	}

	override function applyFormats(_:openfl.text.TextFormat, __:Bool = false):Void
	{
	}
}

enum abstract SubtitlesAlignment(String) from String to String
{
	public var SUBTITLES_TOP:String = 'top';
	public var SUBTITLES_BOTTOM:String = 'bottom';
}
