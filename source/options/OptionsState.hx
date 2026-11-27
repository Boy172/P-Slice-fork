package options;

import mikolka.funkin.custom.mobile.MobileScaleMode;
import mikolka.vslice.components.FunkinBackButton;
import mikolka.vslice.components.TouchPadHider;
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
	private var grpOptions:FlxTypedGroup<FlxText>;
	private var selector:FlxSprite;
	private var selectorAccent:FlxSprite;
	private var selectorTargetY:Float = 0;
	private var panelTitle:FlxText;
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

	static inline var ACCENT:FlxColor = 0xFFEA71FD;
	static inline var BG_TOP:FlxColor = 0xFF0B0B12;
	static inline var BG_BOTTOM:FlxColor = 0xFF1B1B29;
	static inline var PANEL_FILL:FlxColor = 0xFF14141D;
	static inline var PANEL_BORDER:FlxColor = 0xFF2C2C3E;
	static inline var SELECTOR_FILL:FlxColor = 0xFF26263A;
	static inline var TEXT_DIM:FlxColor = 0xFF8A8AA0;
	static inline var DESC_COLOR:FlxColor = 0xFFD6D6E6;
	static inline var LIST_X:Float = 90;
	static inline var LIST_W:Int = 600;
	static inline var ROW_H:Int = 54;
	static inline var TEXT_INSET:Float = 40;
	static inline var SELECT_SHIFT:Float = 14;
	static inline var LIST_SPACING:Float = 66;
	static inline var ROW_START_Y:Float = 120;
	static inline var FOCUS_OFFSET:Float = 8;
	static inline var DEADZONE_TOP:Float = 110;
	static inline var DEADZONE_HEIGHT:Float = 560;
	static inline var FOLLOW_LERP:Float = 0.085;
	static inline var MIN_SCROLL_Y:Float = 0;

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

	function makePanel(width:Int, height:Int, radius:Float, fill:FlxColor, ?border:FlxColor):FlxSprite
	{
		var panel:FlxSprite = new FlxSprite();
		panel.makeGraphic(width, height, FlxColor.TRANSPARENT, true);
		if (border != null)
			FlxSpriteUtil.drawRoundRect(panel, 1, 1, width - 2, height - 2, radius, radius, fill, {thickness: 2, color: border});
		else
			FlxSpriteUtil.drawRoundRect(panel, 0, 0, width, height, radius, radius, fill);
		panel.antialiasing = ClientPrefs.data.antialiasing;
		return panel;
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

		var bg:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [BG_TOP, BG_BOTTOM]);
		bg.scrollFactor.set();
		add(bg);

		var panel:FlxSprite = makePanel(470, 320, 36, PANEL_FILL, PANEL_BORDER);
		panel.setPosition(740, 150);
		panel.scrollFactor.set();
		add(panel);

		var panelBar:FlxSprite = new FlxSprite(772, 182).makeGraphic(40, 4, ACCENT);
		panelBar.scrollFactor.set();
		add(panelBar);

		panelTitle = new FlxText(772, 198, 406, '', 36);
		panelTitle.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, LEFT);
		panelTitle.scrollFactor.set();
		add(panelTitle);

		panelDescription = new FlxText(772, 262, 406, '', 24);
		panelDescription.setFormat(Paths.font('vcr.ttf'), 24, DESC_COLOR, LEFT);
		panelDescription.scrollFactor.set();
		add(panelDescription);

		var hint:FlxText = new FlxText(772, 416, 406, #if TOUCH_CONTROLS_ALLOWED 'Tap to open' #else 'Press ENTER to open' #end, 20);
		hint.setFormat(Paths.font('vcr.ttf'), 20, ACCENT, LEFT);
		hint.scrollFactor.set();
		add(hint);

		selector = makePanel(LIST_W, ROW_H, 26, SELECTOR_FILL);
		selector.setPosition(LIST_X, ROW_START_Y);
		selector.cameras = [funnyCam];
		add(selector);

		var selectorBar:FlxSprite = new FlxSprite().makeGraphic(5, ROW_H - 28, ACCENT);
		selectorBar.cameras = [funnyCam];
		add(selectorBar);
		selectorAccent = selectorBar;

		grpOptions = new FlxTypedGroup<FlxText>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:FlxText = new FlxText(LIST_X + TEXT_INSET, 0, 0, itemLabel(option), 32);
			optionText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT);
			optionText.y = ROW_START_Y + LIST_SPACING * num + (ROW_H - optionText.height) / 2;
			optionText.cameras = [funnyCam];
			grpOptions.add(optionText);
		}

		var headerShade:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, 112, [BG_TOP, 0x000B0B12]);
		headerShade.scrollFactor.set();
		headerShade.cameras = [funnyCam];
		add(headerShade);

		var header:FlxText = new FlxText(LIST_X, 34, 600, 'OPTIONS', 40);
		header.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, LEFT);
		header.scrollFactor.set();
		header.cameras = [funnyCam];
		add(header);

		var headerBar:FlxSprite = new FlxSprite(LIST_X, 88).makeGraphic(56, 4, ACCENT);
		headerBar.scrollFactor.set();
		headerBar.cameras = [funnyCam];
		add(headerBar);

		changeSelection(0,true);
		selector.y = selectorTargetY;
		ClientPrefs.saveSettings();

		#if TOUCH_CONTROLS_ALLOWED
		tapZone = new TouchZone(Std.int(LIST_X),Std.int(ROW_START_Y),LIST_W,ROW_H,FlxColor.PURPLE);

		var scroll = new ScrollableObject(-0.014,100,0,FlxG.width-200,FlxG.height,tapZone);
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
		if (tapZone != null) tapZone.y = selector.y - funnyCam.scroll.y;
		#end

		var follow:Float = FlxMath.bound(elapsed * 14, 0, 1);
		selector.y = FlxMath.lerp(selectorTargetY, selector.y, Math.exp(-elapsed * 18));
		selectorAccent.setPosition(selector.x + 14, selector.y + 14);
		for (num => item in grpOptions.members)
		{
			var targetX:Float = LIST_X + TEXT_INSET + (num == curSelected ? SELECT_SHIFT : 0);
			if (Math.abs(item.x - targetX) < 0.05)
				continue;
			item.x = FlxMath.lerp(item.x, targetX, follow);
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
			item.color = num == curSelected ? FlxColor.WHITE : TEXT_DIM;

		selectorTargetY = ROW_START_Y + LIST_SPACING * curSelected;
		panelTitle.text = itemLabel(options[curSelected]).toUpperCase();
		panelDescription.text = describe(options[curSelected]);
		panelDescription.y = panelTitle.y + panelTitle.height + 14;

		camFocus.y = ROW_START_Y - FOCUS_OFFSET + LIST_SPACING * curSelectedPartial;
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
