package backend;

import flixel.util.FlxTimer;

class GameResolution
{
	static var timer:FlxTimer = null;

	public static var supported(get, never):Bool;

	static function get_supported():Bool
	{
		#if android
		return true;
		#else
		return false;
		#end
	}

	public static function apply():Void
	{
		#if android
		external.android.ResolutionUtil.setScale(ClientPrefs.data.gameResolution);
		#end
	}

	public static function applyLater(delay:Float = 0.8):Void
	{
		#if android
		if (timer == null) timer = new FlxTimer();
		timer.cancel();
		timer.start(delay, function(_) apply());
		#end
	}

	public static function applyNow():Void
	{
		#if android
		if (timer != null) timer.cancel();
		apply();
		#end
	}
}
