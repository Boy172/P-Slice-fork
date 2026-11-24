package mikolka.vslice.ui.mods;

import flixel.FlxCamera;
import flixel.addons.display.FlxRuntimeShader;
import flixel.util.FlxColor;
import mikolka.funkin.FlxAtlasSprite;
import flixel.group.FlxGroup;

class ModMenuCharacter
{
	static final OFFSETS:Map<String, Array<Float>> = [
		'bf' => [0, 0],
		'gf' => [7, -200],
		'pinhead' => [22, -53]
	];

	static final BOUNDS:Map<String, Array<Float>> = [
		'characters/bf' => [-226.3, -286.85, 522.75, 804.55],
		'characters/gf' => [-217.65, -541.21, 771.65, 859.56],
		'characters/pinhead' => [-246.15, -381.75, 690.5, 729.3],
		'characters/empty-chair' => [-131.87, -40.55, 407.92, 692.16],
		'foreground-wires-bottom' => [110.6, -460.7, 1213.35, 1446.5],
		'foreground-wires-top' => [110.6, -460.7, 1213.35, 1446.5],
		'smoke-cloud' => [-977.03, -1405.23, 1322.27, 1679.08],
		'back-arrow' => [-28.5, 0.0, 155.9, 132.03]
	];

	static inline var PINHEAD_GF_START:Int = 561;

	static final REPLACE_FRAG:String = "#pragma header
uniform vec3 uTargetColor;
uniform vec3 uReplaceColor;
uniform float uThreshold;
void main()
{
	vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
	vec3 u = c.rgb;
	if (c.a > 0.0) u = c.rgb / c.a;
	if (distance(u, uTargetColor) < uThreshold) c.rgb = uReplaceColor * c.a;
	gl_FragColor = c;
}";

	static final WHITE_FRAG:String = "#pragma header
void main()
{
	vec4 c = flixel_texture2D(bitmap, openfl_TextureCoordv);
	gl_FragColor = vec4(c.a, c.a, c.a, c.a);
}";

	public static function place(spr:FlxAtlasSprite, key:String, x:Float, y:Float, scale:Float, hitboxed:Bool):Void
	{
		var b:Array<Float> = BOUNDS.get(key);
		if (b == null)
		{
			spr.setPosition(x, y);
			return;
		}

		var px:Float = x - b[0] * scale;
		var py:Float = y - b[1] * scale;

		if (!hitboxed)
		{
			px += (1 - scale) * b[2] * 0.5;
			py += (1 - scale) * b[3] * 0.5;
		}

		spr.setPosition(px, py);
	}

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
	var pinShader:FlxRuntimeShader;
	var whiteShader:FlxRuntimeShader;
	var pinColor:Array<Float> = [1, 1, 1];
	var white:Bool = false;

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
		place(spr, 'characters/$charId', baseX + off[0], baseY + off[1], 0.7, false);
		spr.onAnimationComplete.add(onComplete);
		return spr;
	}

	function randomPinColor():Void
	{
		var hue:Float = FlxG.random.float(0, 360);
		var sat:Float = (75 + FlxG.random.float(0, 5)) / 240;
		var lum:Float = (80 + FlxG.random.float(0, 79)) / 240;
		var color:FlxColor = FlxColor.fromHSL(hue, sat, lum);
		pinColor = [color.redFloat, color.greenFloat, color.blueFloat];
		applyPinColor();
	}

	function applyPinColor():Void
	{
		if (pinShader != null) pinShader.setFloatArray('uReplaceColor', pinColor);
	}

	function lightningPinColor():Void
	{
		pinColor = [Math.min(pinColor[0] * 1.8, 1), Math.min(pinColor[1] * 1.8, 1), Math.min(pinColor[2] * 1.8, 1)];
		applyPinColor();
	}

	function refreshShader():Void
	{
		if (current == null) return;

		if (white)
		{
			if (whiteShader == null) whiteShader = new FlxRuntimeShader(WHITE_FRAG);
			current.shader = whiteShader;
		}
		else if (usingPinhead && pinShader != null) current.shader = pinShader;
		else current.shader = null;
	}

	public function setWhite(value:Bool):Void
	{
		white = value;
		refreshShader();
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
		white = false;

		normal.visible = !value;
		normal.shader = null;
		if (pin != null) pin.visible = value;
		current = value ? pin : normal;

		if (value)
		{
			if (pinShader == null)
			{
				pinShader = new FlxRuntimeShader(REPLACE_FRAG);
				pinShader.setFloatArray('uTargetColor', [0, 1, 0.04]);
				pinShader.setFloat('uThreshold', 0.12);
			}
			randomPinColor();
		}

		refreshShader();
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

		if (name == 'electrocuted' && usingPinhead) lightningPinColor();

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
