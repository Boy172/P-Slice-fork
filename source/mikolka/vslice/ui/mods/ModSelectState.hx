package mikolka.vslice.ui.mods;

import backend.Mods;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import mikolka.vslice.ui.mods.ModMenuList; // ModEntry, ModMenuItem, ModMenuStyle y ModMenuList viven aquí
import mikolka.vslice.ui.title.TitleState;

/**
 * Mod Menu estilo V-Slice 0.9.0 para P-Slice.
 *
 * Capas (de abajo hacia arriba):
 *   1. cámara principal: fondo, paneles, scrollbars, personajes, chispas, textos, botones
 *   2. una cámara por lista (recorta los items al panel)
 *   3. topCam: item que estás arrastrando + marcador de inserción
 *
 * Como las listas están en cámaras propias, SIEMPRE se dibujan encima de los personajes.
 */
class ModSelectState extends MusicBeatState
{
	// ===================== LAYOUT (referencia 720p) =====================
	// Todo se centra horizontalmente en pantallas anchas (vslice-fullscreen).
	// Si algo queda desplazado, ajusta SOLO estas constantes.
	static inline var PANEL_W:Float = 391;
	static inline var PANEL_H:Float = 481;
	static inline var PANEL_Y:Float = 137;
	static inline var PANEL_GAP:Float = 38; // entre Disabled y Enabled
	static inline var CHAR_GAP:Float = 50; // entre Enabled y los personajes
	static inline var CHAR_W:Float = 330; // ancho aprox. del bloque BF + GF
	static inline var CHAR_Y:Float = 90;
	static inline var GF_DX:Float = 170; // separación entre BF y GF
	static inline var CHAR_NUDGE_X:Float = 0; // ajuste fino de personajes
	static inline var CHAR_NUDGE_Y:Float = 0;

	// Nombres de imagen en images/vmods/ (ModMenuButton agrega -highlighted / -inverted solo)
	static inline var BTN_FOLDER:String = 'open-mod-folder';
	static inline var BTN_DONE:String = 'done';
	// ====================================================================

	static inline var MODE_IDLE:Int = 0;
	static inline var MODE_PRESS:Int = 1;
	static inline var MODE_SCROLL:Int = 2;
	static inline var MODE_DRAG:Int = 3;
	static inline var HOLD_SECONDS:Float = 0.35;

	static inline var BTN_BACK_ID:Int = 0;
	static inline var BTN_FOLDER_ID:Int = 1;
	static inline var BTN_DONE_ID:Int = 2;

	var oy:Float = 0;

	var lists:Array<ModMenuList> = [];
	var topCam:FlxCamera;
	var marker:FlxSprite;
	var subtitle:FlxText;
	var subtitleDefault:String;
	var messageTimer:Float = 0;
	var emptyText:FlxText;

	var backArrow:FlxSprite;
	var folderBtn:ModMenuButton;
	var doneBtn:ModMenuButton;

	var bf:ModMenuCharacter;
	var gf:ModMenuCharacter;
	var sparks:ModMenuSparks;
	var ambience:ModMenuAmbience;

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
	var pressItem:ModMenuItem = null;
	var pressList:Int = -1;
	var pressButton:Int = -1;
	var scrollStart:Float = 0;

	var dragItem:ModMenuItem = null;
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

		// el layout está pensado para 720 de alto; si el juego tiene otra altura lo centramos
		oy = (FlxG.height - 720) / 2;

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

		var totalW:Float = PANEL_W * 2 + PANEL_GAP + CHAR_GAP + CHAR_W;
		var left:Float = Math.max(20, (FlxG.width - totalW) / 2);
		var charLeft:Float = left + PANEL_W * 2 + PANEL_GAP + CHAR_GAP + CHAR_NUDGE_X;
		var charTop:Float = CHAR_Y + oy + CHAR_NUDGE_Y;
		var panelY:Float = PANEL_Y + oy;

		// ---------- paneles + listas ----------
		var labels:Array<String> = [
			Language.getPhrase('mod_menu_disabled', 'DISABLED'),
			Language.getPhrase('mod_menu_enabled', 'ENABLED')
		];

		for (i in 0...2)
		{
			var px:Float = left + i * (PANEL_W + PANEL_GAP);

			var panel:FlxSprite = new FlxSprite(px, panelY).makeGraphic(Std.int(PANEL_W), Std.int(PANEL_H), FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(panel, 0, 0, PANEL_W, PANEL_H, 18, 18, 0xFF1F1E24);
			panel.alpha = 0.95;
			add(panel);

			var label:FlxText = new FlxText(px, panelY + 8, PANEL_W, labels[i], 28);
			label.setFormat(ModMenuStyle.fontPath, 28, FlxColor.WHITE, CENTER);
			add(label);

			var cam:FlxCamera = new FlxCamera(Std.int(px), Std.int(panelY + 52), Std.int(PANEL_W), Std.int(PANEL_H - 64));
			cam.bgColor.alpha = 0;
			FlxG.cameras.add(cam, false);

			var list:ModMenuList = new ModMenuList(new FlxRect(px, panelY, PANEL_W, PANEL_H), cam);
			add(list.track);
			add(list.thumb);
			lists.push(list);
		}

		// ---------- personajes / chispas (cámara principal, debajo de las listas) ----------
		try
		{
			bf = new ModMenuCharacter(charLeft, charTop, 'bf', false, FlxG.camera);
			gf = new ModMenuCharacter(charLeft + GF_DX, charTop, 'gf', true, FlxG.camera);
			add(bf.group);
			add(gf.group);
			if (bf.hasAnim('idle')) bf.play('idle', 0, true);
			if (gf.hasAnim('idle')) gf.play('idle', 0, true);

			sparks = new ModMenuSparks();
			sparks.setPosition(charLeft, charTop);
			add(sparks);
		}
		catch (e:Dynamic)
		{
			trace('ModSelectState: no se pudieron cargar los personajes: $e');
		}

		// ---------- entradas ----------
		var modList:ModsList = Mods.parseList();
		Mods.loadTopMod();

		for (mod in modList.all)
		{
			if (mod.trim().length < 1) continue;
			var enabled:Bool = !modList.disabled.contains(mod);
			var list:ModMenuList = lists[enabled ? 1 : 0];
			var item:ModMenuItem = new ModMenuItem(new ModEntry(mod, enabled));
			item.cameras = [list.cam];
			add(item);
			list.insert(item, list.items.length);
		}

		for (list in lists)
			for (j in 0...list.items.length)
				list.items[j].snapTo(ModMenuList.ITEM_X, j * ModMenuList.STEP);

		// ---------- textos ----------
		var title:FlxText = new FlxText(0, 14 + oy, FlxG.width, Language.getPhrase('mod_menu_title', 'CHOOSE YOUR MODS'), 56);
		title.setFormat(ModMenuStyle.fontPath, 56, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
		title.borderSize = 3;
		add(title);

		subtitleDefault = Language.getPhrase('mod_menu_hint', 'TAP A MOD TO MOVE IT. OR HOLD AND DRAG TO REORDER');
		subtitle = new FlxText(0, 90 + oy, FlxG.width, subtitleDefault, 24);
		subtitle.setFormat(ModMenuStyle.fontPath, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
		subtitle.borderSize = 2;
		add(subtitle);

		// ---------- flecha de volver (misma lógica táctil que ya tenías) ----------
		backArrow = new FlxSprite(30, 20 + oy).makeGraphic(70, 50, FlxColor.TRANSPARENT, true);
		var points:Array<FlxPoint> = [
			FlxPoint.get(3, 25),
			FlxPoint.get(25, 3),
			FlxPoint.get(25, 15),
			FlxPoint.get(67, 15),
			FlxPoint.get(67, 35),
			FlxPoint.get(25, 35),
			FlxPoint.get(25, 47)
		];
		FlxSpriteUtil.drawPolygon(backArrow, points, FlxColor.WHITE, {thickness: 3, color: 0xFF1E1A2E});
		add(backArrow);

		// ---------- botones con arte ----------
		var btnY:Float = panelY + PANEL_H + 22;
		folderBtn = new ModMenuButton();
		doneBtn = new ModMenuButton();
		placeButton(folderBtn, BTN_FOLDER, left + (PANEL_W * 2 + PANEL_GAP) / 2, btnY);
		placeButton(doneBtn, BTN_DONE, charLeft + CHAR_W / 2, btnY);
		add(folderBtn);
		add(doneBtn);

		// ---------- capa superior para arrastrar ----------
		topCam = new FlxCamera();
		topCam.bgColor.alpha = 0;
		FlxG.cameras.add(topCam, false);

		marker = new FlxSprite().makeGraphic(ModMenuItem.WIDTH, 4, FlxColor.WHITE);
		marker.cameras = [topCam];
		marker.visible = false;
		add(marker);

		if (lists[0].items.length + lists[1].items.length == 0)
		{
			emptyText = new FlxText(0, 0, FlxG.width, Language.getPhrase('mod_menu_empty', 'NO MODS FOUND\nPUT YOUR MODS INSIDE THE MODS FOLDER'), 26);
			emptyText.setFormat(ModMenuStyle.fontPath, 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, 0xFF1E1A2E);
			emptyText.screenCenter(Y);
			add(emptyText);
		}

		ambience = new ModMenuAmbience();
		ambience.start();

		super.create();
	}

	/** Coloca un botón con arte centrado en cx. Se llama setup dos veces porque el ancho solo se conoce tras cargar la imagen. */
	function placeButton(btn:ModMenuButton, name:String, cx:Float, y:Float):Void
	{
		btn.setup(name, 0, y);
		btn.setup(name, cx - btn.frameWidth * ModMenuButton.REST_SCALE / 2, y);
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
		if (x >= backArrow.x - 10 && x <= backArrow.x + backArrow.width + 10 && y >= backArrow.y - 10 && y <= backArrow.y + backArrow.height + 10)
			return BTN_BACK_ID;
		if (folderBtn.hits(x, y)) return BTN_FOLDER_ID;
		if (doneBtn.hits(x, y)) return BTN_DONE_ID;
		return -1;
	}

	/** Lista cuya zona visible (donde están los items) contiene el punto. */
	function viewAt(x:Float, y:Float):Int
	{
		for (i in 0...lists.length)
			if (lists[i].containsView(x, y)) return i;
		return -1;
	}

	/** Lista cuyo panel completo contiene el punto (para soltar items). */
	function boxAt(x:Float, y:Float):Int
	{
		for (i in 0...lists.length)
			if (lists[i].containsBox(x, y)) return i;
		return -1;
	}

	function setButtonSelected(id:Int, value:Bool):Void
	{
		switch (id)
		{
			case BTN_FOLDER_ID:
				folderBtn.setSelected(value);
			case BTN_DONE_ID:
				doneBtn.setSelected(value);
		}
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

		if (ambience != null) ambience.update(elapsed);

		#if !mobile
		if (FlxG.mouse.wheel != 0)
		{
			var wheelList:Int = viewAt(FlxG.mouse.viewX, FlxG.mouse.viewY);
			if (wheelList >= 0) lists[wheelList].scrollBy(FlxG.mouse.wheel * ModMenuList.STEP);
		}
		#end

		updatePointer(elapsed);

		for (i in 0...lists.length)
		{
			// mientras arrastras con el dedo/mouse la lista sigue el puntero sin suavizado
			lists[i].snap = mode == MODE_SCROLL && pressList == i;
			lists[i].update(elapsed);
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

				var moved:Bool = Math.abs(ptrX - pressX) > 14 || Math.abs(ptrY - pressY) > 14;
				if (moved)
				{
					if (pressList >= 0)
					{
						mode = MODE_SCROLL;
						scrollStart = lists[pressList].targetScroll;
						if (pressItem != null) pressItem.selected = false;
					}
					else mode = MODE_IDLE;
				}
				else if (pressItem != null && pressTime >= HOLD_SECONDS) startDrag();

			case MODE_SCROLL:
				if (released) mode = MODE_IDLE;
				else
				{
					var list:ModMenuList = lists[pressList];
					list.targetScroll = FlxMath.bound(scrollStart + (ptrY - pressY), list.minScroll(), 0);
				}

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
		pressItem = null;
		pressList = -1;
		pressButton = buttonAt(ptrX, ptrY);

		if (pressButton >= 0)
		{
			setButtonSelected(pressButton, true);
			mode = MODE_PRESS;
			return;
		}

		var panel:Int = viewAt(ptrX, ptrY);
		if (panel < 0) return;

		pressList = panel;
		pressItem = lists[panel].itemAt(ptrX, ptrY);
		if (pressItem != null) pressItem.selected = true;
		mode = MODE_PRESS;
	}

	function endPress():Void
	{
		mode = MODE_IDLE;

		if (pressButton >= 0)
		{
			setButtonSelected(pressButton, false);
			if (buttonAt(ptrX, ptrY) == pressButton) fireButton(pressButton);
			return;
		}

		if (pressItem != null)
		{
			pressItem.selected = false;
			if (pressTime < HOLD_SECONDS) toggleItem(pressItem);
		}
	}

	function fireButton(id:Int):Void
	{
		switch (id)
		{
			case BTN_BACK_ID:
				cancel();
			case BTN_FOLDER_ID:
				folderBtn.playAccept(openModFolder);
			case BTN_DONE_ID:
				exiting = true;
				doneBtn.playAccept(confirm);
		}
	}

	function listOf(item:ModMenuItem):Int
	{
		return lists[0].items.contains(item) ? 0 : 1;
	}

	/** Toque corto: pasa el mod a la otra lista (arriba del todo). */
	function toggleItem(item:ModMenuItem):Void
	{
		var from:Int = listOf(item);
		var to:Int = 1 - from;
		var dst:ModMenuList = lists[to];

		lists[from].remove(item);
		dst.insert(item, 0);
		item.entry.enabled = to == 1;

		item.cameras = [dst.cam];
		dst.targetScroll = 0;
		dst.scroll = 0;

		// entra desde un poco más arriba de su slot y se desvanece
		item.setPosition(ModMenuList.ITEM_X, -ModMenuList.STEP * 0.5);
		item.fade = 0;
		FlxTween.tween(item, {fade: 1}, 0.2);
		item.flashBackground();

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	/** Mantener pulsado: el item "vuela" con el puntero en la cámara superior. */
	function startDrag():Void
	{
		mode = MODE_DRAG;
		dragItem = pressItem;
		dragFrom = pressList;
		dragTarget = dragFrom;

		var list:ModMenuList = lists[dragFrom];
		dragIndex = list.items.indexOf(dragItem);

		dragItem.toScreen(list, topCam);
		dragItem.held = true;
		dragItem.flying = true;
		dragItem.rate = 40;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function moveDrag(elapsed:Float):Void
	{
		dragItem.targetX = ptrX - ModMenuItem.WIDTH / 2;
		dragItem.targetY = ptrY - ModMenuItem.ICON / 2;

		var target:Int = boxAt(ptrX, ptrY);
		dragTarget = target;

		if (target < 0)
		{
			marker.visible = false;
			return;
		}

		var dst:ModMenuList = lists[target];
		var cam:FlxCamera = dst.cam;

		if (ptrY < cam.y + 30) dst.scrollBy(500 * elapsed);
		else if (ptrY > cam.y + cam.height - 30) dst.scrollBy(-500 * elapsed);

		dragIndex = Std.int(FlxMath.bound(dst.indexForY(ptrY), 0, dst.items.length));

		var markerY:Float = dst.slotScreenY(dragIndex) - (ModMenuList.STEP - ModMenuItem.ICON) / 2 - 2;
		marker.visible = markerY >= cam.y - 4 && markerY <= cam.y + cam.height + 4;
		marker.x = dst.slotScreenX();
		marker.y = markerY;
	}

	function drop():Void
	{
		mode = MODE_IDLE;
		marker.visible = false;

		var item:ModMenuItem = dragItem;
		dragItem = null;

		item.held = false;
		item.flying = false;
		item.rate = 22;

		// soltado fuera de los paneles: vuelve a su sitio
		if (dragTarget < 0)
		{
			item.toList(lists[dragFrom]);
			return;
		}

		var from:Int = dragFrom;
		var to:Int = dragTarget;
		var src:ModMenuList = lists[from];
		var dst:ModMenuList = lists[to];

		var oldIndex:Int = src.items.indexOf(item);
		var index:Int = dragIndex;

		src.remove(item);
		if (from == to && index > oldIndex) index--;
		index = Std.int(FlxMath.bound(index, 0, dst.items.length));
		dst.insert(item, index);
		item.entry.enabled = to == 1;

		// pasa de coordenadas de pantalla a las de la lista destino y se acomoda solo
		item.toList(dst);

		if (from != to || index != oldIndex)
		{
			item.flashBackground();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}
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
			for (item in lists[i].items)
			{
				if (fileStr.length > 0) fileStr += '\n';
				fileStr += item.entry.folder + '|' + (i == 1 ? '1' : '0');
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
		if (ambience != null) ambience.stop();
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
		for (list in lists)
			for (item in list.items)
				if (item.entry.mustRestart && item.entry.enabled != item.entry.startEnabled) restart = true;

		if (restart)
		{
			TitleState.initialized = false;
			TitleState.closedState = false;
			FlxG.sound.music.fadeOut(0.3);
			FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
		}
		else MusicBeatState.switchState(new MainMenuState());
	}

	override function destroy()
	{
		if (ambience != null) ambience.stop();
		super.destroy();
	}
}
