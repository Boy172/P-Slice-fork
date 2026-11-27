package options;

import mikolka.funkin.custom.mobile.MobileScaleMode;
import mobile.objects.TouchZone;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;
import objects.MiniToggle;
import objects.AttachedText;
import options.Option;
import backend.InputFormatter;
import mobile.options.MobileOptionsSubState;
import mikolka.vslice.components.FunkinBackButton;
import mikolka.vslice.components.SwipeValueInput;
import flixel.util.FlxGradient;
import flixel.util.FlxSpriteUtil;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var curSelectedPartial:Float = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<MiniToggle>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var selector:FlxSprite;
	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	public var bg:FlxSprite;

	static inline var ACCENT:FlxColor = 0xFFEA71FD;
	static inline var BG_TOP:FlxColor = 0xFF0B0B12;
	static inline var BG_BOTTOM:FlxColor = 0xFF1B1B29;
	static inline var PANEL_FILL:FlxColor = 0xFF14141D;
	static inline var PANEL_BORDER:FlxColor = 0xFF2C2C3E;
	static inline var SELECTOR_FILL:FlxColor = 0xFF26263A;
	static inline var TEXT_DIM:FlxColor = 0xFF9A9AB0;
	static inline var VALUE_DIM:FlxColor = 0xFF7A7A92;
	static inline var DESC_COLOR:FlxColor = 0xFFD6D6E6;
	static inline var TEXT_SCALE:Float = 0.55;
	static inline var TEXT_CENTER:Float = 42;
	static inline var ROW_PITCH:Float = 62;
	static inline var ROW_HEIGHT:Int = 56;
	static inline var PANEL_TOP:Float = 108;
	static inline var PANEL_HEIGHT:Int = 470;
	static inline var SELECT_CENTER_Y:Float = 343;

	var panelX:Float = 0;
	var panelWidth:Float = 0;
	var valueRight:Float = 0;

	var swipe:SwipeValueInput;
	var backButton:FunkinBackButton;
	var closing:Bool = false;

	public function new()
	{
		controls.isInSubstate = true;

		super();

		swipe = new SwipeValueInput();

		if (title == null)
			title = 'Options';
		if (rpcTitle == null)
			rpcTitle = 'Options Menu';

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		for (customOption in CustomSettings.optionsFor(Type.getClassName(Type.getClass(this))))
			addOption(customOption);

		bg = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [BG_TOP, BG_BOTTOM]);
		bg.scrollFactor.set();
		add(bg);

		panelX = Math.max(MobileScaleMode.gameCutoutSize.x / 2, 0) + 80;
		panelWidth = FlxG.width - panelX * 2;
		valueRight = panelX + panelWidth - 44;

		var panel:FlxSprite = makePanel(Std.int(panelWidth), PANEL_HEIGHT);
		panel.setPosition(panelX, PANEL_TOP);
		add(panel);

		selector = new FlxSprite(panelX + 12, SELECT_CENTER_Y - ROW_HEIGHT / 2);
		selector.makeGraphic(Std.int(panelWidth - 24), ROW_HEIGHT, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(selector, 0, 0, selector.width, ROW_HEIGHT, 26, 26, SELECTOR_FILL);
		FlxSpriteUtil.drawRoundRect(selector, 14, 14, 5, ROW_HEIGHT - 28, 5, 5, ACCENT);
		selector.antialiasing = ClientPrefs.data.antialiasing;
		selector.scrollFactor.set();
		add(selector);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<MiniToggle>();
		add(checkboxGroup);

		var titleText:FlxText = new FlxText(panelX, 36, panelWidth, title.toUpperCase(), 40);
		titleText.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, LEFT);
		titleText.scrollFactor.set();
		add(titleText);

		if (title != '')
		{
			var titleBar:FlxSprite = new FlxSprite(panelX, 90).makeGraphic(56, 4, ACCENT);
			titleBar.scrollFactor.set();
			add(titleBar);
		}

		descBox = makePanel(Std.int(panelWidth), 96);
		descBox.setPosition(panelX, 600);
		add(descBox);

		descText = new FlxText(panelX + 30, 600, panelWidth - 60, "", 22);
		descText.setFormat(Paths.font("vcr.ttf"), 22, DESC_COLOR, CENTER);
		descText.scrollFactor.set();
		add(descText);

		var rowX:Float = panelX + 56;
		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(rowX, SELECT_CENTER_Y - TEXT_CENTER * TEXT_SCALE, optionsArray[i].name, false);
			optionText.setScale(TEXT_SCALE);
			optionText.isMenuItem = true;
			optionText.distancePerItem.set(0, ROW_PITCH / 1.3);
			optionText.targetY = i;
			grpOptions.add(optionText);

			if (optionsArray[i].type == BOOL)
			{
				var toggle:MiniToggle = new MiniToggle(0, 0, Std.string(optionsArray[i].getValue()) == 'true');
				toggle.sprTracker = optionText;
				toggle.offsetX = valueRight - MiniToggle.TRACK_WIDTH - rowX;
				toggle.offsetY = TEXT_CENTER * TEXT_SCALE - MiniToggle.TRACK_HEIGHT / 2;
				toggle.ID = i;
				checkboxGroup.add(toggle);
			}
			else
			{
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), valueRight - rowX, 0, false, TEXT_SCALE);
				valueText.alignment = RIGHT;
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			updateTextFrom(optionsArray[i]);
		}

		changeSelection(0, true);
		reloadCheckboxes();

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('LEFT_FULL', 'A_B_C');

		var button = new TouchZone(panelX + 12, SELECT_CENTER_Y - ROW_HEIGHT / 2, panelWidth - 24, ROW_HEIGHT, FlxColor.PURPLE);

		var scroll = new ScrollableObject(-0.014, 100, 0, FlxG.width - 200, FlxG.height, button);
		scroll.onPartialScroll.add(delta ->
		{
			if (!swipe.horizontal)
				changeSelection(delta, false);
		});
		// scroll.onFullScroll.add(delta ->
		// {
		// });
		scroll.onFullScrollSnap.add(() -> changeSelection(0, true));
		scroll.onTap.add(() ->
		{
			if (!swipe.horizontal)
				onAcceptPress();
		});
		add(scroll);
		add(button);

		setBackTouchButton(false);
		backButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, () -> closeMenu(false), 1.0);
		add(backButton);
		#end
	}

	function makePanel(width:Int, height:Int):FlxSprite
	{
		var panel:FlxSprite = new FlxSprite();
		panel.makeGraphic(width, height, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(panel, 1, 1, width - 2, height - 2, 36, 36, PANEL_FILL, {thickness: 2, color: PANEL_BORDER});
		panel.antialiasing = ClientPrefs.data.antialiasing;
		panel.scrollFactor.set();
		return panel;
	}

	function tintAlphabet(text:Alphabet, color:FlxColor)
	{
		if (text == null)
			return;
		for (member in text.members)
			if (member != null)
				member.color = color;
	}

	function refreshRowStyle()
	{
		if (selector == null)
			return;
		for (num => item in grpOptions.members)
			tintAlphabet(item, num == curSelected ? FlxColor.WHITE : TEXT_DIM);
		for (text in grpTexts)
			tintAlphabet(text, text.ID == curSelected ? ACCENT : VALUE_DIM);
	}

	function updateRowFade()
	{
		var anchorY:Float = SELECT_CENTER_Y - TEXT_CENTER * TEXT_SCALE;
		var panelBottom:Float = PANEL_TOP + PANEL_HEIGHT;
		for (item in grpOptions.members)
		{
			var distance:Float = Math.abs(item.y - anchorY) / ROW_PITCH;
			var alpha:Float = distance < 1 ? 1 - distance * 0.28 : 0.72 - (distance - 1) * 0.17;
			var center:Float = item.y + TEXT_CENTER * TEXT_SCALE;
			var edge:Float = Math.min(center - PANEL_TOP, panelBottom - center) / (ROW_PITCH * 0.6);
			alpha = FlxMath.bound(alpha, 0, 1) * FlxMath.bound(edge, 0, 1);
			if (Math.abs(item.alpha - alpha) > 0.01)
				item.alpha = alpha;
			item.visible = alpha > 0.02;
		}
	}

	function setBackTouchButton(show:Bool)
	{
		#if TOUCH_CONTROLS_ALLOWED
		if (touchPad != null && touchPad.buttonB != null)
			touchPad.buttonB.visible = touchPad.buttonB.active = show;
		#end
	}

	function closeMenu(playSound:Bool)
	{
		if (closing)
			return;
		closing = true;
		close();
		if (playSound)
			FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function configureSwipe()
	{
		if (swipe == null || curOption == null)
			return;

		switch (curOption.type)
		{
			case INT, FLOAT, PERCENT:
				var span:Float = (curOption.maxValue : Float) - (curOption.minValue : Float);
				var change:Float = curOption.changeValue;
				swipe.configure(change > 0 ? span / change : 0, false);
			case STRING:
				swipe.configure(0, true);
			default:
		}
	}

	public function addOption(option:Option)
	{
		if (optionsArray == null || optionsArray.length < 1)
			optionsArray = [];
		optionsArray.push(option);
		return option;
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var bindingKey:Bool = false;
	var holdingEsc:Float = 0;
	var bindingBlack:FlxSprite;
	var bindingText:Alphabet;
	var bindingText2:Alphabet;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		updateRowFade();

		swipe.enabled = !bindingKey && !closing;
		swipe.update(elapsed);

		if (bindingKey)
		{
			bindingKeyUpdate(elapsed);
			return;
		}

		if (controls.UI_UP_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(-1,true);
		}
		if (controls.UI_DOWN_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'));
			changeSelection(1,true);
		}

		if (controls.BACK)
			closeMenu(true);

		if (nextAccept <= 0)
		{
			switch (curOption.type)
			{
				case BOOL | KEYBIND:
					if (controls.ACCEPT)
						onAcceptPress();
				default:
					var uiLeft:Bool = controls.UI_LEFT || swipe.left;
					var uiRight:Bool = controls.UI_RIGHT || swipe.right;
					var uiLeftP:Bool = controls.UI_LEFT_P || swipe.leftP;
					var uiRightP:Bool = controls.UI_RIGHT_P || swipe.rightP;
					if (uiLeft || uiRight)
					{
						var pressed = (uiLeftP || uiRightP);
						if (holdTime > 0.5 || pressed)
						{
							if (pressed)
							{
								var add:Dynamic = null;
								if (curOption.type != STRING)
									add = uiLeft ? -curOption.changeValue : curOption.changeValue;

								switch (curOption.type)
								{
									case INT, FLOAT, PERCENT:
										holdValue = curOption.getValue() + add;
										if (holdValue < curOption.minValue)
											holdValue = curOption.minValue;
										else if (holdValue > curOption.maxValue)
											holdValue = curOption.maxValue;

										if (curOption.type == INT)
										{
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);
										}
										else
										{
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
										}

									case STRING:
										var num:Int = curOption.curOption; // lol
										if (uiLeftP)
											--num;
										else
											num++;

										if (num < 0)
											num = curOption.options.length - 1;
										else if (num >= curOption.options.length)
											num = 0;

										curOption.curOption = num;
										curOption.setValue(curOption.options[num]);
									// trace(curOption.options[num]);

									default:
								}
								updateTextFrom(curOption);
								curOption.change();
								FlxG.sound.play(Paths.sound('scrollMenu'));
							}
							else if (curOption.type != STRING)
							{
								holdValue += curOption.scrollSpeed * elapsed * (uiLeft ? -1 : 1);
								if (holdValue < curOption.minValue)
									holdValue = curOption.minValue;
								else if (holdValue > curOption.maxValue)
									holdValue = curOption.maxValue;

								switch (curOption.type)
								{
									case INT:
										curOption.setValue(Math.round(holdValue));

									case PERCENT:
										curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));

									default:
								}
								updateTextFrom(curOption);
								curOption.change();
							}
						}

						if (curOption.type != STRING)
							holdTime += elapsed;
					}
					else if (controls.UI_LEFT_R || controls.UI_RIGHT_R || swipe.leftR || swipe.rightR)
					{
						if (holdTime > 0.5)
							FlxG.sound.play(Paths.sound('scrollMenu'));
						holdTime = 0;
					}
			}

			if (controls.RESET #if TOUCH_CONTROLS_ALLOWED || touchPad.buttonC.justPressed #end)
			{
				var leOption:Option = optionsArray[curSelected];
				if (leOption.type != KEYBIND)
				{
					leOption.setValue(leOption.defaultValue);
					if (leOption.type != BOOL)
					{
						if (leOption.type == STRING)
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						updateTextFrom(leOption);
					}
				}
				else
				{
					leOption.setValue(!Controls.instance.controllerMode ? leOption.defaultKeys.keyboard : leOption.defaultKeys.gamepad);
					updateBind(leOption);
				}
				leOption.change();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if (nextAccept > 0)
		{
			nextAccept -= 1;
		}
	}

	function onAcceptPress()
	{
		switch (curOption.type)
		{
			case BOOL:
				FlxG.sound.play(Paths.sound('scrollMenu'));
				curOption.setValue((curOption.getValue() == true) ? false : true);
				curOption.change();
				reloadCheckboxes();

			case KEYBIND:
				bindingBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
				bindingBlack.scale.set(FlxG.width, FlxG.height);
				bindingBlack.updateHitbox();
				bindingBlack.alpha = 0;
				FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
				add(bindingBlack);

				bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [curOption.name]), false);
				bindingText.alignment = CENTERED;
				add(bindingText);

				final escape:String = (controls.mobileC) ? "B" : "ESC";
				final backspace:String = (controls.mobileC) ? "C" : "Backspace";

				bindingText2 = new Alphabet(FlxG.width / 2, 340,
					Language.getPhrase('controls_rebinding2', 'Hold {1} to Cancel\nHold {2} to Delete', [escape, backspace]), true);
				bindingText2.alignment = CENTERED;
				add(bindingText2);

				bindingKey = true;
				setBackTouchButton(true);
				holdingEsc = 0;
				ClientPrefs.toggleVolumeKeys(false);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			default:
				return;
		}
	}

	function bindingKeyUpdate(elapsed:Float)
	{
		if (#if TOUCH_CONTROLS_ALLOWED touchPad.buttonB.pressed || #end FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
		{
			holdingEsc += elapsed;
			if (holdingEsc > 0.5)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else if (#if TOUCH_CONTROLS_ALLOWED touchPad.buttonC.pressed || #end FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
		{
			holdingEsc += elapsed;
			if (holdingEsc > 0.5)
			{
				if (!controls.controllerMode)
					curOption.keys.keyboard = NONE;
				else
					curOption.keys.gamepad = NONE;
				updateBind(!controls.controllerMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else
		{
			holdingEsc = 0;
			var changed:Bool = false;
			if (!controls.controllerMode)
			{
				if (FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
				{
					var keyPressed:FlxKey = cast(FlxG.keys.firstJustPressed(), FlxKey);
					var keyReleased:FlxKey = cast(FlxG.keys.firstJustReleased(), FlxKey);

					if (keyPressed != NONE && keyPressed != ESCAPE && keyPressed != BACKSPACE)
					{
						changed = true;
						curOption.keys.keyboard = keyPressed;
					}
					else if (keyReleased != NONE && (keyReleased == ESCAPE || keyReleased == BACKSPACE))
					{
						changed = true;
						curOption.keys.keyboard = keyReleased;
					}
				}
			}
			else if (FlxG.gamepads.anyJustPressed(ANY)
				|| FlxG.gamepads.anyJustPressed(LEFT_TRIGGER)
				|| FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)
				|| FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:FlxGamepadInputID = NONE;
				var keyReleased:FlxGamepadInputID = NONE;
				if (FlxG.gamepads.anyJustPressed(LEFT_TRIGGER))
					keyPressed = LEFT_TRIGGER; // it wasnt working for some reason
				else if (FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					keyPressed = RIGHT_TRIGGER; // it wasnt working for some reason
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
						if (gamepad != null)
						{
							keyPressed = gamepad.firstJustPressedID();
							keyReleased = gamepad.firstJustReleasedID();
							if (keyPressed != NONE || keyReleased != NONE)
								break;
						}
					}
				}

				if (keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
				{
					changed = true;
					curOption.keys.gamepad = keyPressed;
				}
				else if (keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
				{
					changed = true;
					curOption.keys.gamepad = keyReleased;
				}
			}

			if (changed)
			{
				var key:String = null;
				if (!controls.controllerMode)
				{
					if (curOption.keys.keyboard == null)
						curOption.keys.keyboard = 'NONE';
					curOption.setValue(curOption.keys.keyboard);
					key = InputFormatter.getKeyName(FlxKey.fromString(curOption.keys.keyboard));
				}
				else
				{
					if (curOption.keys.gamepad == null)
						curOption.keys.gamepad = 'NONE';
					curOption.setValue(curOption.keys.gamepad);
					key = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(curOption.keys.gamepad));
				}
				updateBind(key);
				FlxG.sound.play(Paths.sound('confirmMenu'));
				closeBinding();
			}
		}
	}

	final MAX_KEYBIND_WIDTH = 320;

	function updateBind(?text:String = null, ?option:Option = null)
	{
		if (option == null)
			option = curOption;
		if (text == null)
		{
			text = option.getValue();
			if (text == null)
				text = 'NONE';

			if (!controls.controllerMode)
				text = InputFormatter.getKeyName(FlxKey.fromString(text));
			else
				text = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(text));
		}

		var bind:AttachedText = cast option.child;
		var attach:AttachedText = new AttachedText(text, bind.offsetX, bind.offsetY, false, TEXT_SCALE);
		attach.sprTracker = bind.sprTracker;
		attach.copyAlpha = true;
		attach.ID = bind.ID;
		playstationCheck(attach);
		attach.scaleX = Math.min(TEXT_SCALE, MAX_KEYBIND_WIDTH / attach.width);
		attach.alignment = RIGHT;
		attach.x = bind.x;
		attach.y = bind.y;

		option.child = attach;
		grpTexts.insert(grpTexts.members.indexOf(bind), attach);
		grpTexts.remove(bind);
		bind.destroy();
		refreshRowStyle();
	}

	function playstationCheck(alpha:Alphabet)
	{
		if (!controls.controllerMode)
			return;

		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;
		var letter = alpha.letters[0];
		if (model == PS4)
		{
			switch (alpha.text)
			{
				case '[', ']': // Square and Triangle respectively
					letter.image = 'alphabet_playstation';
					letter.updateHitbox();

					letter.offset.x += 4;
					letter.offset.y -= 5;
			}
		}
	}

	function closeBinding()
	{
		bindingKey = false;
		setBackTouchButton(false);
		bindingBlack.destroy();
		remove(bindingBlack);

		bindingText.destroy();
		remove(bindingText);

		bindingText2.destroy();
		remove(bindingText2);
		ClientPrefs.toggleVolumeKeys(true);
	}

	function updateTextFrom(option:Option)
	{
		if (option.type == KEYBIND)
		{
			updateBind(option);
			return;
		}

		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if (option.type == PERCENT)
			val *= 100;
		var def:Dynamic = option.defaultValue;
		if (option.defaultLabel != null && val == def)
			text = option.defaultLabel;
		option.text = text.replace('%v', val).replace('%d', def);
		if (grpTexts != null && selector != null)
			refreshRowStyle();
	}

	function changeSelection(delta:Float, usePrecision:Bool = false)
	{
		if (usePrecision)
		{
			curSelected = FlxMath.wrap(curSelected + Std.int(delta), 0, optionsArray.length - 1);
			curSelectedPartial = curSelected;
		}
		else
		{
			curSelectedPartial = FlxMath.bound(curSelectedPartial + delta, 0, optionsArray.length - 1);
			if(curSelected != Math.round(curSelectedPartial)) FlxG.sound.play(Paths.sound('scrollMenu'));
			curSelected = Math.round(curSelectedPartial);
		}
		descText.text = optionsArray[curSelected].description;

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelectedPartial;
		}

		descText.y = descBox.y + (descBox.height - descText.height) / 2;
		refreshRowStyle();

		curOption = optionsArray[curSelected]; // shorter lol
		configureSwipe();
	}

	function reloadCheckboxes()
		for (checkbox in checkboxGroup)
			checkbox.daValue = Std.string(optionsArray[checkbox.ID].getValue()) == 'true'; // Do not take off the Std.string() from this, it will break a thing in Mod Settings Menu
}
