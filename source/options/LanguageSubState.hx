package options;

import openfl.utils.Assets;
import mikolka.vslice.components.FunkinBackButton;
import mikolka.vslice.components.ListTouch;

class LanguageSubState extends MusicBeatSubstate
{
	#if TRANSLATIONS_ALLOWED
	var grpLanguages:FlxTypedGroup<Alphabet> = new FlxTypedGroup<Alphabet>();
	var languages:Array<String> = [];
	var displayLanguages:Map<String, String> = [];
	var curSelected:Int = 0;

	#if TOUCH_CONTROLS_ALLOWED
	var listTouch:ListTouch;
	var backButton:FunkinBackButton;
	var backCam:FlxCamera;
	#end

	public function new()
	{
		controls.isInSubstate = true;
		super();

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.screenCenter();
		add(bg);
		add(grpLanguages);

		languages.push(ClientPrefs.defaultData.language); //English (US)
		displayLanguages.set(ClientPrefs.defaultData.language, Language.defaultLangName);
		var directories:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'data/');
		for (directory in directories)
		{
			for (file in NativeFileSystem.readDirectory(directory))
			{
				if(file.toLowerCase().endsWith('.lang'))
				{
					var langFile:String = file.substring(0, file.length - '.lang'.length).trim();
					if(!languages.contains(langFile))
						languages.push(langFile);

					if(!displayLanguages.exists(langFile))
					{
						var path:String = '$directory/$file';
						var txt:String = NativeFileSystem.getContent(path);

						var id:Int = txt.indexOf('\n');
						if(id > 0) //language display name shouldnt be an empty string or null
						{
							var name:String = txt.substr(0, id).trim();
							if(!name.contains(':')) displayLanguages.set(langFile, name);
						}
						else if(txt.trim().length > 0 && !txt.contains(':')) displayLanguages.set(langFile, txt.trim());
					}
				}
			}
		}

		languages.sort(function(a:String, b:String)
		{
			a = (displayLanguages.exists(a) ? displayLanguages.get(a) : a).toLowerCase();
			b = (displayLanguages.exists(b) ? displayLanguages.get(b) : b).toLowerCase();
			if (a < b) return -1;
			else if (a > b) return 1;
			return 0;
		});

		//trace(ClientPrefs.data.language);
		curSelected = languages.indexOf(ClientPrefs.data.language);
		if(curSelected < 0)
		{
			//trace('Language not found: ' + ClientPrefs.data.language);
			ClientPrefs.data.language = ClientPrefs.defaultData.language;
			curSelected = Std.int(Math.max(0, languages.indexOf(ClientPrefs.data.language)));
		}

		for (num => lang in languages)
		{
			var name:String = displayLanguages.get(lang);
			if(name == null) name = lang;

			var text:Alphabet = new Alphabet(0, 300, name, true);
			text.isMenuItem = true;
			text.targetY = num;
			text.changeX = false;
			text.distancePerItem.y = 100;
			if(languages.length < 7)
			{
				text.changeY = false;
				text.screenCenter(Y);
				text.y += (100 * (num - (languages.length / 2))) + 45;
			}
			text.screenCenter(X);
			grpLanguages.add(text);
		}
		changeSelected();

		#if TOUCH_CONTROLS_ALLOWED
		backCam = new FlxCamera();
		backCam.bgColor.alpha = 0;
		FlxG.cameras.add(backCam, false);

		backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, goBack, 0.3);
		backButton.cameras = [backCam];
		add(backButton);

		listTouch = new ListTouch(() -> cast grpLanguages.members, d -> changeSelected(d), i -> tapLanguage(i));
		listTouch.stepPixels = 70;
		listTouch.ignore.push(backButton);
		#end
	}

	var changedLanguage:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if TOUCH_CONTROLS_ALLOWED
		if (listTouch != null) listTouch.update(elapsed);
		#end

		var mult:Int = (FlxG.keys.pressed.SHIFT) ? 4 : 1;
		if(controls.UI_UP_P)
			changeSelected(-1 * mult);
		if(controls.UI_DOWN_P)
			changeSelected(1 * mult);
		if(FlxG.mouse.wheel != 0)
			changeSelected(FlxG.mouse.wheel * mult);

		if(controls.BACK) goBack();

		if(controls.ACCEPT) applyLanguage();
	}

	function goBack()
	{
		#if TOUCH_CONTROLS_ALLOWED
		if (backCam != null)
		{
			FlxG.cameras.remove(backCam);
			backCam = null;
		}
		#end

		if(changedLanguage)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.resetState();
		}
		else close();
		controls.isInSubstate = false;
		FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function applyLanguage()
	{
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
		ClientPrefs.data.language = languages[curSelected];
		ClientPrefs.saveSettings();
		Language.reloadPhrases();
		changedLanguage = true;
	}

	function tapLanguage(index:Int)
	{
		if (index < 0 || index >= languages.length) return;

		if (index == curSelected) applyLanguage();
		else changeSelected(index - curSelected);
	}

	function changeSelected(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, languages.length-1);
		for (num => lang in grpLanguages)
		{
			lang.targetY = num - curSelected;
			lang.alpha = 0.6;
			if(num == curSelected) lang.alpha = 1;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}
	#end
}
