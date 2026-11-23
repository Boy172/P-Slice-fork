package mikolka.vslice.ui.mods;

import flixel.FlxSprite;

class ModMenuButton extends FlxSprite
{
	static final ACCEPT_SCALE:Array<Float> = [0.61, 0.61, 0.69, 0.69, 0.69, 0.65, 0.65, 0.65, 0.65];
	static final ACCEPT_INVERT:Array<Bool> = [true, true, false, false, false, false, false, false, false];
	static final ACCEPT_SELECT:Array<Bool> = [false, false, true, true, true, false, false, false, false];

	public static inline var REST_SCALE:Float = 0.65;
	public static inline var SELECT_SCALE:Float = 0.72;

	public var graphicName:String = '';
	public var onFinish:Void->Void;

	var isSelected:Bool = false;
	var isInverted:Bool = false;
	var shownKey:String = '<none>';
	var seqTime:Float = -1;
	var topLeftX:Float = 0;
	var topLeftY:Float = 0;
	var baseW:Float = 0;
	var baseH:Float = 0;

	public function setup(name:String, px:Float, py:Float):ModMenuButton
	{
		graphicName = name;
		topLeftX = px;
		topLeftY = py;
		antialiasing = ClientPrefs.data.antialiasing;
		applyGraphic();
		scale.set(REST_SCALE, REST_SCALE);
		place();
		return this;
	}

	function place():Void
	{
		x = topLeftX - frameWidth * (1 - REST_SCALE) / 2;
		y = topLeftY - frameHeight * (1 - REST_SCALE) / 2;
	}

	function applyGraphic():Void
	{
		var suffix:String = isInverted ? '-inverted' : (isSelected ? '-highlighted' : '');
		if (suffix == shownKey) return;
		var graph = Paths.image('vmods/$graphicName$suffix');
		if (graph == null) return;
		shownKey = suffix;
		loadGraphic(graph);
		baseW = frameWidth;
		baseH = frameHeight;
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function hitRect():Array<Float>
	{
		return [topLeftX, topLeftY, baseW * REST_SCALE, baseH * REST_SCALE];
	}

	public function hits(px:Float, py:Float):Bool
	{
		var r:Array<Float> = hitRect();
		return px >= r[0] && px <= r[0] + r[2] && py >= r[1] && py <= r[1] + r[3];
	}

	public function setSelected(value:Bool):Void
	{
		if (seqTime >= 0) return;
		isSelected = value;
		isInverted = false;
		var s:Float = value ? SELECT_SCALE : REST_SCALE;
		scale.set(s, s);
		applyGraphic();
	}

	public function playAccept(?finished:Void->Void):Void
	{
		onFinish = finished;
		seqTime = 0;
		applySequence(0);
	}

	function applySequence(frame:Int):Void
	{
		var s:Float = ACCEPT_SCALE[frame];
		scale.set(s, s);
		isInverted = ACCEPT_INVERT[frame];
		isSelected = ACCEPT_SELECT[frame];
		applyGraphic();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (seqTime < 0) return;

		seqTime += elapsed;
		var frame:Int = Std.int(seqTime * 24);
		if (frame >= ACCEPT_SCALE.length)
		{
			seqTime = -1;
			isInverted = false;
			isSelected = false;
			scale.set(REST_SCALE, REST_SCALE);
			applyGraphic();
			var cb:Void->Void = onFinish;
			onFinish = null;
			if (cb != null) cb();
			return;
		}
		applySequence(frame);
	}
}
