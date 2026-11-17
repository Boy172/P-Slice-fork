package mikolka.vslice.components;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.input.touch.FlxTouch;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import openfl.display.BlendMode;

class TouchPointerPlugin extends FlxTypedSpriteGroup<TouchPointer>
{
	public static var enabled(default, set):Bool = true;

	static var instance:TouchPointerPlugin = null;
	static var pointerCamera:FlxCamera;

	public function new()
	{
		super();
	}

	public static function initialize():Void
	{
		#if (TOUCH_CONTROLS_ALLOWED || mobile)
		if (instance != null) return;

		if (FlxG.game == null || FlxG.state == null)
		{
			FlxG.signals.postStateSwitch.addOnce(initialize);
			return;
		}

		TouchPadHider.initialize();

		pointerCamera = new FlxCamera();
		pointerCamera.bgColor.alpha = 0;
		instance = new TouchPointerPlugin();
		instance.cameras = [pointerCamera];

		enabled = isSavedEnabled();

		FlxG.cameras.add(pointerCamera, false);
		FlxG.plugins.drawOnTop = true;
		FlxG.plugins.addPlugin(instance);

		function moveCameraToTop(camera:FlxCamera):Void
		{
			if (pointerCamera == null) return;

			if (FlxG.cameras.list.length == 0)
			{
				FlxG.signals.postStateSwitch.addOnce(moveCameraToTop.bind(null));
				return;
			}

			if (FlxG.cameras.list.contains(pointerCamera)) FlxG.cameras.list.remove(pointerCamera);

			if (FlxG.game.contains(pointerCamera.flashSprite)) FlxG.game.removeChild(pointerCamera.flashSprite);

			@:privateAccess
			FlxG.game.addChildAt(pointerCamera.flashSprite, FlxG.game.getChildIndex(FlxG.game._inputContainer));
			FlxG.cameras.list.push(pointerCamera);
		}

		FlxG.cameras.cameraAdded.add(moveCameraToTop);

		FlxG.cameras.cameraRemoved.add(function(camera:FlxCamera)
		{
			if (camera == pointerCamera)
			{
				if (!camera.exists)
				{
					instance.cameras = [pointerCamera = new FlxCamera()];
					moveCameraToTop(null);
					pointerCamera.bgColor.alpha = 0;
					pointerCamera.ID = FlxG.cameras.list.length - 1;
				}
				else
				{
					moveCameraToTop(null);
				}
			}
			else
			{
				moveCameraToTop(null);
			}
		});

		FlxG.signals.preStateSwitch.add(function()
		{
			instance.removeAll();
		});
		#end
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (touch in FlxG.touches.list)
		{
			if (touch == null) continue;

			if (touch.justPressed) removeAll(true);

			var pointer:TouchPointer = findPointerByTouchId(touch.touchPointID);

			if (pointer == null)
			{
				pointer = recycle(TouchPointer);
				pointer.initialize(touch.touchPointID);
				add(pointer);
			}

			pointer.updateFromTouch(touch, pointerCamera);
		}

		for (pointer in members)
		{
			if (pointer == null || touchExists(pointer.touchId)) continue;
			if (pointer.touchId != -2)
			{
				pointer.alpha = 0.8;
				FlxTween.tween(pointer, {alpha: 0}, FlxG.random.float(0.8, 0.9), {
					ease: FlxEase.cubeIn,
					onComplete: function(_)
					{
						remove(pointer, true);
					}
				});
				pointer.touchId = -2;
			}
		}
	}

	function findPointerByTouchId(touchId:Int):TouchPointer
	{
		for (pointer in members)
		{
			if (pointer == null || pointer.touchId != touchId) continue;

			return pointer;
		}
		return null;
	}

	function touchExists(touchId:Int):Bool
	{
		for (touch in FlxG.touches.list)
		{
			if (touch.touchPointID != touchId) continue;

			return true;
		}
		return false;
	}

	public static function isSavedEnabled():Bool
	{
		return FlxG.save == null || FlxG.save.data == null || FlxG.save.data.pslideHideTouchPointer != true;
	}

	public static function toggle():Void
	{
		enabled = !enabled;

		if (FlxG.save != null && FlxG.save.data != null)
		{
			FlxG.save.data.pslideHideTouchPointer = !enabled;
			FlxG.save.flush();
		}
	}

	@:noCompletion
	static function set_enabled(value:Bool):Bool
	{
		if (instance != null)
		{
			instance.exists = instance.visible = instance.active = instance.alive = value;
		}

		return enabled = value;
	}

	public function removeAll(skipTween:Bool = false):Void
	{
		for (pointer in members)
		{
			if (pointer == null) continue;

			if (skipTween)
			{
				FlxTween.cancelTweensOf(pointer);
				remove(pointer, true);
				continue;
			}

			pointer.alpha = 0.8;
			FlxTween.tween(pointer, {alpha: 0}, FlxG.random.float(0.8, 1), {
				ease: FlxEase.quadIn,
				onComplete: function(_)
				{
					remove(pointer, true);
				}
			});
		}
	}
}

class TouchPointer extends FlxSprite
{
	static var idleGraphic:FlxGraphic;
	static var movingGraphic:FlxGraphic;
	static var missingImages:Bool = false;

	public var touchId:Int = -1;

	var viewPoint:FlxPoint;
	var lastPosition:FlxPoint;
	var hasLastPosition:Bool = false;
	var moving:Bool = false;

	public function new()
	{
		super();
		scrollFactor.set(0, 0);
		color = 0xFF6666E1;
		blend = BlendMode.SCREEN;
		viewPoint = FlxPoint.get();
		lastPosition = FlxPoint.get();
	}

	public function initialize(touchId:Int):Void
	{
		this.touchId = touchId;
		alpha = 1;
		angle = 0;
		moving = false;
		hasLastPosition = false;
		applyGraphic(false);
	}

	public function updateFromTouch(touch:FlxTouch, camera:FlxCamera):Void
	{
		touch.getViewPosition(camera, viewPoint);

		if (!hasLastPosition)
		{
			lastPosition.copyFrom(viewPoint);
			hasLastPosition = true;
		}

		var isMoving:Bool = lastPosition.distanceTo(FlxPoint.weak(viewPoint.x, viewPoint.y)) > 3;
		applyGraphic(isMoving);

		x = viewPoint.x - width / 2;
		y = viewPoint.y - height / 2;

		if (camera.target != null)
		{
			x -= camera.target.x;
			y -= camera.target.y;
		}

		if (isMoving) angle = FlxAngle.angleBetweenPoint(this, lastPosition, true);
		else angle = 0;

		lastPosition.copyFrom(viewPoint);
	}

	function applyGraphic(isMoving:Bool):Void
	{
		if (graphic != null && moving == isMoving) return;

		var target:FlxGraphic = isMoving ? getMovingGraphic() : getIdleGraphic();
		if (target == null) return;

		moving = isMoving;
		loadGraphic(target);
		color = 0xFF6666E1;
		blend = BlendMode.SCREEN;
	}

	static function getIdleGraphic():FlxGraphic
	{
		if (idleGraphic == null || idleGraphic.bitmap == null) idleGraphic = loadCached('michael');
		return idleGraphic;
	}

	static function getMovingGraphic():FlxGraphic
	{
		if (movingGraphic == null || movingGraphic.bitmap == null) movingGraphic = loadCached('kevin');
		return movingGraphic;
	}

	static function loadCached(name:String):FlxGraphic
	{
		if (missingImages) return null;

		var source:FlxGraphic = Paths.image('cursor/' + name, null, false);
		if (source == null || source.bitmap == null)
		{
			missingImages = true;
			return null;
		}

		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(source.bitmap.clone(), false, null, false);
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		return graphic;
	}

	override public function destroy():Void
	{
		viewPoint.put();
		lastPosition.put();
		super.destroy();
	}
}
