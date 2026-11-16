package mikolka.vslice.components;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.touch.FlxTouch;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxSignal;

class FunkinBackButton extends FlxSprite
{
	public var onConfirmStart(default, null):FlxSignal = new FlxSignal();
	public var onConfirmEnd(default, null):FlxSignal = new FlxSignal();
	public var enabled:Bool = true;
	public var restingOpacity:Float;
	public var confirming(get, never):Bool;

	var _confirming:Bool = false;
	var held:Bool = false;
	var instant:Bool = false;
	var activeTouchID:Int = -1;

	function get_confirming():Bool
	{
		return _confirming;
	}

	public function new(x:Float = 0, y:Float = 0, ?confirmCallback:Void->Void, restingOpacity:Float = 0.3, instant:Bool = false)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('backButton');
		animation.addByIndices('idle', 'back', [0], '', 24, false);
		animation.addByIndices('hold', 'back', [5], '', 24, false);
		animation.addByIndices('confirm', 'back', [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22], '', 24, false);
		animation.play('idle');

		scale.set(0.7, 0.7);
		updateHitbox();
		scrollFactor.set();
		antialiasing = ClientPrefs.data.antialiasing;

		this.restingOpacity = restingOpacity;
		this.instant = instant;
		this.alpha = restingOpacity;

		if (confirmCallback != null) onConfirmEnd.add(confirmCallback);
	}

	override function update(elapsed:Float):Void
	{
		#if android
		if (FlxG.android.justReleased.BACK) onConfirmEnd.dispatch();
		#end

		super.update(elapsed);

		if (!enabled || _confirming) return;

		for (touch in FlxG.touches.list)
		{
			var over:Bool = isTouchOver(touch);

			if (touch.justPressed && over)
			{
				activeTouchID = touch.touchPointID;
				playHoldAnim();
			}
			else if (touch.touchPointID == activeTouchID)
			{
				if (touch.justReleased)
				{
					activeTouchID = -1;
					if (over) playConfirmAnim();
					else playOutAnim();
				}
				else if (!over)
				{
					activeTouchID = -1;
					playOutAnim();
				}
			}
		}
	}

	function isTouchOver(touch:FlxTouch):Bool
	{
		for (cam in cameras)
		{
			var worldPos = touch.getWorldPosition(cam, _point);
			if (overlapsPoint(worldPos, true, cam)) return true;
		}
		return false;
	}

	function playHoldAnim():Void
	{
		if (_confirming || held || !enabled) return;

		held = true;
		FlxTween.cancelTweensOf(this);
		animation.play('hold');
		alpha = 1;
	}

	function playConfirmAnim():Void
	{
		if (!enabled || _confirming) return;

		if (instant)
		{
			onConfirmEnd.dispatch();
			return;
		}

		_confirming = true;
		FlxTween.cancelTweensOf(this);
		animation.play('confirm');
		alpha = 1;

		FlxG.sound.play(Paths.sound('cancelMenu'));
		onConfirmStart.dispatch();

		animation.onFinish.addOnce(function(name:String)
		{
			if (name != 'confirm') return;
			_confirming = false;
			held = false;
			onConfirmEnd.dispatch();
		});
	}

	function playOutAnim():Void
	{
		if (_confirming || !enabled) return;

		FlxTween.cancelTweensOf(this);
		animation.play('idle');

		FlxTween.tween(this, {alpha: restingOpacity}, 0.5, {
			ease: FlxEase.expoOut,
			onComplete: function(tween:FlxTween):Void
			{
				held = false;
			}
		});
	}

	public function resetState():Void
	{
		FlxTween.cancelTweensOf(this);
		_confirming = false;
		held = false;
		activeTouchID = -1;
		animation.play('idle');
		alpha = restingOpacity;
	}

	override function destroy():Void
	{
		FlxTween.cancelTweensOf(this);
		onConfirmStart.removeAll();
		onConfirmEnd.removeAll();
		if (animation != null && animation.onFinish != null) animation.onFinish.removeAll();
		super.destroy();
	}
}
