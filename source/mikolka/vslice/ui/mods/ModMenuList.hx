package mikolka.vslice.ui.mods;

import backend.Mods;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.util.FlxColor;
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
	public var isBase:Bool = false;

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

	public static function base():ModEntry
	{
		var entry:ModEntry = new ModEntry('__base_game__', true);
		entry.name = 'Base Game';
		entry.desc = 'Default game content';
		entry.isBase = true;
		return entry;
	}
}

class ModMenuStyle
{
	public static var customFont(get, never):Bool;
	public static var fontPath(get, never):String;

	static var resolved:Bool = false;
	static var hasCustom:Bool = false;
	static var path:String = '';

	static function resolve():Void
	{
		if (resolved) return;
		resolved = true;
		var custom:String = Paths.font('FunkinLingLong.otf');
		if (NativeFileSystem.exists(custom))
		{
			hasCustom = true;
			path = custom;
		}
		else
		{
			hasCustom = false;
			path = Paths.font('vcr.ttf');
		}
	}

	static function get_customFont():Bool
	{
		resolve();
		return hasCustom;
	}

	static function get_fontPath():String
	{
		resolve();
		return path;
	}

	public static function fit(text:String, maxChars:Int):String
	{
		if (text == null) return '';
		text = text.split('\n').join(' ').split('\r').join(' ').trim();
		if (text.length <= maxChars) return text;
		return text.substr(0, maxChars - 3) + '...';
	}
}

class ModMenuItem extends FlxSpriteGroup
{
	public static inline var WIDTH:Int = 326;
	public static inline var ICON:Int = 96;
	public static inline var TEXT_W:Int = 216;

	public var entry:ModEntry;
	public var owner:ModMenuList;
	public var selected(default, set):Bool = false;
	public var held:Bool = false;
	public var flying:Bool = false;
	public var screenSpace:Bool = false;
	public var targetX:Float = 0;
	public var targetY:Float = 0;
	public var rate:Float = 22;
	public var fade:Float = 1;

	var bg:FlxSprite;
	var icon:FlxSprite;
	var title:FlxText;
	var desc:FlxText;
	var flashT:Float = -1;

	public function new(entry:ModEntry)
	{
		super(0, 0);
		this.entry = entry;

		bg = new FlxSprite(0, 0).makeGraphic(WIDTH, ICON, FlxColor.WHITE);
		bg.alpha = 0;
		add(bg);

		loadIcon();
		add(icon);

		var big:Bool = ModMenuStyle.customFont;
		var titleSize:Int = big ? 30 : 22;
		var descSize:Int = big ? 20 : 14;

		title = new FlxText(ICON + 8, 2, TEXT_W, ModMenuStyle.fit(entry.name, big ? 22 : 15), titleSize);
		title.setFormat(ModMenuStyle.fontPath, titleSize, FlxColor.WHITE, LEFT);
		title.wordWrap = false;
		add(title);

		desc = new FlxText(ICON + 8, 2 + titleSize * 1.3 + 4, TEXT_W, ModMenuStyle.fit(entry.desc, big ? 54 : 40), descSize);
		desc.setFormat(ModMenuStyle.fontPath, descSize, FlxColor.WHITE, LEFT);
		desc.fieldHeight = descSize * 2.5;
		desc.alpha = 0.7;
		add(desc);
	}

	function loadIcon():Void
	{
		icon = new FlxSprite(0, 0);
		icon.antialiasing = ClientPrefs.data.antialiasing;

		var loaded:Bool = false;

		if (entry.isBase)
		{
			var baseGraphic = Paths.image('vmods/base-icon');
			if (baseGraphic != null)
			{
				icon.loadGraphic(baseGraphic);
				loaded = true;
			}
		}
		else
		{
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
				var total:Int = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
				if (total > 1)
				{
					icon.animation.add('icon', [for (i in 0...total) i], entry.iconFps);
					icon.animation.play('icon');
				}
				loaded = true;
			}
			else
			{
				var fallback = Paths.image('vmods/fallback-icon');
				if (fallback == null) fallback = Paths.image('unknownMod');
				if (fallback != null)
				{
					icon.loadGraphic(fallback);
					loaded = true;
				}
			}
		}

		if (!loaded) icon.makeGraphic(ICON, ICON, 0xFF3A393E);

		icon.setGraphicSize(ICON, ICON);
		icon.updateHitbox();
	}

	function set_selected(value:Bool):Bool
	{
		selected = value;
		return value;
	}

	public function flashBackground():Void
	{
		flashT = 0;
	}

	public function snapTo(px:Float, py:Float):Void
	{
		targetX = px;
		targetY = py;
		setPosition(px, py);
	}

	public function toScreen(list:ModMenuList, topCam:FlxCamera):Void
	{
		if (screenSpace) return;
		setPosition(x + list.cam.x, y + list.cam.y);
		cameras = [topCam];
		screenSpace = true;
	}

	public function toList(list:ModMenuList):Void
	{
		if (!screenSpace) return;
		setPosition(x - list.cam.x, y - list.cam.y);
		cameras = [list.cam];
		screenSpace = false;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var k:Float = 1 - Math.exp(-rate * elapsed);
		var nx:Float = x + (targetX - x) * k;
		var ny:Float = y + (targetY - y) * k;
		if (Math.abs(targetX - nx) < 0.3) nx = targetX;
		if (Math.abs(targetY - ny) < 0.3) ny = targetY;
		if (nx != x || ny != y) setPosition(nx, ny);

		var bgTarget:Float = selected || held ? 0.25 : 0;
		var bgAlpha:Float = bgTarget;
		if (flashT >= 0)
		{
			flashT += elapsed;
			var t:Float = Math.min(1, flashT / 0.5);
			bgAlpha = FlxMath.lerp(1, bgTarget, 1 - Math.pow(1 - t, 5));
			if (t >= 1) flashT = -1;
		}

		bg.alpha = bgAlpha * fade;
		icon.alpha = fade;
		title.alpha = fade;
		desc.alpha = 0.7 * fade;
	}
}

class ModMenuList
{
	public static inline var STEP:Float = 112;
	public static inline var ITEM_X:Float = 40;

	public var items:Array<ModMenuItem> = [];
	public var cam:FlxCamera;
	public var rect:FlxRect;
	public var scroll:Float = 0;
	public var targetScroll:Float = 0;
	public var selIndex:Int = -1;
	public var snap:Bool = false;
	public var viewH:Float;
	public var track:FlxSprite;
	public var thumb:FlxSprite;

	public function new(rect:FlxRect, cam:FlxCamera)
	{
		this.rect = rect;
		this.cam = cam;
		viewH = cam.height;

		track = new FlxSprite().makeGraphic(1, 1, 0xFF3A393E);
		track.alpha = 0.6;
		track.origin.set(0, 0);
		track.visible = false;

		thumb = new FlxSprite().makeGraphic(1, 1, 0xFF57565A);
		thumb.alpha = 0.95;
		thumb.origin.set(0, 0);
		thumb.visible = false;
	}

	public function minScroll():Float
	{
		var content:Float = items.length * STEP - 16;
		return Math.min(0, viewH - content - 8);
	}

	public function clamp():Void
	{
		targetScroll = FlxMath.bound(targetScroll, minScroll(), 0);
	}

	public function scrollBy(delta:Float):Void
	{
		targetScroll += delta;
		clamp();
	}

	public function ensureVisible(index:Int):Void
	{
		if (index < 0 || index >= items.length) return;
		var top:Float = index * STEP + targetScroll;
		if (top < 0) targetScroll -= top;
		else if (top + ModMenuItem.ICON > viewH) targetScroll -= top + ModMenuItem.ICON - viewH + 8;
		clamp();
	}

	public function insert(item:ModMenuItem, index:Int):Void
	{
		if (index < 0 || index > items.length) index = items.length;
		items.insert(index, item);
		item.owner = this;
		if (selIndex >= index && selIndex >= 0) selIndex++;
		clamp();
	}

	public function remove(item:ModMenuItem):Void
	{
		var index:Int = items.indexOf(item);
		if (index < 0) return;
		items.splice(index, 1);
		if (selIndex == index)
		{
			item.selected = false;
			selIndex = -1;
		}
		else if (selIndex > index) selIndex--;
		clamp();
	}

	public function select(index:Int):Void
	{
		for (item in items) item.selected = false;
		if (index < 0 || index >= items.length)
		{
			selIndex = -1;
			return;
		}
		selIndex = index;
		items[index].selected = true;
		ensureVisible(index);
	}

	public function deselect():Void
	{
		select(-1);
	}

	public function selectedItem():ModMenuItem
	{
		if (selIndex < 0 || selIndex >= items.length) return null;
		return items[selIndex];
	}

	public function slotScreenX():Float
	{
		return cam.x + ITEM_X;
	}

	public function slotScreenY(index:Int):Float
	{
		return cam.y + index * STEP + targetScroll;
	}

	public function containsBox(px:Float, py:Float):Bool
	{
		return px >= rect.x && px <= rect.x + rect.width && py >= rect.y && py <= rect.y + rect.height;
	}

	public function containsView(px:Float, py:Float):Bool
	{
		return px >= cam.x && px <= cam.x + cam.width && py >= cam.y && py <= cam.y + cam.height;
	}

	public function itemAt(px:Float, py:Float):ModMenuItem
	{
		if (!containsView(px, py)) return null;
		for (item in items)
		{
			if (item.flying || item.held) continue;
			var ix:Float = cam.x + item.x;
			var iy:Float = cam.y + item.y;
			if (px >= ix && px <= ix + ModMenuItem.WIDTH && py >= iy && py <= iy + ModMenuItem.ICON) return item;
		}
		return null;
	}

	public function indexForY(py:Float):Int
	{
		return Math.round((py - cam.y - targetScroll - ModMenuItem.ICON / 2) / STEP);
	}

	public function update(elapsed:Float):Void
	{
		if (Math.abs(targetScroll - scroll) > 0.2)
		{
			if (snap) scroll = targetScroll;
			else scroll += (targetScroll - scroll) * (1 - Math.exp(-16 * elapsed));
		}
		else scroll = targetScroll;

		for (i in 0...items.length)
		{
			var item:ModMenuItem = items[i];
			if (item.flying || item.held) continue;
			item.targetX = ITEM_X;
			item.targetY = i * STEP + scroll;
			item.rate = snap ? 1000 : 22;
		}

		updateScrollbar();
	}

	function updateScrollbar():Void
	{
		var content:Float = items.length * STEP - 16;
		var need:Bool = content > viewH;
		track.visible = need;
		thumb.visible = need;
		if (!need) return;

		var top:Float = rect.y + 18;
		var bottom:Float = rect.y + rect.height - 15;
		var trackH:Float = Math.max(1, bottom - top);
		var thumbH:Float = Math.max(24, trackH * (viewH / content));
		if (thumbH > trackH) thumbH = trackH;

		var minS:Float = minScroll();
		var frac:Float = minS != 0 ? scroll / minS : 0;
		frac = FlxMath.bound(frac, 0, 1);

		track.setPosition(rect.x + 15, top);
		track.scale.set(10, trackH);
		thumb.setPosition(rect.x + 15, top + frac * (trackH - thumbH));
		thumb.scale.set(10, thumbH);
	}
}
