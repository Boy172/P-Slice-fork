package mikolka.vslice.components;

import flixel.FlxG;
import flixel.input.touch.FlxTouch;
import flixel.math.FlxMath;

class SwipeValueInput
{
	public var left(default, null):Bool = false;
	public var right(default, null):Bool = false;
	public var leftP(default, null):Bool = false;
	public var rightP(default, null):Bool = false;
	public var leftR(default, null):Bool = false;
	public var rightR(default, null):Bool = false;
	public var horizontal(default, null):Bool = false;
	public var stepPixels:Float = 24;
	public var enabled:Bool = true;

	static inline var LOCK_DISTANCE:Float = 14;
	static inline var HORIZONTAL_BIAS:Float = 1.2;
	static inline var MAX_PENDING_STEPS:Int = 60;
	static inline var FULL_SWIPE_PIXELS:Float = 700;

	var axis:Int = 0;
	var touchId:Int = -1;
	var startX:Float = 0;
	var startY:Float = 0;
	var lastX:Float = 0;
	var accumulated:Float = 0;
	var pendingSteps:Int = 0;
	var lastDirection:Int = 0;
	var stepping:Bool = false;

	public function new() {}

	public function configure(totalSteps:Float, isChoice:Bool):Void
	{
		if (isChoice) stepPixels = 90;
		else if (Math.isNaN(totalSteps) || totalSteps <= 0 || totalSteps == Math.POSITIVE_INFINITY) stepPixels = 30;
		else stepPixels = FlxMath.bound(FULL_SWIPE_PIXELS / totalSteps, 8, 60);
	}

	public function update(elapsed:Float):Void
	{
		left = right = leftP = rightP = leftR = rightR = false;

		#if TOUCH_CONTROLS_ALLOWED
		if (enabled) updateTouch();
		else if (touchId != -1 || axis != 0) endTouch();

		horizontal = axis == 1 || axis == 3;
		emitSteps();

		if (axis == 3) axis = 0;
		#end
	}

	#if TOUCH_CONTROLS_ALLOWED
	function updateTouch():Void
	{
		var touch:FlxTouch = null;

		for (candidate in FlxG.touches.list)
		{
			if (candidate == null) continue;

			if (touchId == -1)
			{
				if (candidate.justPressed)
				{
					touchId = candidate.touchPointID;
					touch = candidate;
					beginTouch(candidate);
					break;
				}
			}
			else if (candidate.touchPointID == touchId)
			{
				touch = candidate;
				break;
			}
		}

		if (touchId == -1) return;

		if (touch == null || touch.justReleased || !touch.pressed)
		{
			endTouch();
			return;
		}

		moveTouch(touch);
	}

	function beginTouch(touch:FlxTouch):Void
	{
		startX = touch.viewX;
		startY = touch.viewY;
		lastX = startX;
		accumulated = 0;
		axis = 0;
		pendingSteps = 0;
	}

	function moveTouch(touch:FlxTouch):Void
	{
		var x:Float = touch.viewX;
		var y:Float = touch.viewY;

		if (axis == 0)
		{
			var dx:Float = x - startX;
			var dy:Float = y - startY;

			if (Math.max(Math.abs(dx), Math.abs(dy)) < LOCK_DISTANCE) return;

			if (Math.abs(dx) > Math.abs(dy) * HORIZONTAL_BIAS)
			{
				axis = 1;
				accumulated = dx;
			}
			else axis = 2;

			lastX = x;
		}
		else if (axis == 1)
		{
			accumulated += x - lastX;
			lastX = x;
		}

		if (axis != 1) return;

		var steps:Int = Std.int(accumulated / stepPixels);
		if (steps == 0) return;

		accumulated -= steps * stepPixels;
		pendingSteps = Std.int(FlxMath.bound(pendingSteps + steps, -MAX_PENDING_STEPS, MAX_PENDING_STEPS));
	}

	function endTouch():Void
	{
		touchId = -1;
		axis = axis == 1 ? 3 : 0;
		pendingSteps = 0;
	}

	function emitSteps():Void
	{
		if (pendingSteps != 0)
		{
			var direction:Int = pendingSteps > 0 ? 1 : -1;
			pendingSteps -= direction;
			lastDirection = direction;
			stepping = true;

			if (direction < 0) left = leftP = true;
			else right = rightP = true;
		}
		else if (stepping)
		{
			stepping = false;

			if (lastDirection < 0) leftR = true;
			else rightR = true;
		}
	}
	#end
}
