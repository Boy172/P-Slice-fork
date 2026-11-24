package states.editors.content;

import haxe.io.Path;
import flixel.FlxSubState;

enum abstract BrowserMode(Int)
{
	var PICK_FILE;
	var PICK_DIRECTORY;
	var SAVE_FILE;
}

private class BrowserButton
{
	public var bg:FlxSprite;
	public var label:FlxText;
	public var action:Void->Void;

	public function new(x:Float, y:Float, width:Int, height:Int, text:String, color:Int, action:Void->Void, cam:FlxCamera, owner:FlxSubState)
	{
		this.action = action;

		bg = new FlxSprite(x, y).makeGraphic(width, height, color);
		bg.cameras = [cam];
		bg.scrollFactor.set();
		owner.add(bg);

		label = new FlxText(x, y + (height - 22) / 2, width, text, 20);
		label.alignment = CENTER;
		label.color = FlxColor.WHITE;
		label.cameras = [cam];
		label.scrollFactor.set();
		owner.add(label);
	}

	public function setText(text:String):Void
	{
		label.text = text;
	}

	public function hit(px:Float, py:Float):Bool
	{
		return px >= bg.x && px <= bg.x + bg.width && py >= bg.y && py <= bg.y + bg.height;
	}
}

class MobileFileBrowser extends FlxSubState
{
	static var lastDirectory:String = null;
	static inline var ROW_HEIGHT:Int = 46;
	static inline var HEADER_HEIGHT:Int = 124;
	static inline var FOOTER_HEIGHT:Int = 84;

	var mode:BrowserMode;
	var title:String;
	var extensions:Array<String>;
	var fileName:String;
	var onPick:String->Void;
	var onCancel:Void->Void;

	var cam:FlxCamera;
	var currentDir:String = '';
	var entries:Array<{name:String, isDir:Bool}> = [];
	var showAll:Bool = false;
	var scroll:Float = 0;
	var rowBgs:Array<FlxSprite> = [];
	var rowTexts:Array<FlxText> = [];
	var pathText:FlxText;
	var statusText:FlxText;
	var listTop:Float;
	var listHeight:Float;
	var buttons:Array<BrowserButton> = [];
	var confirmButton:BrowserButton;
	var allFilesButton:BrowserButton;

	var pressY:Float = 0;
	var startScroll:Float = 0;
	var dragging:Bool = false;
	var pressedInList:Bool = false;
	var pressedButton:BrowserButton = null;
	var finished:Bool = false;
	var overwriteArmed:String = null;

	public function new(mode:BrowserMode, title:String, extensions:Array<String>, ?fileName:String, onPick:String->Void, ?onCancel:Void->Void)
	{
		super();
		this.mode = mode;
		this.title = title;
		this.extensions = extensions == null ? [] : extensions;
		this.fileName = fileName == null ? '' : fileName;
		this.onPick = onPick;
		this.onCancel = onCancel;
	}

	override function create():Void
	{
		super.create();

		cam = new FlxCamera();
		cam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(cam, false);
		cameras = [cam];

		var W:Float = FlxG.width;
		var H:Float = FlxG.height;
		listTop = HEADER_HEIGHT;
		listHeight = H - HEADER_HEIGHT - FOOTER_HEIGHT;

		var backdrop:FlxSprite = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), 0xF0101018);
		backdrop.cameras = [cam];
		backdrop.scrollFactor.set();
		add(backdrop);

		var rowCount:Int = Math.ceil(listHeight / ROW_HEIGHT) + 1;
		for (i in 0...rowCount)
		{
			var rowBg:FlxSprite = new FlxSprite(20, 0).makeGraphic(Std.int(W - 40), ROW_HEIGHT - 3, 0xFF22222E);
			rowBg.cameras = [cam];
			rowBg.scrollFactor.set();
			rowBg.visible = false;
			add(rowBg);
			rowBgs.push(rowBg);

			var rowText:FlxText = new FlxText(36, 0, W - 72, '', 24);
			rowText.cameras = [cam];
			rowText.scrollFactor.set();
			rowText.visible = false;
			add(rowText);
			rowTexts.push(rowText);
		}

		var headerBg:FlxSprite = new FlxSprite().makeGraphic(Std.int(W), HEADER_HEIGHT, 0xFF15151F);
		headerBg.cameras = [cam];
		headerBg.scrollFactor.set();
		add(headerBg);

		var footerBg:FlxSprite = new FlxSprite(0, H - FOOTER_HEIGHT).makeGraphic(Std.int(W), FOOTER_HEIGHT, 0xFF15151F);
		footerBg.cameras = [cam];
		footerBg.scrollFactor.set();
		add(footerBg);

		var titleText:FlxText = new FlxText(20, 8, W - 40, title, 28);
		titleText.cameras = [cam];
		titleText.scrollFactor.set();
		add(titleText);

		pathText = new FlxText(20, 46, W - 40, '', 18);
		pathText.color = 0xFFAAAAFF;
		pathText.cameras = [cam];
		pathText.scrollFactor.set();
		add(pathText);

		statusText = new FlxText(20, H - FOOTER_HEIGHT - 26, W - 40, '', 18);
		statusText.color = FlxColor.YELLOW;
		statusText.cameras = [cam];
		statusText.scrollFactor.set();
		add(statusText);

		var shortcutX:Float = 20;
		var shortcutY:Float = 80;
		var addShortcut = function(name:String, dir:String):Void
		{
			if (dir == null) return;
			try
			{
				if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;
			}
			catch (e:Dynamic)
			{
				return;
			}

			var button:BrowserButton = new BrowserButton(shortcutX, shortcutY, 190, 36, name, 0xFF3A3A5A, function() navigate(dir), cam, this);
			buttons.push(button);
			shortcutX += 200;
		};

		var gameDir:String = normalize(StorageUtil.getStorageDirectory());
		addShortcut('Game folder', gameDir);
		var savesDir:String = gameDir + '/saves';
		try
		{
			if (!FileSystem.exists(savesDir)) FileSystem.createDirectory(savesDir);
		}
		catch (e:Dynamic) {}
		addShortcut('Saves', savesDir);
		addShortcut('Download', '/storage/emulated/0/Download');
		addShortcut('Storage', '/storage/emulated/0');

		if (mode == PICK_FILE)
		{
			allFilesButton = new BrowserButton(W - 210, shortcutY, 190, 36, 'All files: OFF', 0xFF5A3A3A, toggleAllFiles, cam, this);
			buttons.push(allFilesButton);
		}

		var footerY:Float = H - FOOTER_HEIGHT + 14;
		buttons.push(new BrowserButton(20, footerY, 200, 56, 'Up', 0xFF3A3A5A, goUp, cam, this));

		if (mode != PICK_FILE)
		{
			var confirmText:String = mode == SAVE_FILE ? 'Save here' : 'Select this folder';
			confirmButton = new BrowserButton(W / 2 - 150, footerY, 300, 56, confirmText, 0xFF2E7D32, confirm, cam, this);
			buttons.push(confirmButton);
		}

		buttons.push(new BrowserButton(W - 220, footerY, 200, 56, 'Cancel', 0xFF8E2A2A, cancel, cam, this));

		var start:String = lastDirectory;
		if (start == null || !isDirectory(start)) start = isDirectory(savesDir) && mode == SAVE_FILE ? savesDir : gameDir;
		navigate(start);
	}

	function normalize(path:String):String
	{
		if (path == null) return '/';
		path = path.replace('\\', '/');
		while (path.length > 1 && path.endsWith('/')) path = path.substr(0, path.length - 1);
		return path;
	}

	function isDirectory(path:String):Bool
	{
		try
		{
			return FileSystem.exists(path) && FileSystem.isDirectory(path);
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	function matchesExtension(name:String):Bool
	{
		if (showAll || extensions.length < 1) return true;
		var lower:String = name.toLowerCase();
		for (ext in extensions)
			if (lower.endsWith('.' + ext)) return true;
		return false;
	}

	function navigate(dir:String):Void
	{
		dir = normalize(dir);
		var listing:Array<String> = null;
		try
		{
			listing = FileSystem.readDirectory(dir);
		}
		catch (e:Dynamic)
		{
			statusText.text = 'Cannot open this folder.';
			return;
		}

		currentDir = dir;
		lastDirectory = dir;
		overwriteArmed = null;
		statusText.text = '';
		pathText.text = dir;

		var folders:Array<String> = [];
		var files:Array<String> = [];
		for (name in listing)
		{
			var full:String = (dir == '/' ? '' : dir) + '/' + name;
			if (isDirectory(full)) folders.push(name);
			else if (mode != PICK_DIRECTORY && matchesExtension(name)) files.push(name);
		}

		folders.sort(function(a:String, b:String):Int return a.toLowerCase() < b.toLowerCase() ? -1 : 1);
		files.sort(function(a:String, b:String):Int return a.toLowerCase() < b.toLowerCase() ? -1 : 1);

		entries = [];
		for (name in folders) entries.push({name: name, isDir: true});
		for (name in files) entries.push({name: name, isDir: false});

		scroll = 0;
		refreshRows();
	}

	function goUp():Void
	{
		if (currentDir == '/' || currentDir.length < 2) return;
		var parent:String = Path.directory(currentDir);
		if (parent == null || parent.length < 1) parent = '/';
		navigate(parent);
	}

	function toggleAllFiles():Void
	{
		showAll = !showAll;
		if (allFilesButton != null) allFilesButton.setText(showAll ? 'All files: ON' : 'All files: OFF');
		navigate(currentDir);
	}

	function maxScroll():Float
	{
		return Math.max(0, entries.length * ROW_HEIGHT - listHeight);
	}

	function refreshRows():Void
	{
		scroll = Math.max(0, Math.min(scroll, maxScroll()));
		var first:Int = Std.int(scroll / ROW_HEIGHT);
		var shift:Float = scroll - first * ROW_HEIGHT;

		for (i in 0...rowBgs.length)
		{
			var index:Int = first + i;
			var rowBg:FlxSprite = rowBgs[i];
			var rowText:FlxText = rowTexts[i];

			if (index >= entries.length)
			{
				rowBg.visible = false;
				rowText.visible = false;
				continue;
			}

			var entry = entries[index];
			var y:Float = listTop + i * ROW_HEIGHT - shift;
			rowBg.y = y;
			rowText.y = y + 9;
			rowBg.visible = true;
			rowText.visible = true;
			rowBg.color = (index % 2 == 0) ? 0xFFFFFFFF : 0xFFC8C8D8;
			rowText.text = entry.isDir ? '[ ] ' + entry.name : entry.name;
			rowText.color = entry.isDir ? 0xFFFFD54F : FlxColor.WHITE;
		}

		if (entries.length == 0 && statusText != null && statusText.text == '')
			statusText.text = mode == PICK_FILE ? 'No matching files here.' : 'Empty folder.';
	}

	function inList(px:Float, py:Float):Bool
	{
		return py >= listTop && py <= listTop + listHeight;
	}

	function buttonAt(px:Float, py:Float):BrowserButton
	{
		for (button in buttons)
			if (button.hit(px, py)) return button;
		return null;
	}

	function onEntry(index:Int):Void
	{
		if (index < 0 || index >= entries.length) return;

		var entry = entries[index];
		var full:String = (currentDir == '/' ? '' : currentDir) + '/' + entry.name;
		if (entry.isDir)
		{
			navigate(full);
			return;
		}

		if (mode == PICK_FILE) finish(full);
		else if (mode == SAVE_FILE)
		{
			fileName = entry.name;
			overwriteArmed = null;
			statusText.text = 'File name: $fileName';
		}
	}

	function confirm():Void
	{
		if (mode == PICK_DIRECTORY)
		{
			finish(currentDir);
			return;
		}

		if (mode == SAVE_FILE)
		{
			var full:String = (currentDir == '/' ? '' : currentDir) + '/' + fileName;
			var exists:Bool = false;
			try
			{
				exists = FileSystem.exists(full);
			}
			catch (e:Dynamic) {}

			if (exists && overwriteArmed != full)
			{
				overwriteArmed = full;
				statusText.text = '"$fileName" already exists. Press again to overwrite.';
				return;
			}

			finish(full);
		}
	}

	function cancel():Void
	{
		if (finished) return;
		finished = true;
		close();
		new FlxTimer().start(0.1, function(_) if (onCancel != null) onCancel());
	}

	function finish(path:String):Void
	{
		if (finished) return;
		finished = true;
		close();
		new FlxTimer().start(0.1, function(_) if (onPick != null) onPick(path));
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (finished) return;

		if (FlxG.keys.justPressed.ESCAPE #if android || FlxG.android.justReleased.BACK #end)
		{
			cancel();
			return;
		}

		var mx:Float = FlxG.mouse.screenX;
		var my:Float = FlxG.mouse.screenY;

		if (FlxG.mouse.justPressed)
		{
			pressY = my;
			startScroll = scroll;
			dragging = false;
			pressedButton = buttonAt(mx, my);
			pressedInList = pressedButton == null && inList(mx, my);
		}
		else if (FlxG.mouse.pressed && pressedInList)
		{
			var delta:Float = my - pressY;
			if (!dragging && Math.abs(delta) > 14) dragging = true;
			if (dragging)
			{
				scroll = startScroll - delta;
				refreshRows();
			}
		}

		if (FlxG.mouse.wheel != 0)
		{
			scroll -= FlxG.mouse.wheel * ROW_HEIGHT;
			refreshRows();
		}

		if (FlxG.mouse.justReleased)
		{
			if (pressedButton != null)
			{
				if (buttonAt(mx, my) == pressedButton) pressedButton.action();
			}
			else if (pressedInList && !dragging && inList(mx, my))
			{
				var index:Int = Std.int((scroll + my - listTop) / ROW_HEIGHT);
				onEntry(index);
			}

			pressedButton = null;
			pressedInList = false;
			dragging = false;
		}
	}

	override function destroy():Void
	{
		if (cam != null)
		{
			if (FlxG.cameras.list.contains(cam)) FlxG.cameras.remove(cam);
			cam = null;
		}
		super.destroy();
	}
}
