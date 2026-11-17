package mikolka.vslice.components;

import flixel.FlxG;
import flixel.FlxState;
import mikolka.funkin.custom.mobile.MobileScaleMode;

class TouchPadHider
{
	public static var hidden(get, set):Bool;

	static inline var EDITORS_PREFIX:String = 'states.editors.';
	static inline var EDITORS_MENU:String = 'states.editors.MasterEditorMenu';
	static inline var PLAYSTATE:String = 'states.PlayState';

	static var started:Bool = false;
	static var lastHidden:Bool = false;
	static var editorBack:FunkinBackButton = null;
	static var editorBackOwner:FlxState = null;
	static var leaving:Bool = false;

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

		var rootName:String = Type.getClassName(Type.getClass(root));

		if (hide && (rootName == PLAYSTATE || (rootName.indexOf(EDITORS_PREFIX) == 0 && rootName != EDITORS_MENU))) return;

		if (hide && rootName == EDITORS_MENU) ensureEditorBack(root);

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

	static function ensureEditorBack(root:FlxState):Void
	{
		if (editorBack != null && editorBackOwner == root) return;

		leaving = false;
		editorBackOwner = root;
		editorBack = new FunkinBackButton(FlxG.width - 230 - MobileScaleMode.gameCutoutSize.x / 2, 10, leaveEditors, 1.0);
		editorBack.handleAndroidBack = false;
		root.add(editorBack);
	}

	static function leaveEditors():Void
	{
		if (leaving) return;
		leaving = true;
		MusicBeatState.switchState(new MainMenuState());
	}
}
