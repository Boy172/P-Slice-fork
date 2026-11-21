package options;

import mikolka.funkin.custom.mobile.MobileScaleMode;
import mikolka.vslice.components.FunkinBackButton;
import mikolka.vslice.components.TouchPadHider;
import mikolka.vslice.components.VSliceBoldText;
import mikolka.vslice.components.crash.UserErrorSubstate;
import backend.StageData;
import flixel.FlxObject;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay',
		'P-Slice Options',
		'V-Slice Options',
		'Editors',
		#if TRANSLATIONS_ALLOWED  'Language', #end
		#if (TOUCH_CONTROLS_ALLOWED || mobile)'Mobile Options' #end
	];
	private var grpOptions:FlxTypedGroup<VSliceBoldText>;
	private static var curSelected:Int = 0;
	private static var curSelectedPartial:Float = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	var exiting:Bool = false;

	private var mainCam:FlxCamera;
	public static var funnyCam:FlxCamera;
	private var camFocus:FlxObject;
	private var backButton:FunkinBackButton;
	#if TOUCH_CONTROLS_ALLOWED
	private var tapZone:TouchZone;
	#end

	static inline var LIST_SPACING:Float = 100;
	static inline var ROW_START_Y:Float = 107;
	static inline var FOCUS_OFFSET:Float = 7;
	static inline var DEADZONE_TOP:Float = 75;
	static inline var DEADZONE_HEIGHT:Float = 610;
	static inline var FOLLOW_LERP:Float = 0.085;
	static inline var MIN_SCROLL_Y:Float = -75;

	function itemLabel(option:String):String
	{
		return Language.getPhrase('options_$option', option);
	}

	function centerItem(item:VSliceBoldText)
	{
		item.screenCenter(X);
	}

	function openSelectedSubstate(label:String) {
		if (label == 'Editors')
		{
			if (onPlayState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				return;
			}
			ClientPrefs.saveSettings();
			MusicBeatState.switchState(new states.editors.MasterEditorMenu());
			return;
		}

		if (label != "Adjust Delay and Combo")
			funnyCam.visible = persistentUpdate = false;

		switch(label)
		{
			case 'Note Colors':
				openSubState(new options.NotesColorSubState());
			case 'Controls':
				if (controls.mobileC)
				{
					funnyCam.visible = persistentUpdate = true;
					UserErrorSubstate.makeMessage("Unsupported controls",
					"You don't need to go there on mobile!\n\nIf you wish to go there anyway\nSet 'Mobile Controls Opacity' to 0%");
				}
				else
					openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new options.VisualsSettingsSubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'P-Slice Options':
				openSubState(new PSliceSubState());
			case 'V-Slice Options':
				openSubState(new VSliceSubState());
			#if (TOUCH_CONTROLS_ALLOWED || mobile)
			case 'Mobile Options':
				openSubState(new mobile.options.MobileOptionsSubState());
			#end
			#if TRANSLATIONS_ALLOWED
			case 'Language':
				openSubState(new options.LanguageSubState());
			#end
		}
	}

	override function create()
	{
		TouchPadHider.initialize();
		mainCam = initPsychCamera();
		funnyCam = new FlxCamera();
		funnyCam.bgColor.alpha = 0;
		FlxG.cameras.add(funnyCam, false);

		camFocus = new FlxObject(0, 0, 140, 70);
		add(camFocus);
		funnyCam.follow(camFocus, null, FOLLOW_LERP);
		funnyCam.deadzone.set(0, DEADZONE_TOP, funnyCam.width, DEADZONE_HEIGHT);
		funnyCam.minScrollY = MIN_SCROLL_Y;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFB45A8C;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<VSliceBoldText>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:VSliceBoldText = new VSliceBoldText(0, 0, itemLabel(option));
			centerItem(optionText);
			optionText.y = ROW_START_Y + LIST_SPACING * num;
			optionText.cameras = [funnyCam];
			grpOptions.add(optionText);
		}

		changeSelection(0,true);
		ClientPrefs.saveSettings();

		#if TOUCH_CONTROLS_ALLOWED
		tapZone = new TouchZone(90,Std.int(ROW_START_Y - 15),FlxG.width,100,FlxColor.PURPLE);

		var scroll = new ScrollableObject(-0.01,100,0,FlxG.width-200,FlxG.height,tapZone);
		scroll.onPartialScroll.add(delta -> changeSelection(delta,false));
		scroll.onFullScrollSnap.add(() ->changeSelection(0,true));
		scroll.onTap.add(() ->{
			openSelectedSubstate(options[curSelected]);
		});
		add(scroll);
		add(tapZone);

		backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, () -> goBack(false), 1.0);
		backButton.cameras = [funnyCam];
		add(backButton);
		#end

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		controls.isInSubstate = false;
		persistentUpdate = funnyCam.visible = true;

		if (backButton != null) backButton.resetState();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if(exiting) return;

		if (controls.UI_UP_P){
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(-1,true);
		}
		if (controls.UI_DOWN_P){
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(1,true);
		}

		#if TOUCH_CONTROLS_ALLOWED
		if (tapZone != null) tapZone.y = grpOptions.members[curSelected].y - funnyCam.scroll.y - 15;
		#end

		if (controls.BACK) goBack();
		else if (controls.ACCEPT) openSelectedSubstate(options[curSelected]);
	}

	function goBack(playSound:Bool = true)
	{
		if (exiting) return;
		exiting = true;
		if (playSound) FlxG.sound.play(Paths.sound('cancelMenu'));
		if(onPlayState)
		{
			StageData.loadDirectory(PlayState.SONG);
			LoadingState.loadAndSwitchState(new PlayState());
			FlxG.sound.music.volume = 0;
		}
		else MusicBeatState.switchState(new MainMenuState());
	}

	function changeSelection(delta:Float,usePrecision:Bool = false) {
		if(usePrecision) {
			if(delta != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			curSelected =  FlxMath.wrap(curSelected + Std.int(delta), 0, options.length - 1);
			curSelectedPartial = curSelected;
		}
		else {
			curSelectedPartial = FlxMath.bound(curSelectedPartial + delta, 0, options.length - 1);
			if(curSelected != Math.round(curSelectedPartial)) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			curSelected = Math.round(curSelectedPartial);
		}
		for (num => item in grpOptions.members)
			item.alpha = (num == curSelected) ? 1 : 0.6;

		camFocus.y = ROW_START_Y - FOCUS_OFFSET + LIST_SPACING * curSelectedPartial;
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
