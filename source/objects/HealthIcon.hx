package objects;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	public var baseScale:Float = 1;
	public var restWidth:Float = 150;
	public var shouldBop:Bool = true;
	public var userOffsetX:Float = 0;
	public var userOffsetY:Float = 0;

	public function logicalWidth():Float
	{
		return restWidth * scale.x / baseScale;
	}

	public function configure(id:String, size:Float = 1, flip:Bool = false, pixel:Bool = false, bop:Bool = true, offsetX:Float = 0, offsetY:Float = 0, ?allowGPU:Bool = true):Void
	{
		this.char = '';
		changeIcon(id, allowGPU);

		var longSide:Float = Math.max(frameWidth, frameHeight);
		restWidth = 150 * size;
		baseScale = restWidth / longSide;
		shouldBop = bop;
		userOffsetX = offsetX;
		userOffsetY = offsetY;
		iconOffsets[0] = (frameWidth - restWidth) / 2;
		iconOffsets[1] = (frameHeight - restWidth) / 2;

		flipX = flip != isPlayer;
		antialiasing = pixel ? false : ClientPrefs.data.antialiasing;

		scale.set(baseScale, baseScale);
		updateHitbox();
	}

	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(this.char != char) {
			baseScale = 1;
			restWidth = 150;
			shouldBop = true;
			userOffsetX = 0;
			userOffsetY = 0;
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			
			var graphic = Paths.image(name, allowGPU);
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(char.endsWith('-pixel'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0] + userOffsetX;
			offset.y = iconOffsets[1] + userOffsetY;
		}
	}

	public function getCharacter():String {
		return char;
	}
}
