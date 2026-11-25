package mikolka.vslice.ui.mods;

import animate.FlxAnimateFrames;
import flixel.util.FlxSignal.FlxTypedSignal;
import haxe.Json;
import haxe.io.Path;

using StringTools;

class ModAtlas extends animate.FlxAnimate
{
	public static inline var WHOLE:String = '__whole';

	public var onComplete:FlxTypedSignal<String->Void> = new FlxTypedSignal();
	public var currentName:String = '';
	public var loaded:Bool = false;

	var names:Array<String> = [];

	public function new(x:Float, y:Float, key:String)
	{
		super(x, y);
		load(key);
	}

	function load(key:String):Void
	{
		var dir:String = Paths.getPath('images/$key');
		var animPath:String = Path.join([dir, 'Animation.json']);
		var mapPath:String = Path.join([dir, 'spritemap1.json']);

		if (!NativeFileSystem.exists(animPath) || !NativeFileSystem.exists(mapPath))
		{
			trace('Missing atlas files for $key');
			return;
		}

		var animText:String = NativeFileSystem.getContent(animPath);
		var mapText:String = NativeFileSystem.getContent(mapPath);
		var graphic = Paths.image(Path.join([key, 'spritemap1']));

		if (graphic == null)
		{
			trace('Missing spritemap image for $key');
			return;
		}

		var collection:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(animText, [{source: graphic, json: mapText}], null, 'modmenu/$key', true);

		if (collection == null)
		{
			trace('Could not build atlas $key');
			return;
		}

		frames = collection;
		loaded = true;

		var parsed:Dynamic = Json.parse(animText.replace(String.fromCharCode(0xFEFF), ''));
		var layers:Array<Dynamic> = parsed.AN.TL.L;

		for (layer in layers)
		{
			var keyframes:Array<Dynamic> = layer.FR;
			for (kf in keyframes)
			{
				var label:String = kf.N;
				if (label == null) continue;
				label = label.rtrim();
				if (label == '' || names.indexOf(label) != -1) continue;
				anim.addByFrameLabel(label, label, null, false);
				names.push(label);
			}
		}

		anim.addByTimeline(WHOLE, anim.getDefaultTimeline(), null, false);
		anim.onFinish.add(finishedAnim);
	}

	function finishedAnim(name:String):Void
	{
		onComplete.dispatch(name == WHOLE ? '' : name);
	}

	public function hasAnimation(name:String):Bool
	{
		return loaded && (name == '' || names.indexOf(name) != -1);
	}

	public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, loop:Bool = false, startFrame:Int = 0):Void
	{
		if (!loaded) return;

		var id:String = name == '' ? WHOLE : name;
		if (!hasAnimation(name)) return;

		currentName = name;

		var target = anim.getByName(id);
		if (target == null) return;
		if (startFrame < 0 || startFrame >= target.frames.length) startFrame = 0;

		anim.play(id, restart, false, startFrame);
		target.looped = loop;
	}

	public function isDone():Bool
	{
		return anim.curAnim == null || anim.curAnim.finished;
	}
}
