package mikolka.vslice.ui.mods;

import flixel.sound.FlxSound;

class ModMenuSparks extends ModAtlas
{
	static inline var SHOCK_SOUND_END_TIME:Float = (83 / 24) * 1000;

	var countdown:Float = 0;
	var timerOn:Bool = true;
	var previous:Int = 0;
	var shockSound:FlxSound;
	var busy:Bool = false;

	public function new()
	{
		super(0, 0, 'vmods/sparks');
		applyStageMatrix = true;
		visible = false;
		antialiasing = ClientPrefs.data.antialiasing;
		startTimer();
		onComplete.add(onDone);
	}

	function startTimer():Void
	{
		countdown = FlxG.random.int(6, 20);
		timerOn = true;
	}

	function onDone(name:String):Void
	{
		if (name == 'electrocution') return;

		busy = false;
		visible = false;
		if (name != 'end') startTimer();
	}

	public function startElectrocution():Void
	{
		timerOn = false;
		busy = true;
		visible = true;
		playAnimation('electrocution', true, false, true);
		var sound = Paths.sound('vmods/sounds/sparks/electrocution');
		if (sound != null) shockSound = FlxG.sound.play(sound);
	}

	public function endElectrocution():Void
	{
		playAnimation('end', true);
		if (shockSound != null && shockSound.playing) shockSound.time = SHOCK_SOUND_END_TIME;
	}

	function playRandom():Void
	{
		var pick:Int = FlxG.random.int(1, 11);
		if (pick == previous) pick = pick % 11 + 1;
		previous = pick;

		busy = true;
		visible = true;
		playAnimation('spark $pick', true);

		var sound = Paths.sound('vmods/sounds/sparks/spark-$pick');
		if (sound != null) FlxG.sound.play(sound);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!timerOn || busy) return;

		countdown -= elapsed;
		if (countdown <= 0)
		{
			timerOn = false;
			playRandom();
		}
	}

	override public function destroy():Void
	{
		if (shockSound != null) shockSound.stop();
		super.destroy();
	}
}
