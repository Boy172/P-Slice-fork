package mikolka.vslice.ui.mods;

import flixel.sound.FlxSound;

class ModMenuAmbience
{
	static final SOUNDS:Array<String> = [
		'1_horse', '3_moo', '60_knocking', '60_scream', '200_roar1', '200_roar2', '200_roar3', '200_sob1', '200_sob2', '200_sob3', '400_creaking',
		'400_creaking2', '400_dragging', '400_moaning', '400_moaning2', '400_pulley1', '400_pulley2', '400_pulley3', '400_slam', '600_beep1', '600_beep2',
		'600_beep3', '600_beep4', '600_beep5', '600_beep6', '600_beep7', '600_beep8', '600_chains1', '600_chains2', '600_chains3'
	];

	static inline var FIRST_WAIT:Float = 7.0;
	static inline var EASTER_EGG_AT:Float = 180.0;

	var names:Array<String> = [];
	var weights:Array<Float> = [];
	var loop:FlxSound;
	var egg:FlxSound;
	var timer:Float = FIRST_WAIT;
	var elapsedTotal:Float = 0;
	var eggPlayed:Bool = false;
	var started:Bool = false;

	public function new()
	{
		for (entry in SOUNDS)
		{
			var cut:Int = entry.indexOf('_');
			names.push(entry);
			weights.push(Std.parseFloat(entry.substr(0, cut)));
		}
	}

	public function start():Void
	{
		var sound = Paths.sound('vmods/mod-menu-ambience');
		if (sound == null) return;
		loop = FlxG.sound.load(sound, 0, true);
		loop.play();
		loop.fadeIn(4, 0, 1);
		started = true;
	}

	public function update(elapsed:Float):Void
	{
		if (!started) return;

		elapsedTotal += elapsed;
		if (!eggPlayed && elapsedTotal >= EASTER_EGG_AT)
		{
			eggPlayed = true;
			var eggSound = Paths.sound('vmods/sounds/phantomarcade-trapped');
			if (eggSound != null) egg = FlxG.sound.play(eggSound);
		}

		timer -= elapsed;
		if (timer > 0 || names.length == 0) return;

		timer = FlxG.random.float(6, 10);
		playRandom();
	}

	function playRandom():Void
	{
		var total:Float = 0;
		for (w in weights) total += w;

		var roll:Float = FlxG.random.float(0, total);
		var pick:Int = names.length - 1;
		var acc:Float = 0;
		for (i in 0...names.length)
		{
			acc += weights[i];
			if (roll <= acc)
			{
				pick = i;
				break;
			}
		}

		var sound = Paths.sound('vmods/sounds/' + names[pick]);
		if (sound != null) FlxG.sound.play(sound, 0.8);

		if (weights[pick] <= 1)
		{
			names.splice(pick, 1);
			weights.splice(pick, 1);
		}
	}

	public function stop():Void
	{
		if (loop != null)
		{
			loop.stop();
			loop.destroy();
			loop = null;
		}
		if (egg != null)
		{
			egg.stop();
			egg = null;
		}
		started = false;
	}
}
