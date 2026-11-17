package mikolka.vslice.components;

import flixel.FlxG;
import flixel.FlxState;

class TouchPadHider
{
	public static var hidden(get, set):Bool;

	static var started:Bool = false;
	static var lastHidden:Bool = false;

	public static function initialize():Void
	{
		if (started) return;
		started = true;
		FlxG.signals.postUpdate.add(apply);
	}

	static function get_hidden():Bool
	{
		return FlxG.save != null && FlxG.save.data != null && FlxG.save.data.pslideHideTouchPad == true;
	}

	static function set_hidden(value:Bool):Bool
	{
		if (FlxG.save == null || FlxG.save.data == null) return value;
		FlxG.save.data.pslideHideTouchPad = value;
		FlxG.save.flush();
		initialize();
		apply();
		return value;
	}

	static function apply():Void
	{
		var hide:Bool = hidden;
		if (!hide && !lastHidden) return;
		lastHidden = hide;

		var root:FlxState = FlxG.state;
		if (root == null) return;
		if (hide && Type.getClassName(Type.getClass(root)) == 'states.PlayState') return;

		var current:FlxState = root;
		while (current != null)
		{
			var pad:Dynamic = Reflect.getProperty(current, 'touchPad');
			if (pad != null)
			{
				pad.visible = !hide;
				pad.active = !hide;
			}
			current = current.subState;
		}
	}
}
