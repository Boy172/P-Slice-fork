package mikolka.vslice.ui.mods;

import flixel.FlxCamera;
import flixel.group.FlxGroup;

class ModMenuCharacter
{
	static final OFFSETS:Map<String, Array<Float>> = [
		'bf' => [0, 0],
		'gf' => [7, -200],
		'pinhead' => [22, -53]
	];

	static inline var PINHEAD_GF_START:Int = 561;

	public var group:FlxGroup = new FlxGroup();
	public var isGF:Bool;
	public var usingPinhead:Bool = false;
	public var finished:Bool = true;
	public var current:FlxAtlasSprite;

	public var hasCustomWires(get, never):Bool;
	public var useSmallWire(get, never):Bool;

	var baseX:Float;
	var baseY:Float;
	var cam:FlxCamera;
	var id:String;
	var normal:FlxAtlasSprite;
	var pin:FlxAtlasSprite;
	var playedStart:Bool = false;
	var currentName:String = '';
	var looping:Bool = false;

	public function new(x:Float, y:Float, id:String, isGF:Bool, cam:FlxCamera)
	{
		this.baseX = x;
		this.baseY = y;
		this.id = id;
		this.isGF = isGF;
		this.cam = cam;

		normal = make(id);
		group.add(normal);
		current = normal;
	}

	function get_hasCustomWires():Bool
	{
		return isGF && !usingPinhead;
	}

	function get_useSmallWire():Bool
	{
		return usingPinhead;
	}

	function make(charId:String):FlxAtlasSprite
	{
		var spr:FlxAtlasSprite = new FlxAtlasSprite(0, 0, 'vmods/characters/$charId');
		spr.scale.set(0.7, 0.7);
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.cameras = [cam];
		var off:Array<Float> = OFFSETS.get(charId);
		if (off == null) off = [0, 0];
		spr.setPosition(baseX + off[0], baseY + off[1]);
		spr.onAnimationComplete.add(onComplete);
		return spr;
	}

	public function setPinhead(value:Bool):Void
	{
		if (value && pin == null)
		{
			pin = make('pinhead');
			group.add(pin);
		}

		usingPinhead = value;
		playedStart = false;

		normal.visible = !value;
		if (pin != null) pin.visible = value;
		current = value ? pin : normal;
	}

	public function hasAnim(name:String):Bool
	{
		return current != null && current.hasAnimation(name);
	}

	public function currentAnim():String
	{
		return currentName;
	}

	public function play(name:String, ?startFrame:Int = 0, ?loop:Bool = false):Void
	{
		if (current == null) return;

		if (name == 'idle' && !playedStart && isGF && usingPinhead)
		{
			startFrame = PINHEAD_GF_START;
			playedStart = true;
		}

		finished = false;
		looping = loop;
		currentName = name;
		current.playAnimation(name, true, false, loop, startFrame);
	}

	function onComplete(name:String):Void
	{
		if (name != currentName) return;

		if (name == 'crispy' && hasAnim('crispy loop'))
		{
			play('crispy loop', 0, true);
			return;
		}

		if (!looping) finished = true;
	}

	public function pause():Void
	{
		if (current != null && current.anim != null) current.anim.pause();
	}

	public function resume():Void
	{
		if (current != null && current.anim != null) current.anim.resume();
	}
}
