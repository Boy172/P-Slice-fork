package mikolka.vslice.ui.mods;

import backend.Mods;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import mikolka.vslice.ui.mods.ModMenuList;
import mikolka.vslice.ui.title.TitleState;

class ModSelectState extends MusicBeatState
{
	static inline var P_NONE:Int = 0;
	static inline var P_BTN:Int = 1;
	static inline var P_ITEM:Int = 2;
	static inline var P_SCROLL:Int = 3;
	static inline var P_DRAG:Int = 4;

	static inline var BTN_BACK:Int = 0;
	static inline var BTN_FOLDER:Int = 1;
	static inline var BTN_DONE:Int = 2;

	static inline var SEL_DIS:Int = 0;
	static inline var SEL_ENA:Int = 1;
	static inline var SEL_FOLDER:Int = 2;
	static inline var SEL_DONE:Int = 3;
	static inline var SEL_BACK:Int = 4;

	var assetsOk:Bool = true;

	var camL:FlxCamera;
	var camR:FlxCamera;
	var camChars:FlxCamera;
	var camHUD:FlxCamera;
	var camTop:FlxCamera;

	var menuBG:FlxSprite;
	var leftBox:FlxSprite;
	var rightBox:FlxSprite;
	var topText:FlxSprite;
	var dragText:FlxText;
	var dragTextDefault:String;
	var messageTimer:Float = 0;

	var disabledList:ModMenuList;
	var enabledList:ModMenuList;
	var flyers:Array<ModMenuItem> = [];

	var backBtn:FlxAtlasSprite;
	var backRect:Array<Float> = [0, 0, 0, 0];
	var folderBtn:ModMenuButton;
	var doneBtn:ModMenuButton;

	var blackFlash:FlxSprite;
	var bgWires:FlxSprite;
	var carBattery:FlxSprite;
	var gfWire:FlxSprite;
	var bf:ModMenuCharacter;
	var gf:ModMenuCharacter;
	var fgTop:FlxAtlasSprite;
	var fgBottom:FlxAtlasSprite;
	var smokeBF:FlxSprite;
	var smokeGF:FlxSprite;
	var smokeCloud:FlxAtlasSprite;
	var sparks:ModMenuSparks;

	var ambience:ModMenuAmbience;
	var savedMusicVolume:Float = 1;

	var bfCountdown:Float = 0;
	var gfCountdown:Float = 0;

	var allowInput:Bool = true;
	var exiting:Bool = false;
	var backWait:Float = -1;
	var shockTimer:FlxTimer = new FlxTimer();
	var afterFlash:Bool = false;
	var crispyShown:Bool = false;
	var crispyTimer:Float = 0;
	var crispySfx:Bool = false;
	var gfHeld:Bool = false;
	var prevPinhead:Bool = false;
	var finishing:Bool = false;

	var ptrX:Float = 0;
	var ptrY:Float = 0;
	var ptrJust:Bool = false;
	var ptrUp:Bool = false;
	var ptrDown:Bool = false;

	var mode:Int = P_NONE;
	var pressX:Float = 0;
	var pressY:Float = 0;
	var pressTime:Float = 0;
	var pressBtn:Int = -1;
	var pressList:ModMenuList;
	var pressItem:ModMenuItem;
	var scrollStart:Float = 0;
	var dragItem:ModMenuItem;
	var dragDX:Float = 0;
	var dragDY:Float = 0;

	var usingKeys:Bool = false;
	var sel:Int = SEL_DIS;
	var backFromEnabled:Bool = false;

	function makeCam():FlxCamera
	{
		var cam:FlxCamera = new FlxCamera();
		cam.bgColor.alpha = 0;
		FlxG.cameras.add(cam, false);
		return cam;
	}

	function img(px:Float, py:Float, key:String, sx:Float = 1, sy:Float = 1):FlxSprite
	{
		var s:FlxSprite = new FlxSprite(px, py);
		var graph = Paths.image('vmods/$key');
		if (graph != null) s.loadGraphic(graph);
		else s.makeGraphic(8, 8, FlxColor.TRANSPARENT);
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.scale.set(sx, sy);
		s.updateHitbox();
		return s;
	}

	function sparrow(px:Float, py:Float, key:String):FlxSprite
	{
		var s:FlxSprite = new FlxSprite(px, py);
		s.frames = Paths.getSparrowAtlas('vmods/$key');
		s.antialiasing = ClientPrefs.data.antialiasing;
		return s;
	}

	function atlas(px:Float, py:Float, key:String, sc:Float, cam:FlxCamera):FlxAtlasSprite
	{
		var s:FlxAtlasSprite = new FlxAtlasSprite(px, py, 'vmods/$key');
		s.scale.set(sc, sc);
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.cameras = [cam];
		return s;
	}

	function label(px:Float, py:Float, w:Float, text:String, size:Int, align:FlxTextAlign = FlxTextAlign.CENTER):FlxText
	{
		var t:FlxText = new FlxText(px, py, w, text, size);
		t.setFormat(ModMenuStyle.fontPath, size, FlxColor.WHITE, align);
		return t;
	}

	override function create()
	{
		super.create();

		persistentUpdate = false;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		CacheSystem.clearStoredMemory();
		CacheSystem.clearUnusedMemory();

		#if !mobile
		FlxG.mouse.visible = true;
		#end

		assetsOk = Paths.image('vmods/box') != null && Paths.image('vmods/bg') != null;
		if (!assetsOk)
		{
			var warn:FlxText = label(0, 0, FlxG.width, 'THIS DEVICE CANNOT LOAD THE MOD MENU TEXTURES (ASTC)\nTAP TO GO BACK', 28);
			warn.screenCenter(Y);
			add(warn);
			return;
		}

		if (FlxG.sound.music != null)
		{
			savedMusicVolume = FlxG.sound.music.volume;
			FlxG.sound.music.fadeOut(0.8, 0);
		}

		menuBG = img(0, 0, 'bg', 0.66, 0.67);
		menuBG.screenCenter();
		add(menuBG);

		leftBox = img(FlxG.width * 0.047, FlxG.height * 0.19, 'box', 0.64, 0.67);
		add(leftBox);
		rightBox = img(leftBox.x + leftBox.width + 35, leftBox.y, 'box', 0.64, 0.67);
		add(rightBox);

		topText = img(0, FlxG.height * 0.035, 'top-text', 0.66, 0.67);
		topText.screenCenter(X);
		add(topText);

		var big:Bool = ModMenuStyle.customFont;
		#if mobile
		dragTextDefault = 'TAP A MOD TO MOVE IT, OR HOLD AND DRAG IT';
		#else
		dragTextDefault = 'CLICK A MOD TO MOVE IT, OR DRAG IT BETWEEN THE LISTS';
		#end
		dragText = label(leftBox.x, FlxG.height * 0.13, leftBox.width * 2 + 35, dragTextDefault, big ? 32 : 20);
		add(dragText);

		var lrect:FlxRect = FlxRect.get(leftBox.x, leftBox.y, leftBox.width, leftBox.height);
		var rrect:FlxRect = FlxRect.get(rightBox.x, rightBox.y, rightBox.width, rightBox.height);

		camL = new FlxCamera(Std.int(lrect.x), Std.int(lrect.y + 60), Std.int(lrect.width), Std.int(lrect.height - 75));
		camL.bgColor.alpha = 0;
		FlxG.cameras.add(camL, false);
		camR = new FlxCamera(Std.int(rrect.x), Std.int(rrect.y + 60), Std.int(rrect.width), Std.int(rrect.height - 75));
		camR.bgColor.alpha = 0;
		FlxG.cameras.add(camR, false);

		camChars = makeCam();
		camHUD = makeCam();
		camTop = makeCam();

		disabledList = new ModMenuList(lrect, camL);
		enabledList = new ModMenuList(rrect, camR);

		var titleSize:Int = big ? 32 : 24;
		add(label(lrect.x, lrect.y + 14, lrect.width, 'DISABLED', titleSize));
		add(label(rrect.x, rrect.y + 14, rrect.width, 'ENABLED', titleSize));
		add(disabledList.track);
		add(disabledList.thumb);
		add(enabledList.track);
		add(enabledList.thumb);

		buildLists();
		buildBackButton();
		buildCharacters();
		buildButtons();

		ambience = new ModMenuAmbience();
		ambience.start();

		bfCountdown = FlxG.random.float(0, 1) + FlxG.random.float(0, 6);
		gfCountdown = FlxG.random.float(0, 1) + 6 + FlxG.random.float(0, 4);

		changeCharacters();
		applySelection();
		if (!usingKeys) deselectAll();
	}

	function buildLists():Void
	{
		var modList:ModsList = Mods.parseList();
		Mods.loadTopMod();

		var disabledEntries:Array<ModEntry> = [];
		var enabledEntries:Array<ModEntry> = [];

		for (mod in modList.all)
		{
			if (mod.trim().length < 1) continue;
			var isOn:Bool = !modList.disabled.contains(mod);
			var entry:ModEntry = new ModEntry(mod, isOn);
			if (isOn) enabledEntries.push(entry);
			else disabledEntries.push(entry);
		}

		enabledEntries.push(ModEntry.base());

		for (entry in disabledEntries) addItem(entry, disabledList);
		for (entry in enabledEntries) addItem(entry, enabledList);
	}

	function addItem(entry:ModEntry, list:ModMenuList):ModMenuItem
	{
		var item:ModMenuItem = new ModMenuItem(entry);
		item.cameras = [list.cam];
		add(item);
		list.insert(item, list.items.length);
		item.snapTo(ModMenuList.ITEM_X, (list.items.length - 1) * ModMenuList.STEP);
		return item;
	}

	function buildBackButton():Void
	{
		backBtn = atlas(leftBox.x - 50, topText.y + topText.height / 2 - 38, 'back-arrow', 0.7, FlxG.camera);
		backBtn.playAnimation('default', true, false, true);
		add(backBtn);
		backRect = [leftBox.x - 70, topText.y - 10, 170, topText.height + 20];
	}

	function buildCharacters():Void
	{
		blackFlash = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF232327);
		blackFlash.cameras = [camChars];
		blackFlash.visible = false;
		add(blackFlash);

		var batteryX:Float = rightBox.x + 475.6;
		var batteryY:Float = FlxG.height * 0.11;

		var bfX:Float = batteryX - 119;
		var bfY:Float = batteryY + 50;
		var gfX:Float = bfX - 166;

		bgWires = img(batteryX + 75, batteryY + 170, 'bgwires', 0.7, 0.7);
		bgWires.cameras = [camChars];
		add(bgWires);

		carBattery = sparrow(batteryX, batteryY, 'carbattery');
		carBattery.animation.addByPrefix('idle', 'idle', 24);
		carBattery.animation.play('idle');
		carBattery.animation.pause();
		carBattery.scale.set(0.75, 0.75);
		carBattery.updateHitbox();
		carBattery.cameras = [camChars];
		add(carBattery);

		gfWire = sparrow(batteryX - 117, batteryY - 18, 'gfwire');
		gfWire.animation.addByPrefix('idle', 'idle0', 24, false);
		gfWire.animation.addByPrefix('idle-emptychair', 'idle empty chair0', 24, false);
		gfWire.animation.addByPrefix('shock', 'shock', 24, false);
		gfWire.animation.play('idle');
		gfWire.scale.set(0.7, 0.7);
		gfWire.updateHitbox();
		gfWire.cameras = [camChars];
		add(gfWire);

		gf = new ModMenuCharacter(gfX, bfY, 'gf', true, camChars);
		add(gf.group);

		bf = new ModMenuCharacter(bfX, bfY, 'bf', false, camChars);
		add(bf.group);

		fgBottom = atlas(bfX - 144, bfY - 90, 'foreground-wires-bottom', 0.7, camChars);
		add(fgBottom);
		fgTop = atlas(bfX - 144, bfY - 90, 'foreground-wires-top', 0.7, camChars);
		add(fgTop);

		smokeGF = sparrow(gfX + 70, bfY - 180, 'smoke');
		smokeGF.animation.addByPrefix('idle', 'retry_smoke', 24);
		smokeGF.animation.play('idle');
		smokeGF.scale.set(0.5, 0.5);
		smokeGF.updateHitbox();
		smokeGF.alpha = 0.67;
		smokeGF.visible = false;
		smokeGF.cameras = [camChars];
		add(smokeGF);

		smokeBF = sparrow(bfX + 70, bfY - 180, 'smoke');
		smokeBF.animation.addByPrefix('idle', 'retry_smoke', 24);
		smokeBF.animation.play('idle', false, false, 13);
		smokeBF.scale.set(0.5, 0.5);
		smokeBF.updateHitbox();
		smokeBF.alpha = 0.67;
		smokeBF.visible = false;
		smokeBF.cameras = [camChars];
		add(smokeBF);

		smokeCloud = atlas(batteryX - 415, -450, 'smoke-cloud', 0.75, camChars);
		smokeCloud.visible = false;
		add(smokeCloud);

		sparks = new ModMenuSparks();
		sparks.cameras = [camChars];
		add(sparks);
	}

	function buildButtons():Void
	{
		doneBtn = new ModMenuButton();
		doneBtn.setup('done', carBattery.x - 100, FlxG.height * 0.89);
		doneBtn.cameras = [camHUD];
		add(doneBtn);

		folderBtn = new ModMenuButton();
		folderBtn.setup('open-folder', leftBox.x + 180, FlxG.height * 0.89);
		folderBtn.cameras = [camHUD];
		add(folderBtn);
	}

	function countEnabledMods():Int
	{
		var total:Int = 0;
		for (item in enabledList.items)
			if (!item.entry.isBase) total++;
		return total;
	}

	function changeCharacters():Void
	{
		var pinhead:Bool = countEnabledMods() > 0;
		bf.setPinhead(pinhead);
		gf.setPinhead(pinhead);

		gfWire.visible = !gf.hasCustomWires;
		gfWire.animation.play('idle');

		var wire:String = bf.useSmallWire ? 'idle pinhead' : 'idle';
		fgBottom.playAnimation(wire, true);
		fgTop.playAnimation(wire, true);

		bf.play('idle');
		gf.play('idle');
	}

	function readPointer():Void
	{
		ptrJust = false;
		ptrUp = false;

		#if mobile
		var touch = FlxG.touches.getFirst();
		if (touch != null)
		{
			ptrX = touch.viewX;
			ptrY = touch.viewY;
			ptrJust = touch.justPressed;
			ptrUp = touch.justReleased;
			ptrDown = touch.pressed;
		}
		else ptrDown = false;
		#else
		ptrX = FlxG.mouse.viewX;
		ptrY = FlxG.mouse.viewY;
		ptrJust = FlxG.mouse.justPressed;
		ptrUp = FlxG.mouse.justReleased;
		ptrDown = FlxG.mouse.pressed;
		#end
	}

	function buttonAt(px:Float, py:Float):Int
	{
		if (doneBtn.visible && doneBtn.hits(px, py)) return BTN_DONE;
		if (folderBtn.visible && folderBtn.hits(px, py)) return BTN_FOLDER;
		if (px >= backRect[0] && px <= backRect[0] + backRect[2] && py >= backRect[1] && py <= backRect[1] + backRect[3]) return BTN_BACK;
		return -1;
	}

	function viewListAt(px:Float, py:Float):ModMenuList
	{
		if (disabledList.containsView(px, py)) return disabledList;
		if (enabledList.containsView(px, py)) return enabledList;
		return null;
	}

	function boxListAt(px:Float, py:Float):ModMenuList
	{
		if (disabledList.containsBox(px, py)) return disabledList;
		if (enabledList.containsBox(px, py)) return enabledList;
		return null;
	}

	function hasBase(list:ModMenuList):Bool
	{
		return list.items.length > 0 && list.items[list.items.length - 1].entry.isBase;
	}

	function deselectAll():Void
	{
		disabledList.deselect();
		enabledList.deselect();
	}

	function playTick():Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function say(text:String, seconds:Float = 5):Void
	{
		dragText.text = text;
		messageTimer = seconds;
	}

	override function update(elapsed:Float)
	{
		if (!assetsOk)
		{
			super.update(elapsed);
			if (FlxG.mouse.justPressed || FlxG.touches.justStarted().length > 0 || controls.BACK) cancel();
			return;
		}

		super.update(elapsed);

		ambience.update(elapsed);
		disabledList.update(elapsed);
		enabledList.update(elapsed);
		updateFlyers();
		updateBlink(elapsed);

		if (messageTimer > 0)
		{
			messageTimer -= elapsed;
			if (messageTimer <= 0) dragText.text = dragTextDefault;
		}

		if (backWait >= 0)
		{
			backWait -= elapsed;
			if (backWait < 0)
			{
				backWait = -1;
				cancel();
			}
			return;
		}

		handleInput(elapsed);
		updateSequence(elapsed);
	}

	function updateBlink(elapsed:Float):Void
	{
		if (exiting || !allowInput) return;

		bfCountdown -= elapsed;
		if (bfCountdown <= 0 && bf.finished)
		{
			bfCountdown = FlxG.random.float(0, 1) + FlxG.random.float(0, 6);
			bf.play('idle');
		}

		gfCountdown -= elapsed;
		if (gfCountdown <= 0 && gf.finished)
		{
			gfCountdown = FlxG.random.float(0, 1) + FlxG.random.float(0, 8);
			gf.play('idle');
		}
	}

	function updateFlyers():Void
	{
		for (item in flyers.copy())
		{
			var dest:ModMenuList = item.owner;
			var index:Int = dest.items.indexOf(item);
			if (index < 0)
			{
				item.flying = false;
				flyers.remove(item);
				continue;
			}

			item.targetX = dest.slotScreenX();
			item.targetY = dest.cam.y + index * ModMenuList.STEP + dest.scroll;
			item.rate = 16;

			if (Math.abs(item.x - item.targetX) < 3 && Math.abs(item.y - item.targetY) < 3)
			{
				item.flying = false;
				item.toList(dest);
				flyers.remove(item);
			}
		}
	}

	function handleInput(elapsed:Float):Void
	{
		readPointer();

		if (!allowInput)
		{
			if ((ptrJust || controls.ACCEPT) && shockTimer.active && !afterFlash)
			{
				shockTimer.cancel();
				afterShock();
			}
			return;
		}

		#if android
		if (FlxG.android.justReleased.BACK)
		{
			pressBack();
			return;
		}
		#end

		#if !mobile
		if (FlxG.mouse.wheel != 0)
		{
			var wheelList:ModMenuList = viewListAt(ptrX, ptrY);
			if (wheelList != null) wheelList.scrollBy(FlxG.mouse.wheel * 60);
		}
		#end

		if (ptrJust || mode != P_NONE)
		{
			if (ptrJust && usingKeys)
			{
				usingKeys = false;
				applySelection();
			}
			handlePointer(elapsed);
			return;
		}

		handleKeys();
	}

	function handlePointer(elapsed:Float):Void
	{
		if (ptrJust && mode == P_NONE)
		{
			pressX = ptrX;
			pressY = ptrY;
			pressTime = 0;
			pressItem = null;
			pressList = null;

			var btn:Int = buttonAt(ptrX, ptrY);
			if (btn >= 0)
			{
				mode = P_BTN;
				pressBtn = btn;
				setButtonPressed(btn, true);
			}
			else
			{
				var list:ModMenuList = viewListAt(ptrX, ptrY);
				if (list != null)
				{
					mode = P_ITEM;
					pressList = list;
					pressItem = list.itemAt(ptrX, ptrY);
					scrollStart = list.targetScroll;
				}
			}
			return;
		}

		pressTime += elapsed;

		var dx:Float = ptrX - pressX;
		var dy:Float = ptrY - pressY;

		switch (mode)
		{
			case P_BTN:

			case P_ITEM:
				var movable:Bool = pressItem != null && !pressItem.entry.isBase;
				if (movable && Math.abs(dx) > 18 && Math.abs(dx) > Math.abs(dy) * 0.8) startDrag(pressItem);
				else if (Math.abs(dy) > 12)
				{
					mode = P_SCROLL;
					pressList.snap = true;
				}
				else if (movable && pressTime >= 0.4 && ptrDown) startDrag(pressItem);

			case P_SCROLL:
				pressList.targetScroll = scrollStart + dy;
				pressList.clamp();

			case P_DRAG:
				dragItem.targetX = ptrX - dragDX;
				dragItem.targetY = ptrY - dragDY;
		}

		if (ptrUp || (!ptrDown && mode != P_NONE))
		{
			switch (mode)
			{
				case P_BTN:
					var over:Bool = buttonAt(ptrX, ptrY) == pressBtn;
					setButtonPressed(pressBtn, false);
					if (over) fireButton(pressBtn);

				case P_ITEM:
					if (pressItem != null && !pressItem.entry.isBase && pressTime < 0.4) toggle(pressItem);

				case P_SCROLL:
					pressList.snap = false;

				case P_DRAG:
					dropItem();
			}

			mode = P_NONE;
			pressItem = null;
			pressList = null;
			pressBtn = -1;
		}
	}

	function setButtonPressed(btn:Int, down:Bool):Void
	{
		switch (btn)
		{
			case BTN_BACK:
				backBtn.playAnimation(down ? 'press hold' : 'default', true, false, !down);
			case BTN_FOLDER:
				folderBtn.setSelected(down);
			case BTN_DONE:
				doneBtn.setSelected(down);
		}
	}

	function fireButton(btn:Int):Void
	{
		switch (btn)
		{
			case BTN_BACK:
				pressBack();
			case BTN_FOLDER:
				playTick();
				folderBtn.playAccept(openModFolder);
			case BTN_DONE:
				playTick();
				startShock();
		}
	}

	function startDrag(item:ModMenuItem):Void
	{
		var list:ModMenuList = item.owner;
		item.toScreen(list, camTop);
		item.held = true;
		item.rate = 30;
		dragItem = item;
		dragDX = ptrX - item.x;
		dragDY = ptrY - item.y;
		mode = P_DRAG;
		playTick();
	}

	function dropItem():Void
	{
		var item:ModMenuItem = dragItem;
		dragItem = null;
		if (item == null) return;

		var centerX:Float = item.x + ModMenuItem.WIDTH / 2;
		var centerY:Float = item.y + ModMenuItem.ICON / 2;
		var src:ModMenuList = item.owner;
		var dest:ModMenuList = boxListAt(centerX, centerY);
		if (dest == null) dest = src;

		var index:Int = dest.indexForY(centerY);
		moveItem(item, dest, index);
	}

	function moveItem(item:ModMenuItem, dest:ModMenuList, index:Int):Void
	{
		var src:ModMenuList = item.owner;
		item.toScreen(src, camTop);
		src.remove(item);

		var limit:Int = dest.items.length - (hasBase(dest) ? 1 : 0);
		index = Std.int(FlxMath.bound(index, 0, Math.max(0, limit)));

		dest.insert(item, index);
		item.held = false;
		item.flying = true;
		item.selected = false;
		item.rate = 16;
		item.entry.enabled = dest == enabledList;
		if (flyers.indexOf(item) < 0) flyers.push(item);

		dest.ensureVisible(index);
		src.clamp();

		if (dest != src) playTick();
	}

	function toggle(item:ModMenuItem):Void
	{
		if (item.entry.isBase) return;
		var dest:ModMenuList = item.owner == enabledList ? disabledList : enabledList;
		moveItem(item, dest, 0);
	}

	function handleKeys():Void
	{
		var up:Bool = controls.UI_UP_P;
		var down:Bool = controls.UI_DOWN_P;
		var left:Bool = controls.UI_LEFT_P;
		var right:Bool = controls.UI_RIGHT_P;
		var accept:Bool = controls.ACCEPT;
		var back:Bool = controls.BACK;

		if (back)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
			pressBack();
			return;
		}

		if (!(up || down || left || right || accept)) return;

		if (!usingKeys)
		{
			usingKeys = true;
			sel = disabledList.items.length > 0 ? SEL_DIS : SEL_ENA;
			applySelection();
			return;
		}

		var ctrl:Bool = FlxG.keys.pressed.CONTROL;
		var before:Int = sel;

		if (left)
		{
			switch (sel)
			{
				case SEL_DIS:
					sel = SEL_DONE;
				case SEL_ENA:
					sel = disabledList.items.length > 0 ? SEL_DIS : SEL_FOLDER;
				case SEL_FOLDER:
					sel = SEL_ENA;
				case SEL_DONE:
					sel = SEL_FOLDER;
			}
		}
		else if (right)
		{
			switch (sel)
			{
				case SEL_DIS:
					sel = SEL_ENA;
				case SEL_ENA:
					sel = SEL_FOLDER;
				case SEL_FOLDER:
					sel = SEL_DONE;
				case SEL_DONE:
					sel = disabledList.items.length > 0 ? SEL_DIS : SEL_ENA;
			}
		}
		else if (up)
		{
			switch (sel)
			{
				case SEL_DIS:
					if (!moveSelection(disabledList, -1))
					{
						sel = SEL_BACK;
						backFromEnabled = false;
					}
				case SEL_ENA:
					if (ctrl) reorder(enabledList.selectedItem(), -1);
					else if (!moveSelection(enabledList, -1))
					{
						sel = SEL_BACK;
						backFromEnabled = true;
					}
				case SEL_FOLDER:
					sel = disabledList.items.length > 0 ? SEL_DIS : SEL_ENA;
				case SEL_DONE:
					sel = SEL_ENA;
				case SEL_BACK:
					sel = backFromEnabled ? SEL_DONE : SEL_FOLDER;
			}
		}
		else if (down)
		{
			switch (sel)
			{
				case SEL_DIS:
					if (!moveSelection(disabledList, 1)) sel = SEL_FOLDER;
				case SEL_ENA:
					if (ctrl) reorder(enabledList.selectedItem(), 1);
					else if (!moveSelection(enabledList, 1)) sel = SEL_DONE;
				case SEL_FOLDER:
					sel = SEL_BACK;
					backFromEnabled = false;
				case SEL_DONE:
					sel = SEL_BACK;
					backFromEnabled = true;
				case SEL_BACK:
					sel = backFromEnabled ? SEL_ENA : (disabledList.items.length > 0 ? SEL_DIS : SEL_ENA);
			}
		}
		else if (accept)
		{
			switch (sel)
			{
				case SEL_DIS:
					acceptList(disabledList);
				case SEL_ENA:
					acceptList(enabledList);
				case SEL_FOLDER:
					playTick();
					folderBtn.playAccept(openModFolder);
				case SEL_DONE:
					playTick();
					startShock();
				case SEL_BACK:
					pressBack();
			}
			return;
		}

		if (sel != before)
		{
			playTick();
			applySelection();
		}
	}

	function moveSelection(list:ModMenuList, delta:Int):Bool
	{
		var index:Int = list.selIndex + delta;
		if (index < 0 || index >= list.items.length) return false;
		list.select(index);
		playTick();
		return true;
	}

	function acceptList(list:ModMenuList):Void
	{
		var item:ModMenuItem = list.selectedItem();
		if (item == null || item.entry.isBase) return;

		var index:Int = list.selIndex;
		playTick();
		toggle(item);

		if (list.items.length > 0)
		{
			list.select(Std.int(Math.min(index, list.items.length - 1)));
			if (list.items.length == 1 && hasBase(list) && list == enabledList) list.select(0);
		}
		else
		{
			sel = list == disabledList ? SEL_ENA : SEL_DIS;
			applySelection();
		}
	}

	function reorder(item:ModMenuItem, delta:Int):Void
	{
		if (item == null || item.entry.isBase) return;
		var list:ModMenuList = item.owner;
		var index:Int = list.items.indexOf(item);
		var target:Int = index + delta;
		var last:Int = list.items.length - 1 - (hasBase(list) ? 1 : 0);
		if (target < 0 || target > last) return;

		list.items.splice(index, 1);
		list.items.insert(target, item);
		list.select(target);
		playTick();
	}

	function applySelection():Void
	{
		deselectAll();
		folderBtn.setSelected(false);
		doneBtn.setSelected(false);
		if (backBtn != null && !exiting) backBtn.playAnimation('default', true, false, true);

		if (!usingKeys) return;

		if (sel == SEL_DIS && disabledList.items.length == 0) sel = SEL_ENA;

		switch (sel)
		{
			case SEL_DIS:
				disabledList.select(0);
			case SEL_ENA:
				enabledList.select(0);
			case SEL_FOLDER:
				folderBtn.setSelected(true);
			case SEL_DONE:
				doneBtn.setSelected(true);
			case SEL_BACK:
				backBtn.playAnimation('highlighted', true, false, true);
		}
	}

	function pressBack():Void
	{
		if (exiting) return;
		exiting = true;
		allowInput = false;
		backBtn.playAnimation('confirm', true);
		backWait = 0.5;
	}

	function openModFolder():Void
	{
		#if (windows || linux || mac)
		var modFolder:String = Paths.mods();
		if (!NativeFileSystem.exists(modFolder)) NativeFileSystem.createDirectory(modFolder);
		CoolUtil.openFolder(modFolder);
		#else
		say('MODS FOLDER: ' + StorageUtil.getStorageDirectory() + '/mods', 7);
		#end
	}

	function startShock():Void
	{
		if (!allowInput) return;
		allowInput = false;
		mode = P_NONE;
		prevPinhead = bf.usingPinhead;

		bf.play('electrocuted', FlxG.random.int(0, 20), true);
		gf.play('electrocuted', FlxG.random.int(0, 20), true);

		carBattery.animation.resume();
		fgBottom.playAnimation('shock', true, false, true);
		fgTop.playAnimation('shock', true, false, true);

		gfWire.visible = true;
		gfWire.animation.play('shock');

		sparks.startElectrocution();
		doneBtn.playAccept();

		shockTimer.start(81 / 24, function(_:FlxTimer)
		{
			afterShock();
		});
	}

	function afterShock():Void
	{
		blackFlash.visible = true;
		carBattery.visible = false;
		gfWire.visible = false;
		fgTop.visible = false;
		fgBottom.visible = false;
		bgWires.visible = false;
		doneBtn.visible = false;
		folderBtn.visible = false;

		FlxTimer.wait(2 / 24, function()
		{
			blackFlash.visible = false;
			if (VsliceOptions.FLASHBANG) FlxG.camera.flash(0xFFFFFFFF, 1 / 24);

			changeCharacters();

			menuBG.color = 0xFF232327;
			FlxTween.color(menuBG, 1, 0xFF232327, FlxColor.WHITE);

			doneBtn.visible = true;
			folderBtn.visible = true;
			carBattery.visible = true;
			carBattery.animation.reset();
			bgWires.visible = true;
			fgTop.visible = true;
			fgBottom.visible = true;

			smokeCloud.visible = true;
			smokeCloud.alpha = 1;
			smokeCloud.anim.play('', true);
			var cloudSound = Paths.sound('vmods/sounds/smoke-cloud');
			if (cloudSound != null) FlxG.sound.play(cloudSound);
			FlxTween.tween(smokeCloud, {alpha: 0}, 62 / 24, {
				ease: FlxEase.linear,
				onComplete: function(_:FlxTween)
				{
					smokeCloud.visible = false;
				}
			});

			sparks.endElectrocution();

			var crispy:Bool = !prevPinhead && !bf.usingPinhead;
			crispyShown = false;

			if (crispy && bf.hasAnim('crispy'))
			{
				crispyShown = true;
				bf.play('crispy');
			}
			else bf.play('idle');

			if (crispy && gf.hasAnim('crispy'))
			{
				crispyShown = true;
				gf.play('crispy');
			}
			else
			{
				gf.play('idle');
				gf.pause();
				gfHeld = true;
			}

			if (crispyShown)
			{
				smokeBF.visible = true;
				smokeBF.animation.play('idle', true, false, 13);
				smokeGF.visible = true;
				smokeGF.animation.play('idle', true);
				fgBottom.playAnimation('end', true);
				fgTop.playAnimation('end', true);
			}

			crispyTimer = 0;
			afterFlash = true;
		});
	}

	function updateSequence(elapsed:Float):Void
	{
		if (allowInput || !afterFlash || finishing) return;

		crispyTimer += elapsed;

		if (crispyShown && !crispySfx && crispyTimer >= 0.7)
		{
			crispySfx = true;
			var crispySound = Paths.sound('vmods/sounds/crispy');
			if (crispySound != null) FlxG.sound.play(crispySound);
		}

		if (gfHeld && crispyTimer >= 0.3)
		{
			gfHeld = false;
			gf.resume();
		}

		if (crispyTimer >= 2.5)
		{
			finishing = true;
			confirm();
		}
	}

	function saveList():Void
	{
		var fileStr:String = '';
		for (list in [enabledList, disabledList])
		{
			var isOn:Bool = list == enabledList;
			for (item in list.items)
			{
				if (item.entry.isBase) continue;
				if (fileStr.length > 0) fileStr += '\n';
				fileStr += item.entry.folder + '|' + (isOn ? '1' : '0');
			}
		}

		var path:String = StorageUtil.getStorageDirectory() + '/modsList.txt';
		try
		{
			File.saveContent(path, fileStr);
		}
		catch (e:Dynamic) {}

		Mods.parseList();
		Mods.loadTopMod();
	}

	function leave():Void
	{
		exiting = true;
		#if !mobile
		FlxG.mouse.visible = false;
		#end
		if (ambience != null) ambience.stop();
	}

	function cancel():Void
	{
		leave();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		MusicBeatState.switchState(new MainMenuState());
	}

	function confirm():Void
	{
		leave();
		saveList();
		FlxG.sound.play(Paths.sound('confirmMenu'));

		var restart:Bool = false;
		for (list in [enabledList, disabledList])
			for (item in list.items)
				if (!item.entry.isBase && item.entry.mustRestart && item.entry.enabled != item.entry.startEnabled) restart = true;

		if (restart)
		{
			TitleState.initialized = false;
			TitleState.closedState = false;
			if (FlxG.sound.music != null) FlxG.sound.music.fadeOut(0.3);
			FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
		}
		else MusicBeatState.switchState(new MainMenuState());
	}

	override function destroy()
	{
		if (ambience != null) ambience.stop();
		shockTimer.destroy();
		super.destroy();
	}
}
