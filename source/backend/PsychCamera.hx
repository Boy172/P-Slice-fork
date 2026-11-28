package backend;

import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
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

		updateFlashSpritePosition();
		updateShake(elapsed);
		updateRenderScale();
	}

	static inline var MAX_RENDER_PIXELS:Float = 4096;
	static inline var MIN_RENDER_QUALITY:Float = 0.1;
	static inline var QUALITY_EPSILON:Float = 0.995;

	var renderFrames:Int = 0;
	var renderScaleActive:Bool = false;
	var renderScaleX:Float = 0;
	var renderScaleY:Float = 0;
	final renderBounds:Rectangle = new Rectangle();

	@:access(openfl.display.DisplayObject)
	function releaseRenderBuffers():Void
	{
		final sprite = flashSprite;
		final first:BitmapData = sprite.__cacheBitmapData;
		final second:BitmapData = sprite.__cacheBitmapData2;
		final third:BitmapData = sprite.__cacheBitmapData3;

		sprite.__cacheBitmap = null;
		sprite.__cacheBitmapData = null;
		sprite.__cacheBitmapData2 = null;
		sprite.__cacheBitmapData3 = null;
		sprite.__cacheBitmapRenderer = null;

		if (first != null)
			first.dispose();
		if (second != null && second != first)
			second.dispose();
		if (third != null && third != first && third != second)
			third.dispose();
	}

	function restoreRenderScale():Void
	{
		if (!renderScaleActive)
			return;

		renderScaleActive = false;
		renderScaleX = 0;
		renderScaleY = 0;
		flashSprite.cacheAsBitmapMatrix = null;
		flashSprite.cacheAsBitmap = false;
		releaseRenderBuffers();
	}

	@:access(openfl.display.DisplayObject)
	function updateRenderScale():Void
	{
		if (renderFrames < 2)
			renderFrames++;

		var quality:Float = ClientPrefs.data.gameResolution / 100;
		if (filtersEnabled && filters != null && filters.length > 0)
			quality *= ClientPrefs.data.shaderQuality / 100;

		if (quality >= QUALITY_EPSILON)
		{
			restoreRenderScale();
			return;
		}

		if (renderFrames < 2)
			return;

		final sprite = flashSprite;
		final world:Matrix = sprite.__renderTransform;
		if (world == null)
			return;

		final worldX:Float = Math.sqrt(world.a * world.a + world.b * world.b);
		final worldY:Float = Math.sqrt(world.c * world.c + world.d * world.d);
		if (worldX <= 0 || worldY <= 0)
			return;

		final largest:Float = Math.max(worldX * width, worldY * height);
		if (largest > 0 && largest * quality > MAX_RENDER_PIXELS)
			quality = MAX_RENDER_PIXELS / largest;
		if (quality < MIN_RENDER_QUALITY)
			quality = MIN_RENDER_QUALITY;

		if (quality >= QUALITY_EPSILON)
		{
			restoreRenderScale();
			return;
		}

		final scaleX:Float = worldX * quality;
		final scaleY:Float = worldY * quality;

		if (!renderScaleActive)
		{
			renderScaleActive = true;
			sprite.cacheAsBitmap = true;
		}

		if (sprite.cacheAsBitmapMatrix == null
			|| Math.abs(scaleX - renderScaleX) > 0.002
			|| Math.abs(scaleY - renderScaleY) > 0.002)
		{
			renderScaleX = scaleX;
			renderScaleY = scaleY;
			releaseRenderBuffers();
			sprite.cacheAsBitmapMatrix = new Matrix(scaleX, 0, 0, scaleY, 0, 0);
		}

		final matrix:Matrix = sprite.cacheAsBitmapMatrix;
		renderBounds.setTo(0, 0, 0, 0);
		sprite.__getFilterBounds(renderBounds, matrix);

		final offsetX:Float = renderBounds.x > 0 ? Math.ceil(renderBounds.x) : Math.floor(renderBounds.x);
		final offsetY:Float = renderBounds.y > 0 ? Math.ceil(renderBounds.y) : Math.floor(renderBounds.y);

		var parentX:Float = Math.abs(sprite.scaleX) > 0 ? worldX / Math.abs(sprite.scaleX) : 1;
		var parentY:Float = Math.abs(sprite.scaleY) > 0 ? worldY / Math.abs(sprite.scaleY) : 1;
		if (parentX <= 0)
			parentX = 1;
		if (parentY <= 0)
			parentY = 1;

		final localX:Float = offsetX * (worldX / matrix.a - 1) / parentX;
		final localY:Float = offsetY * (worldY / matrix.d - 1) / parentY;

		final radians:Float = sprite.rotation * Math.PI / 180;
		final cos:Float = Math.cos(radians);
		final sin:Float = Math.sin(radians);

		sprite.x += localX * cos - localY * sin;
		sprite.y += localX * sin + localY * cos;
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
