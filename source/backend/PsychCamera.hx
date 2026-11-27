package backend;

import openfl.geom.Matrix;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

// PsychCamera handles followLerp based on elapsed
// and stops camera from snapping at higher framerates

class PsychCamera extends FlxCamera
{
	override public function update(elapsed:Float):Void
	{
		// follow the target, if there is one
		if (target != null)
		{
			updateFollowDelta(elapsed);
		}

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;
		updateRenderScale();

		updateFlashSpritePosition();
		updateShake(elapsed);
	}

	static inline var MAX_RENDER_PIXELS:Float = 4096;

	var renderFrames:Int = 0;
	var renderScaleActive:Bool = false;

	function restoreRenderScale():Void
	{
		if (!renderScaleActive)
			return;
		renderScaleActive = false;
		flashSprite.cacheAsBitmapMatrix = null;
		flashSprite.cacheAsBitmap = false;
	}

	function updateRenderScale():Void
	{
		var quality:Float = ClientPrefs.data.gameResolution / 100;
		var hasFilters:Bool = filtersEnabled && filters != null && filters.length > 0;
		if (hasFilters)
			quality *= ClientPrefs.data.shaderQuality / 100;

		if (Math.abs(quality - 1) < 0.005)
		{
			restoreRenderScale();
			return;
		}

		if (renderFrames < 3)
		{
			renderFrames++;
			return;
		}

		var world:Matrix = @:privateAccess flashSprite.__renderTransform;
		if (world == null)
			return;

		var pixelsX:Float = Math.abs(world.a) * width + Math.abs(world.c) * height;
		var pixelsY:Float = Math.abs(world.b) * width + Math.abs(world.d) * height;
		var largest:Float = Math.max(pixelsX, pixelsY);
		if (largest <= 0)
			return;
		if (largest * quality > MAX_RENDER_PIXELS)
			quality = MAX_RENDER_PIXELS / largest;

		var current:Matrix = flashSprite.cacheAsBitmapMatrix;
		var scaleA:Float = world.a * quality;
		var scaleB:Float = world.b * quality;
		var scaleC:Float = world.c * quality;
		var scaleD:Float = world.d * quality;

		if (!renderScaleActive)
		{
			renderScaleActive = true;
			flashSprite.cacheAsBitmap = true;
		}

		if (current == null
			|| Math.abs(current.a - scaleA) > 0.002
			|| Math.abs(current.b - scaleB) > 0.002
			|| Math.abs(current.c - scaleC) > 0.002
			|| Math.abs(current.d - scaleD) > 0.002)
			flashSprite.cacheAsBitmapMatrix = new Matrix(scaleA, scaleB, scaleC, scaleD, 0, 0);
	}

	public function updateFollowDelta(?elapsed:Float = 0):Void
	{
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= viewRight)
				{
					_scrollTarget.x += viewWidth;
				}
				else if (targetX + target.width < viewLeft)
				{
					_scrollTarget.x -= viewWidth;
				}

				if (targetY >= viewBottom)
				{
					_scrollTarget.y += viewHeight;
				}
				else if (targetY + target.height < viewTop)
				{
					_scrollTarget.y -= viewHeight;
				}
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
				{
					_scrollTarget.x = edge;
				}
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
				{
					_scrollTarget.x = edge;
				}

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
				{
					_scrollTarget.y = edge;
				}
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
				{
					_scrollTarget.y = edge;
				}
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
				{
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				}
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}

		var mult:Float = 1 - Math.exp(-elapsed * followLerp / (1/60));
		scroll.x += (_scrollTarget.x - scroll.x) * mult;
		scroll.y += (_scrollTarget.y - scroll.y) * mult;
		//trace('lerp on this frame: $mult');
	}
	// Fixes some scripts assuming we are on the filxel 5.6.2
	public function setFilters(newShaders:Array<ShaderFilter>) {
		this.filters = cast newShaders;
	}
	// override function set_followLerp(value:Float)
	// {
	// 	return followLerp = value;
	// }
}
