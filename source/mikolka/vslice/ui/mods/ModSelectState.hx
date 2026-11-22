package mikolka.vslice.ui.mods;

import backend.Mods;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import mikolka.vslice.ui.title.TitleState;
import openfl.display.BitmapData;

class ModEntry
{
	public var folder:String;
	public var name:String;
	public var desc:String = 'No description provided.';
	public var iconFps:Int = 10;
	public var mustRestart:Bool = false;
	public var enabled:Bool;
	public var startEnabled:Bool;
	public var row:ModRow;

	public function new(folder:String, enabled:Bool)
	{
		this.folder = folder;
		this.name = folder;
		this.enabled = enabled;
		this.startEnabled = enabled;

		var pack:Dynamic = Mods.getPack(folder);
		if (pack != null)
		{
			if (pack.name != null) name = pack.name;
			if (pack.description != null) desc = pack.description;
			if (pack.iconFramerate != null) iconFps = pack.iconFramerate;
			mustRestart = pack.restart == true;
		}
	}
}

class ModRow extends FlxSpriteGroup
{
	public var entry:ModEntry;
	public var targetY:Float = 0;
	public var rowHeight:Float;

	var icon:FlxSprite;
	var nameText:FlxText;
	var descText:FlxText;

	public function new(entry:ModEntry, scale:Float, width:Float)
	{
		super();

		this.entry = entry;
		rowHeight = 90 * scale;
		var iconSize:Float = 76 * scale;

		icon = new FlxSprite(30 * scale, 7 * scale);
		icon.antialiasing = ClientPrefs.data.antialiasing;

		var isPixel:Bool = false;
		var file:String = Paths.mods('${entry.folder}/pack.png');
		if (!NativeFileSystem.exists(file))
		{
			file = Paths.mods('${entry.folder}/pack-pixel.png');
			isPixel = true;
		}

		var bmp:BitmapData = NativeFileSystem.getBitmap(file);
		if (bmp != null)
		{
			icon.loadGraphic(CacheSystem.cacheBitmap(file, bmp), true, 150, 150);
			if (isPixel) icon.antialiasing = false;
		}
		else
		{
			icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		}

		icon.setGraphicSize(Std.int(iconSize), Std.int(iconSize));
		icon.updateHitbox();

		if (bmp != null)
		{
			var total:Int = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
			if (total > 1)
			{
				icon.animation.add('icon', [for (i in 0...total) i], entry.iconFps);
				icon.animation.play('icon');
			}
		}
		add(icon);

		var textX:Float = 30 * scale + iconSize + 10 * scale;
		var textW:Float = width - textX - 8 * scale;
		var nameSize:Int = Std.int(17 * scale);
		var descSize:Int = Std.int(12 * scale);

		nameText = new FlxText(textX, 6 * scale, textW, entry.name.toUpperCase(), nameSize);
		nameText.setFormat(Paths.font('vcr.ttf'), nameSize, FlxColor.WHITE, LEFT);
		nameText.wordWrap = false;
		add(nameText);

		var desc:String = entry.desc.toUpperCase();
		var maxChars:Int = Std.int(textW / (descSize * 0.6)) * 3 - 3;
		if (desc.length > maxChars) desc = desc.substr(0, maxChars) + '...';

		descText = new FlxText(textX, nameText.y + nameText.height + 2 * scale, textW, desc, descSize);
		descText.setFormat(Paths.font('vcr.ttf'), descSize, 0xFFDDDDDD, LEFT);
		add(descText);
	}
}

class ModSelectState extends MusicBeatState
{
	static inline var MODE_IDLE:Int = 0;
	static inline var MODE_PRESS:Int = 1;
	static inline var MODE_SCROLL:Int = 2;
	static inline var MODE_DRAG:Int = 3;
	static inline var HOLD_SECONDS:Float = 0.35;

	var s:Float = 1;
	var ox:Float = 0;
	var rowH:Float = 90;
	var pad:Float = 6;

	var lists:Array<Array<ModEntry>> = [[], []];
	var panelCams:Array<FlxCamera> = [];
	var scrolls:Array<Float> = [0, 0];
	var panelW:Float = 0;
	var topCam:FlxCamera;
	var marker:FlxSprite;
	var ghost:ModRow;
	var subtitle:FlxText;
	var subtitleDefault:String;
	var messageTimer:Float = 0;
	var emptyText:FlxText;

	var buttonRects:Array<Array<Float>> = [];

	var mode:Int = MODE_IDLE;
	var exiting:Bool = false;

	var ptrX:Float = 0;
	var ptrY:Float = 0;
	var ptrJust:Bool = false;
	var ptrUp:Bool = false;
	var ptrDown:Bool = false;

	var pressX:Float = 0;
	var pressY:Float = 0;
	var pressTime:Float = 0;
	var pressEntry:ModEntry = null;
	var pressList:Int = -1;
	var pressButton:Int = -1;
	var scrollStart:Float = 0;

	var dragEntry:ModEntry = null;
	var dragFrom:Int = 0;
	var dragTarget:Int = -1;
	var dragIndex:Int = 0;

	override function create()
	{
		persistentUpdate = false;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		CacheSystem.clearStoredMemory();
		CacheSystem.clearUnusedMemory();

		s = FlxG.height / 576;
		ox = (FlxG.width - 1280 * s) / 2;
		rowH = 90 * s;
		pad = 6 * s;

		#if !mobile
		FlxG.mouse.visible = true;
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF4A4166;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		var modList:ModsList = Mods.parseList();
		Mods.loadTopMod();

		for (mod in modList.all)
		{
			if (mod.trim().length < 1) continue;
			var enabled:Bool = !modList.disabled.contains(mod);
			lists[enabled ? 1 : 0].push(new ModEntry(mod, enabled));
		}

		var title:FlxText = new FlxText(0, 14 * s, FlxG.width, Language.getPhrase('mod_menu_title', 'CHOOSE YOUR MODS'), Std.int(44 * s));
		title.setFormat(Paths.font('vcr.ttf'), Std.int(44 * s), FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
		title.borderSize = 3 * s;
		add(title);

		subtitleDefault = Language.getPhrase('mod_menu_hint', 'TAP A MOD TO MOVE IT. HOLD AND DRAG TO REORDER');
		subtitle = new FlxText(0, 78 * s, FlxG.width, subtitleDefault, Std.int(16 * s));
		subtitle.setFormat(Paths.font('vcr.ttf'), Std.int(16 * s), FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
		subtitle.borderSize = 2 * s;
		add(subtitle);

		var arrow:FlxSprite = new FlxSprite(ox + 115 * s, 15 * s).makeGraphic(Std.int(70 * s), Std.int(50 * s), FlxColor.TRANSPARENT, true);
		var w:Float = 70 * s;
		var h:Float = 50 * s;
		var points:Array<FlxPoint> = [
			FlxPoint.get(3 * s, h * 0.5),
			FlxPoint.get(w * 0.36, 3 * s),
			FlxPoint.get(w * 0.36, h * 0.3),
			FlxPoint.get(w - 3 * s, h * 0.3),
			FlxPoint.get(w - 3 * s, h * 0.7),
			FlxPoint.get(w * 0.36, h * 0.7),
			FlxPoint.get(w * 0.36, h - 3 * s)
		];
		FlxSpriteUtil.drawPolygon(arrow, points, FlxColor.WHITE, {thickness: 3 * s, color: 0xFF1E1A2E});
		add(arrow);
		buttonRects.push([arrow.x - 10 * s, arrow.y - 10 * s, w + 20 * s, h + 20 * s]);

		var panelXs:Array<Float> = [ox + 165 * s, ox + 508 * s];
		var panelY:Float = 110 * s;
		panelW = 312 * s;
		var panelH:Float = 385 * s;
		var labels:Array<String> = [Language.getPhrase('mod_menu_disabled', 'DISABLED'), Language.getPhrase('mod_menu_enabled', 'ENABLED')];

		for (i in 0...2)
		{
			var panel:FlxSprite = new FlxSprite(panelXs[i], panelY).makeGraphic(Std.int(panelW), Std.int(panelH), FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(panel, 0, 0, panelW, panelH, 16 * s, 16 * s, 0xFF1F1E24);
			panel.alpha = 0.95;
			add(panel);

			var label:FlxText = new FlxText(panelXs[i], panelY + 8 * s, panelW, labels[i], Std.int(18 * s));
			label.setFormat(Paths.font('vcr.ttf'), Std.int(18 * s), FlxColor.WHITE, CENTER);
			add(label);

			var cam:FlxCamera = new FlxCamera(Std.int(panelXs[i]), Std.int(panelY + 40 * s), Std.int(panelW), Std.int(panelH - 46 * s));
			cam.bgColor.alpha = 0;
			FlxG.cameras.add(cam, false);
			panelCams.push(cam);

			for (entry in lists[i])
			{
				entry.row = new ModRow(entry, s, panelW);
				entry.row.cameras = [cam];
				add(entry.row);
			}

			layoutList(i, true);
		}

		topCam = new FlxCamera();
		topCam.bgColor.alpha = 0;
		FlxG.cameras.add(topCam, false);

		marker = new FlxSprite().makeGraphic(Std.int(panelW - 20 * s), Std.int(Math.max(2, 3 * s)), FlxColor.WHITE);
		marker.cameras = [topCam];
		marker.visible = false;
		add(marker);

		addPlate(ox + 307 * s, 513 * s, 385 * s, 45 * s, Language.getPhrase('mod_menu_folder', 'OPEN MOD FOLDER'), 18);
		addPlate(ox + 808 * s, 513 * s, 260 * s, 55 * s, Language.getPhrase('mod_menu_done', 'DONE'), 34);

		if (lists[0].length + lists[1].length == 0)
		{
			emptyText = new FlxText(0, 0, FlxG.width, Language.getPhrase('mod_menu_empty', 'NO MODS FOUND\nPUT YOUR MODS INSIDE THE MODS FOLDER'), Std.int(22 * s));
			emptyText.setFormat(Paths.font('vcr.ttf'), Std.int(22 * s), FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
			emptyText.screenCenter(Y);
			add(emptyText);
		}

		super.create();
	}

	function addPlate(x:Float, y:Float, w:Float, h:Float, label:String, size:Int):Void
	{
		var plate:FlxSprite = new FlxSprite(x, y).makeGraphic(Std.int(w), Std.int(h), FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(plate, 0, 0, w, h, 12 * s, 12 * s, 0xFF8D90B8, {thickness: 3 * s, color: 0xFFE6E6F5});
		add(plate);

		var text:FlxText = new FlxText(x, y, w, label, Std.int(size * s));
		text.setFormat(Paths.font('vcr.ttf'), Std.int(size * s), FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
		text.borderSize = 2 * s;
		text.y = y + (h - text.height) / 2;
		add(text);

		buttonRects.push([x, y, w, h]);
	}

	function layoutList(i:Int, snap:Bool = false):Void
	{
		for (j in 0...lists[i].length)
		{
			var row:ModRow = lists[i][j].row;
			row.targetY = pad + j * rowH;
			row.x = 0;
			if (snap) row.y = row.targetY;
		}
		scrolls[i] = FlxMath.bound(scrolls[i], 0, maxScroll(i));
	}

	function maxScroll(i:Int):Float
	{
		return Math.max(0, lists[i].length * rowH + pad * 2 - panelCams[i].height);
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

	function buttonAt(x:Float, y:Float):Int
	{
		for (i in 0...buttonRects.length)
		{
			var r:Array<Float> = buttonRects[i];
			if (x >= r[0] && x <= r[0] + r[2] && y >= r[1] && y <= r[1] + r[3]) return i;
		}
		return -1;
	}

	function panelAt(x:Float, y:Float):Int
	{
		for (i in 0...panelCams.length)
		{
			var cam:FlxCamera = panelCams[i];
			if (x >= cam.x && x <= cam.x + cam.width && y >= cam.y && y <= cam.y + cam.height) return i;
		}
		return -1;
	}

	function indexAt(i:Int, y:Float):Int
	{
		return Math.floor((y - panelCams[i].y + scrolls[i] - pad) / rowH);
	}

	function slotAt(i:Int, y:Float):Int
	{
		var raw:Float = (y - panelCams[i].y + scrolls[i] - pad) / rowH;
		return Std.int(FlxMath.bound(Math.round(raw), 0, lists[i].length));
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (exiting) return;

		if (controls.BACK)
		{
			cancel();
			return;
		}

		updatePointer(elapsed);

		var lerpVal:Float = 1 - Math.exp(-elapsed * 18);
		for (i in 0...2)
		{
			for (entry in lists[i])
				if (entry.row != null) entry.row.y = FlxMath.lerp(entry.row.y, entry.row.targetY, lerpVal);

			panelCams[i].scroll.y = scrolls[i];
		}

		if (messageTimer > 0)
		{
			messageTimer -= elapsed;
			if (messageTimer <= 0) subtitle.text = subtitleDefault;
		}
	}

	function updatePointer(elapsed:Float):Void
	{
		readPointer();

		var released:Bool = ptrUp || (mode != MODE_IDLE && !ptrDown);

		switch (mode)
		{
			case MODE_IDLE:
				if (ptrJust) beginPress();

			case MODE_PRESS:
				if (released)
				{
					endPress();
					return;
				}

				pressTime += elapsed;
				if (pressButton >= 0) return;

				var moved:Bool = Math.abs(ptrX - pressX) > 14 * s || Math.abs(ptrY - pressY) > 14 * s;
				if (moved)
				{
					if (pressList >= 0)
					{
						mode = MODE_SCROLL;
						scrollStart = scrolls[pressList];
					}
					else mode = MODE_IDLE;
				}
				else if (pressEntry != null && pressTime >= HOLD_SECONDS) startDrag();

			case MODE_SCROLL:
				if (released) mode = MODE_IDLE;
				else scrolls[pressList] = FlxMath.bound(scrollStart - (ptrY - pressY), 0, maxScroll(pressList));

			case MODE_DRAG:
				if (released) drop();
				else moveDrag(elapsed);
		}
	}

	function beginPress():Void
	{
		pressX = ptrX;
		pressY = ptrY;
		pressTime = 0;
		pressEntry = null;
		pressList = -1;
		pressButton = buttonAt(ptrX, ptrY);

		if (pressButton >= 0)
		{
			mode = MODE_PRESS;
			return;
		}

		var panel:Int = panelAt(ptrX, ptrY);
		if (panel < 0) return;

		pressList = panel;
		var index:Int = indexAt(panel, ptrY);
		if (index >= 0 && index < lists[panel].length) pressEntry = lists[panel][index];
		mode = MODE_PRESS;
	}

	function endPress():Void
	{
		mode = MODE_IDLE;

		if (pressButton >= 0)
		{
			if (buttonAt(ptrX, ptrY) == pressButton) fireButton(pressButton);
			return;
		}

		if (pressEntry != null && pressTime < HOLD_SECONDS) toggleEntry(pressEntry);
	}

	function fireButton(id:Int):Void
	{
		switch (id)
		{
			case 0:
				cancel();
			case 1:
				openModFolder();
			case 2:
				confirm();
		}
	}

	function toggleEntry(entry:ModEntry):Void
	{
		var from:Int = lists[0].contains(entry) ? 0 : 1;
		var to:Int = 1 - from;

		lists[from].remove(entry);
		lists[to].insert(0, entry);
		entry.enabled = to == 1;

		entry.row.cameras = [panelCams[to]];
		scrolls[to] = 0;
		layoutList(from);
		layoutList(to);
		entry.row.y = entry.row.targetY - rowH * 0.5;
		entry.row.alpha = 0;
		FlxTween.tween(entry.row, {alpha: 1}, 0.2);

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function startDrag():Void
	{
		mode = MODE_DRAG;
		dragEntry = pressEntry;
		dragFrom = pressList;
		dragTarget = dragFrom;
		dragIndex = lists[dragFrom].indexOf(dragEntry);

		dragEntry.row.alpha = 0.25;

		ghost = new ModRow(dragEntry, s, panelW);
		ghost.cameras = [topCam];
		ghost.alpha = 0.95;
		add(ghost);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function moveDrag(elapsed:Float):Void
	{
		ghost.x = ptrX - panelW / 2;
		ghost.y = ptrY - rowH / 2;

		var target:Int = panelAt(ptrX, ptrY);
		dragTarget = target;

		if (target < 0)
		{
			marker.visible = false;
			return;
		}

		var cam:FlxCamera = panelCams[target];
		if (ptrY < cam.y + 30 * s) scrolls[target] = FlxMath.bound(scrolls[target] - 500 * s * elapsed, 0, maxScroll(target));
		else if (ptrY > cam.y + cam.height - 30 * s) scrolls[target] = FlxMath.bound(scrolls[target] + 500 * s * elapsed, 0, maxScroll(target));

		dragIndex = slotAt(target, ptrY);

		var markerY:Float = cam.y + pad + dragIndex * rowH - scrolls[target] - marker.height / 2;
		marker.visible = markerY >= cam.y - 2 && markerY <= cam.y + cam.height;
		marker.x = cam.x + 10 * s;
		marker.y = markerY;
	}

	function drop():Void
	{
		mode = MODE_IDLE;

		remove(ghost, true);
		ghost.destroy();
		ghost = null;
		marker.visible = false;

		var entry:ModEntry = dragEntry;
		dragEntry = null;
		entry.row.alpha = 1;

		if (dragTarget < 0) return;

		var from:Int = dragFrom;
		var to:Int = dragTarget;
		var index:Int = dragIndex;
		var oldIndex:Int = lists[from].indexOf(entry);

		lists[from].remove(entry);
		if (from == to && index > oldIndex) index--;
		index = Std.int(FlxMath.bound(index, 0, lists[to].length));
		lists[to].insert(index, entry);
		entry.enabled = to == 1;

		if (from != to) entry.row.cameras = [panelCams[to]];

		layoutList(from);
		layoutList(to);
		if (from != to) entry.row.y = entry.row.targetY;

		if (from != to || index != oldIndex) FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function openModFolder():Void
	{
		#if (windows || linux)
		var modFolder:String = Paths.mods();
		if (!NativeFileSystem.exists(modFolder)) NativeFileSystem.createDirectory(modFolder);
		CoolUtil.openFolder(modFolder);
		#else
		subtitle.text = 'MODS: ' + StorageUtil.getStorageDirectory() + '/mods';
		messageTimer = 6;
		#end
	}

	function saveList():Void
	{
		var fileStr:String = '';
		for (i in [1, 0])
		{
			for (entry in lists[i])
			{
				if (fileStr.length > 0) fileStr += '\n';
				fileStr += entry.folder + '|' + (i == 1 ? '1' : '0');
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
		for (i in 0...2)
			for (entry in lists[i])
				if (entry.mustRestart && entry.enabled != entry.startEnabled) restart = true;

		if (restart)
		{
			TitleState.initialized = false;
			TitleState.closedState = false;
			FlxG.sound.music.fadeOut(0.3);
			FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
		}
		else MusicBeatState.switchState(new MainMenuState());
	}
}
