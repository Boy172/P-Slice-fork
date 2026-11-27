package options;

import mikolka.funkin.custom.mobile.MobileScaleMode;
import mikolka.vslice.components.FunkinBackButton;
import mikolka.vslice.components.TouchPadHider;
import mikolka.vslice.components.VSliceBoldText;
import mikolka.vslice.components.crash.UserErrorSubstate;
import backend.StageData;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.util.FlxGradient;
import flixel.util.FlxSpriteUtil;

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
	private var pillsOff:Array<FlxSprite> = [];
	private var pillsOn:Array<FlxSprite> = [];
	private var panelTitle:VSliceBoldText;
	private var panelDescription:FlxText;
	private static var curSelected:Int = 0;
	private static var curSelectedPartial:Float = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	var exiting:Bool = false;
	var customSections:Map<String, String> = new Map<String, String>();

	private var mainCam:FlxCamera;
	public static var funnyCam:FlxCamera;
	private var camFocus:FlxObject;
	private var backButton:FunkinBackButton;
	#if TOUCH_CONTROLS_ALLOWED
	private var tapZone:TouchZone;
	#end

	static inline var PILL_X:Float = 90;
	static inline var PILL_W:Int = 600;
	static inline var PILL_H:Int = 78;
	static inline var PILL_SHIFT:Float = 28;
	static inline var TEXT_INSET:Float = 36;
	static inline var LABEL_SCALE:Float = 0.62;
	static inline var VSLICE_PINK:Int = 0xFFEA71FD;
	static inline var VSLICE_YELLOW:Int = 0xFFFFE066;
	static inline var VSLICE_PURPLE:Int = 0xCC2A0B4F;
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

	function describe(option:String):String
	{
		return switch (option)
		{
			case 'Note Colors': 'Change the colors of your notes and strums.';
			case 'Controls': 'Rebind your keyboard and gamepad controls.';
			case 'Adjust Delay and Combo': 'Calibrate the audio offset and move the combo popups.';
			case 'Graphics': 'Anti-aliasing, shaders, resolution and framerate.';
			case 'Visuals': 'Interface, notes, splashes and visual effects.';
			case 'Gameplay': 'Scroll direction, ghost tapping and gameplay rules.';
			case 'P-Slice Options': 'Extra options added by P-Slice.';
			case 'V-Slice Options': 'Options ported from V-Slice.';
			case 'Editors': 'Open the chart, character and stage editors.';
			case 'Language': 'Change the language of the game.';
			case 'Mobile Options': 'Touch controls and mobile settings.';
			default: 'Settings added by a mod.';
		}
	}

	function makePill(fill:FlxColor, border:FlxColor):FlxSprite
	{
		var pill:FlxSprite = new FlxSprite();
		pill.makeGraphic(PILL_W, PILL_H, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(pill, 2, 2, PILL_W - 4, PILL_H - 4, 40, 40, fill, {thickness: 3, color: border});
		pill.antialiasing = ClientPrefs.data.antialiasing;
		pill.cameras = [funnyCam];
		return pill;
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
			default:
				if (customSections.exists(label))
					openSubState(new options.CustomSettingsSubState(customSections.get(label), label));
				else
					funnyCam.visible = persistentUpdate = true;
		}
	}

	override function create()
	{
		TouchPadHider.initialize();
		CustomSettings.load();
		var insertAt:Int = options.indexOf('Editors');
		if (insertAt < 0) insertAt = options.length;
		for (section in CustomSettings.visibleSections())
		{
			customSections.set(section.title, section.id);
			options.insert(insertAt, section.title);
			insertAt++;
		}
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

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = VSLICE_PINK;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		var panel:FlxSprite = new FlxSprite(740, 150);
		panel.makeGraphic(470, 320, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(panel, 2, 2, 466, 316, 34, 34, VSLICE_PURPLE, {thickness: 4, color: FlxColor.WHITE});
		panel.antialiasing = ClientPrefs.data.antialiasing;
		panel.scrollFactor.set();
		add(panel);

		panelTitle = new VSliceBoldText(772, 180, '', 0.7);
		panelTitle.scrollFactor.set();
		add(panelTitle);

		panelDescription = new FlxText(772, 262, 410, '', 26);
		panelDescription.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, LEFT);
		panelDescription.scrollFactor.set();
		add(panelDescription);

		var hint:FlxText = new FlxText(772, 410, 410, #if TOUCH_CONTROLS_ALLOWED 'Tap to open' #else 'Press ENTER to open' #end, 22);
		hint.setFormat(Paths.font('vcr.ttf'), 22, VSLICE_YELLOW, LEFT);
		hint.scrollFactor.set();
		add(hint);

		for (row in 0...options.length)
		{
			var rowY:Float = ROW_START_Y + LIST_SPACING * row - 4;
			var off:FlxSprite = makePill(VSLICE_PURPLE, 0x99FFFFFF);
			off.setPosition(PILL_X, rowY);
			var on:FlxSprite = makePill(VSLICE_YELLOW, FlxColor.WHITE);
			on.setPosition(PILL_X, rowY);
			on.visible = false;
			pillsOff.push(off);
			pillsOn.push(on);
			add(off);
			add(on);
		}

		grpOptions = new FlxTypedGroup<VSliceBoldText>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:VSliceBoldText = new VSliceBoldText(PILL_X + TEXT_INSET, ROW_START_Y + LIST_SPACING * num, itemLabel(option), LABEL_SCALE);
			optionText.fitTo(PILL_W - TEXT_INSET * 2 - PILL_SHIFT);
			optionText.y = ROW_START_Y + LIST_SPACING * num - 4 + (PILL_H - optionText.height) / 2;
			optionText.cameras = [funnyCam];
			grpOptions.add(optionText);
		}

		var headerShade:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, 110, [0xE6000000, 0x00000000]);
		headerShade.scrollFactor.set();
		headerShade.cameras = [funnyCam];
		add(headerShade);

		var header:VSliceBoldText = new VSliceBoldText(PILL_X, 18, 'OPTIONS', 0.95);
		header.scrollFactor.set();
		header.cameras = [funnyCam];
		add(header);

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
		if (tapZone != null) tapZone.y = pillsOff[curSelected].y - funnyCam.scroll.y - 11;
		#end

		var follow:Float = FlxMath.bound(elapsed * 14, 0, 1);
		for (num => item in grpOptions.members)
		{
			var targetX:Float = PILL_X + (num == curSelected ? PILL_SHIFT : 0);
			var pillX:Float = pillsOff[num].x;
			if (Math.abs(pillX - targetX) < 0.05)
				continue;
			pillX = FlxMath.lerp(pillX, targetX, follow);
			pillsOff[num].x = pillX;
			pillsOn[num].x = pillX;
			item.x = pillX + TEXT_INSET;
		}

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
		{
			var selected:Bool = num == curSelected;
			item.alpha = selected ? 1 : 0.9;
			item.setTint(selected ? FlxColor.BLACK : FlxColor.WHITE);
			pillsOn[num].visible = selected;
			pillsOff[num].visible = !selected;
		}

		panelTitle.textScale = 0.7;
		panelTitle.text = itemLabel(options[curSelected]);
		panelTitle.fitTo(410);
		panelDescription.text = describe(options[curSelected]);

		camFocus.y = ROW_START_Y - FOCUS_OFFSET + LIST_SPACING * curSelectedPartial;
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
