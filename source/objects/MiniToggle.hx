package objects;

import flixel.util.FlxSpriteUtil;

class MiniToggle extends FlxSprite
{
	public static inline var TRACK_WIDTH:Int = 64;
	public static inline var TRACK_HEIGHT:Int = 34;

	public var sprTracker:FlxSprite;
	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var copyAlpha:Bool = true;
	public var onColor:FlxColor;
	public var offColor:FlxColor;
	public var daValue(default, set):Bool;

	var progress:Float = 0;
	var drawnProgress:Float = -1;

	public function new(x:Float = 0, y:Float = 0, checked:Bool = false, onColor:FlxColor = 0xFFEA71FD, offColor:FlxColor = 0xFF3A3A4C)
	{
		super(x, y);
		this.onColor = onColor;
		this.offColor = offColor;
		makeGraphic(TRACK_WIDTH, TRACK_HEIGHT, FlxColor.TRANSPARENT, true);
		antialiasing = ClientPrefs.data.antialiasing;
		daValue = checked;
		progress = checked ? 1 : 0;
		redraw();
	}

	function redraw():Void
	{
		drawnProgress = progress;
		FlxSpriteUtil.fill(this, FlxColor.TRANSPARENT);
		var track:FlxColor = FlxColor.interpolate(offColor, onColor, progress);
		FlxSpriteUtil.drawRoundRect(this, 1, 1, TRACK_WIDTH - 2, TRACK_HEIGHT - 2, TRACK_HEIGHT, TRACK_HEIGHT, track);
		var knobX:Float = FlxMath.lerp(TRACK_HEIGHT / 2, TRACK_WIDTH - TRACK_HEIGHT / 2, progress);
		FlxSpriteUtil.drawCircle(this, knobX, TRACK_HEIGHT / 2, TRACK_HEIGHT / 2 - 5, FlxColor.WHITE);
	}

	override function update(elapsed:Float)
	{
		var target:Float = daValue ? 1 : 0;
		if (progress != target)
		{
			progress = FlxMath.lerp(target, progress, Math.exp(-elapsed * 18));
			if (Math.abs(progress - target) < 0.01)
				progress = target;
		}
		if (progress != drawnProgress)
			redraw();

		if (sprTracker != null)
		{
			setPosition(sprTracker.x + offsetX, sprTracker.y + offsetY);
			visible = sprTracker.visible;
			if (copyAlpha)
				alpha = sprTracker.alpha;
		}
		super.update(elapsed);
	}

	function set_daValue(value:Bool):Bool
	{
		daValue = value;
		return value;
	}
}
