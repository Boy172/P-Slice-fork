package mikolka.vslice.components;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.input.touch.FlxTouch;

class ListTouch
{
	public var enabled:Bool = true;
	public var stepPixels:Float = 60;
	public var holdSeconds:Float = 0.7;
	public var ignore:Array<FlxBasic> = [];
	public var getItems:Void->Array<FlxBasic>;
	public var onStepY:Int->Void;
	public var onStepX:Int->Void;
	public var onTapItem:Int->Void;
	public var onHoldItem:Int->Void;

	static inline var LOCK_DISTANCE:Float = 14;
	static inline var HORIZONTAL_BIAS:Float = 1.2;

	var touchId:Int = -1;
	var startX:Float = 0;
	var startY:Float = 0;
	var lastX:Float = 0;
	var lastY:Float = 0;
	var accumulated:Float = 0;
	var axis:Int = 0;
	var heldTime:Float = 0;
	var holdFired:Bool = false;

	public function new(getItems:Void->Array<FlxBasic>, ?onStepY:Int->Void, ?onTapItem:Int->Void)
	{
		this.getItems = getItems;
		this.onStepY = onStepY;
		this.onTapItem = onTapItem;
	}

	public function update(elapsed:Float):Void
	{
		#if TOUCH_CONTROLS_ALLOWED
		if (!enabled)
		{
			reset();
			return;
		}

		var touch:FlxTouch = null;

		for (candidate in FlxG.touches.list)
		{
			if (candidate == null) continue;

			if (touchId == -1)
			{
				if (candidate.justPressed && !overlapsIgnored(candidate))
				{
					begin(candidate);
					touch = candidate;
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

		if (touch == null)
		{
			reset();
			return;
		}

		if (touch.justReleased || !touch.pressed)
		{
			finish(touch);
			return;
		}

		move(touch, elapsed);
		#end
	}

	public function reset():Void
	{
		touchId = -1;
		axis = 0;
		accumulated = 0;
		heldTime = 0;
		holdFired = false;
	}

	#if TOUCH_CONTROLS_ALLOWED
	function begin(touch:FlxTouch):Void
	{
		touchId = touch.touchPointID;
		startX = lastX = touch.viewX;
		startY = lastY = touch.viewY;
		accumulated = 0;
		axis = 0;
		heldTime = 0;
		holdFired = false;
	}

	function move(touch:FlxTouch, elapsed:Float):Void
	{
		var x:Float = touch.viewX;
		var y:Float = touch.viewY;

		if (axis == 0)
		{
			var dx:Float = x - startX;
			var dy:Float = y - startY;

			if (Math.max(Math.abs(dx), Math.abs(dy)) < LOCK_DISTANCE)
			{
				heldTime += elapsed;
				if (!holdFired && onHoldItem != null && heldTime >= holdSeconds)
				{
					var index:Int = itemAt(touch);
					if (index >= 0)
					{
						holdFired = true;
						onHoldItem(index);
					}
				}
				return;
			}

			if (Math.abs(dx) > Math.abs(dy) * HORIZONTAL_BIAS)
			{
				axis = 1;
				accumulated = 0;
			}
			else
			{
				axis = 2;
				accumulated = 0;
			}

			lastX = x;
			lastY = y;
			return;
		}

		if (axis == 1)
		{
			accumulated += lastX - x;
			lastX = x;
			emit(onStepX);
		}
		else
		{
			accumulated += lastY - y;
			lastY = y;
			emit(onStepY);
		}
	}

	function emit(callback:Int->Void):Void
	{
		while (Math.abs(accumulated) >= stepPixels)
		{
			var direction:Int = accumulated > 0 ? 1 : -1;
			accumulated -= direction * stepPixels;
			if (callback != null) callback(direction);
		}
	}

	function finish(touch:FlxTouch):Void
	{
		var wasTap:Bool = axis == 0 && !holdFired;
		reset();

		if (!wasTap || onTapItem == null) return;

		var index:Int = itemAt(touch);
		if (index >= 0) onTapItem(index);
	}

	function itemAt(touch:FlxTouch):Int
	{
		var items:Array<FlxBasic> = getItems != null ? getItems() : null;
		if (items == null) return -1;

		for (i in 0...items.length)
		{
			var obj:FlxBasic = items[i];
			if (obj != null && obj.exists && obj.visible && touch.overlaps(obj, obj.camera)) return i;
		}

		return -1;
	}

	function overlapsIgnored(touch:FlxTouch):Bool
	{
		for (obj in ignore)
			if (obj != null && obj.exists && touch.overlaps(obj, obj.camera)) return true;

		return false;
	}
	#end
}
