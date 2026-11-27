package backend;

import openfl.utils.AssetCache;
import flixel.util.FlxStringUtil;
import flixel.system.FlxAssets;
import openfl.media.Sound;
import openfl.Assets;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.system.System;
import flixel.graphics.FlxGraphic;
import flixel.FlxState;

typedef ImageLine =
{
	size:Int,
	text:String
};

@:access(openfl.display.BitmapData)
class CacheSystem
{
	/**
	 * A list of all cached graphics
	 */
	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	/**
	 * A list of cached sounds
	 */
	public static var currentTrackedSounds:Map<String, Sound> = [];

	/**
	 * define the locally tracked assets
	 * Those assets are used in the current context.
	**/
	public static var localTrackedAssets:Array<String> = [];

	/**
	 * A global list of assets to exclude from memory purges.
	 * Effectively, they stay loaded forever.
	 */
	public static var dumpExclusions:Array<String> = ['music/freakyMenu.${Paths.SOUND_EXT}'];

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	static var assetTicks:Map<String, Int> = [];
	static var assetContexts:Map<String, String> = [];
	static var useTick:Int = 0;
	static var assetFiles:Map<String, String> = [];
	static var fileKeys:Map<String, String> = [];

	static inline function currentContext():String
		return Mods.currentModDirectory + '|' + Paths.currentLevel;

	static inline function touch(key:String):Void
		assetTicks.set(key, ++useTick);

	static function retainBudget():Float
	{
		var megabytes:Float = switch (ClientPrefs.data.cacheReuse)
		{
			case '256 MB': 256;
			case '384 MB': 384;
			case '512 MB': 512;
			case '768 MB': 768;
			case '1 GB': 1024;
			default: 0;
		}
		return megabytes * 1048576;
	}

	static function graphicBytes(graphic:FlxGraphic):Float
	{
		if (graphic == null || graphic.bitmap == null)
			return 0;
		return graphic.bitmap.width * graphic.bitmap.height * 4;
	}

	static function soundBytes(sound:Sound):Float
	{
		if (sound == null)
			return 0;
		var length:Float = @:privateAccess (sound.__buffer != null && sound.__buffer.data != null ? sound.__buffer.data.length : 0);
		return length > 0 ? length : 2097152;
	}

	public static function isGraphicCached(key:String):Bool
		return currentTrackedAssets.exists(key) && (dumpExclusions.contains(key) || assetContexts.get(key) == currentContext());

	static function forgetKey(key:String):Void
	{
		assetContexts.remove(key);
		assetTicks.remove(key);
		var file:String = assetFiles.get(key);
		if (file != null)
		{
			assetFiles.remove(key);
			if (fileKeys.get(file) == key)
				fileKeys.remove(file);
		}
	}

	static function isGraphicShared(graphic:FlxGraphic):Bool
	{
		for (other in currentTrackedAssets)
			if (other == graphic)
				return true;
		return false;
	}

	static function discardGraphic(key:String):Void
	{
		var graphic:FlxGraphic = currentTrackedAssets.get(key);
		currentTrackedAssets.remove(key);
		forgetKey(key);
		if (graphic != null && !isGraphicShared(graphic))
			destroyGraphic(graphic);
	}

	public static function isSongAudio(key:String):Bool
		return key.indexOf('songs/') >= 0;

	/**
	 * Frees the audio of songs that are no longer being played.
	 */
	public static function releaseSongAudio():Void
	{
		var released:Array<String> = [];
		for (key in currentTrackedSounds.keys())
			if (isSongAudio(key) && !dumpExclusions.contains(key))
				released.push(key);

		for (key in released)
		{
			Assets.cache.clear(key);
			currentTrackedSounds.remove(key);
			assetTicks.remove(key);
			localTrackedAssets.remove(key);
		}
	}

	public static function onStateCreated(state:FlxState):Void
	{
		if (state is states.PlayState || state is states.LoadingState)
			return;
		releaseSongAudio();
	}

	/**
	 * Removes graphics and sounds not contained in the local context.
	 * Unless forced, the most recently used ones are kept (up to the
	 * configured budget) so they can be reused without loading them again.
	 */
	public static function clearUnusedMemory(force:Bool = false)
	{
		var budget:Float = force ? 0 : retainBudget();
		var candidates:Array<{key:String, tick:Int, bytes:Float, isSound:Bool}> = [];

		for (key => graphic in currentTrackedAssets)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
				candidates.push({key: key, tick: assetTicks.exists(key) ? assetTicks.get(key) : 0, bytes: graphicBytes(graphic), isSound: false});
		}
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
				candidates.push({key: key, tick: assetTicks.exists(key) ? assetTicks.get(key) : 0, bytes: soundBytes(asset), isSound: true});
		}

		if (budget > 0)
			candidates.sort((a, b) -> b.tick - a.tick);

		var retained:Float = 0;
		var evicted:Int = 0;
		for (candidate in candidates)
		{
			if (budget > 0 && retained + candidate.bytes <= budget)
			{
				retained += candidate.bytes;
				continue;
			}

			if (candidate.isSound)
			{
				Assets.cache.clear(candidate.key);
				currentTrackedSounds.remove(candidate.key);
				assetTicks.remove(candidate.key);
			}
			else
				discardGraphic(candidate.key);
			evicted++;
		}

		#if cpp
		if (evicted > 0)
			cpp.vm.Gc.compact();
		#end
	}

	#if debug
	public static function cacheStatus():String
	{
		var str = new StringBuf();
		str.add('-- Cache dump start --');
		str.add("\n");
		str.add('( openfl caches are ${openfl.utils.Assets.cache.enabled})');
		str.add("\n");
		var totalMemory = 0;

		str.add("-- Managed bitmaps --");
		str.add("\n");
		var entries:Array<ImageLine> = [];
		@:privateAccess
		for (key => texture in FlxG.bitmap._cache)
		{
			var inStored = currentTrackedAssets.exists(key) ? "S" : "-";
			var inLocal = localTrackedAssets.contains(key) ? "L" : "-";
			var memory = texture?.bitmap?.image?.data?.byteLength ?? 0;
			entries.push({
				size: memory,
				text: '[ $inStored $inLocal ](${FlxStringUtil.formatBytes(memory)}) $key'
			});
			totalMemory += memory;
		}
		entries.sort((x, y) -> cast y.size - x.size);
		for (entry in entries)
		{
			str.add(entry.text);
			str.add("\n");
		}
		str.add('Total: ${FlxStringUtil.formatBytes(totalMemory)}');
		str.add("\n");

		str.add("-- Managed sounds --");
		str.add("\n");
		totalMemory = 0;
		@:privateAccess
		for (key => snd in currentTrackedSounds)
		{
			var inLocal = localTrackedAssets.contains(key) ? "L" : "-";
			var memory = snd.bytesLoaded;
			str.add('[ $inLocal ](${FlxStringUtil.formatBytes(memory)}}/${FlxStringUtil.formatBytes(snd.bytesTotal)}) $key');
			str.add("\n");
			totalMemory += memory;
		}
		str.add('Total: ${FlxStringUtil.formatBytes(totalMemory)}');
		str.add("\n");

		str.add("-- OPENFL sounds --");
		str.add("\n");
		totalMemory = 0;
		@:privateAccess
		for (key => snd in currentTrackedSounds)
		{
			var memory = snd.__buffer.data.length;
			str.add(' (${FlxStringUtil.formatBytes(memory)}) $key');
			str.add("\n");
			totalMemory += memory;
		}
		str.add('Total: ${FlxStringUtil.formatBytes(totalMemory)}');
		str.add("\n");

		str.add("-- END --");
		return str.toString();
	}
	#end

	/**
	 * Clears up internal remnants of graphics not cached by this system.
	 * It also clears the current context.
	 * 
	 * This means that the next ``clearUnusedMemory`` call will purge them
	 * (unless you load them from cache before that)
	 */
	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key) && !dumpExclusions.contains(key)){

				destroyGraphic(FlxG.bitmap.get(key));
				
			}
		}

		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function loadBitmap(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		var file:String = null;
		if (currentTrackedAssets.exists(key))
		{
			if (isGraphicCached(key))
			{
				localTrackedAssets.push(key);
				touch(key);
				return currentTrackedAssets.get(key);
			}

			file = resolveTexturePath(key, parentFolder);
			if (file != null && assetFiles.get(key) == file)
			{
				assetContexts.set(key, currentContext());
				localTrackedAssets.push(key);
				touch(key);
				return currentTrackedAssets.get(key);
			}
			discardGraphic(key);
		}

		if (file == null)
			file = resolveTexturePath(key, parentFolder);

		if (file != null)
		{
			var sibling:String = fileKeys.get(file);
			if (sibling != null && sibling != key && currentTrackedAssets.exists(sibling))
			{
				var shared:FlxGraphic = currentTrackedAssets.get(sibling);
				if (shared != null && shared.bitmap != null)
				{
					currentTrackedAssets.set(key, shared);
					assetContexts.set(key, currentContext());
					assetFiles.set(key, file);
					localTrackedAssets.push(key);
					localTrackedAssets.push(sibling);
					touch(key);
					touch(sibling);
					return shared;
				}
			}
		}

		var bitmap = __loadBitmap(file);
		return cacheBitmap(key, bitmap, allowGPU, file);
	}

	public static function cacheBitmap(key:String, bitmap:BitmapData, ?allowGPU:Bool = true, ?file:String = null):FlxGraphic
	{
		if (bitmap == null)
			return null;
		if (currentTrackedAssets.exists(key))
		{
			if (isGraphicCached(key))
			{
				localTrackedAssets.push(key);
				touch(key);
				return currentTrackedAssets.get(key);
			}
			discardGraphic(key);
		}
		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap?.image != null)
		{
			bitmap.lock(); // This does nothing on cpp
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			#if ATSC_SUPPORT
			if (!Std.isOfType(bitmap.__texture, openfl.display3D.textures.ASTCTexture))
			{
			#end

				bitmap.getSurface();
				bitmap.disposeImage();
				bitmap.image.data = null;
				bitmap.image = null;
				bitmap.readable = true;

			#if ATSC_SUPPORT
			}
			#end
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		assetContexts.set(key, currentContext());
		if (file != null)
		{
			assetFiles.set(key, file);
			fileKeys.set(file, key);
		}
		touch(key);
		localTrackedAssets.push(key);
		return graph;
	}

	/**
		 * Loads and caches a sound from the given path.
		 * @param file 
		 * @param requestName 
		 * @return Sound
		 */
	public static function loadSound(file:String, ?beepOnNull:Bool = true, requestName:String = ""):Sound
	{
		// trace('precaching sound: $file');
		if (!currentTrackedSounds.exists(file))
		{
			var isTrackingSound = false;
			var sound = NativeFileSystem.getSound(file);
			if (sound != null)
			{
				currentTrackedSounds.set(file, sound);
				isTrackingSound = true;
			}
			else if (beepOnNull && !isTrackingSound)
			{
				trace('SOUND NOT FOUND: $requestName');
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		touch(file);
		return currentTrackedSounds.get(file);
	}

	/**
		 * I believe this ose is used to clear graphics cache while preserving graphics used by
		 * the current state.
		 */
	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if (grp != null)
				{
					// trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if (gfx != null)
				{
					protectedGfx.push(gfx);
					// trace('gfx added to the list successfully!');
				}
			}
			// catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if (FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		var destroyedGfx:Array<FlxGraphic> = [];
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if (!protectedGfx.contains(graphic))
				{
					if (!destroyedGfx.contains(graphic))
					{
						destroyedGfx.push(graphic);
						destroyGraphic(graphic); // get rid of the graphic
					}
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					forgetKey(key);
					// trace('deleted $key');
				}
			}
		}
	}

	/**
		 * Destroys a given graphic. Make sure to dereference it as well to avoid any issues.
		 * @param graphic 
		 */
	private inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
		graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	private inline static function resolveTexturePath(key:String, ?parentFolder:String = null):String
	{
		// A ton of stuff uses .png internally, so we fake it for ATSC
		return getTexturePath(Path.withoutExtension(key), parentFolder);
	}

	private inline static function __loadBitmap(file:String):BitmapData
	{
		var bitmap = NativeFileSystem.getBitmap(file);
		if (bitmap == null)
		{
			trace('Bitmap not found: $file');
		}

		return bitmap;
	}

	/**
		 * Finds a graphic in the given path. Can give either PNG or ASTC file path.
		 * @param file 
		 * @param parentfolder 
		 * @return String
		 */
	private static function getTexturePath(file:String, ?parentfolder:String):String
	{
		function astcGetSharedPath(path:String)
		{
			#if ATSC_SUPPORT
			if (Native.isASTCSupported())
			{
				var assetPath = Paths.getSharedPath('$path.astc');
				if (NativeFileSystem.exists(assetPath))
					return assetPath;
			}
			#end
			return Paths.getSharedPath('$path.png');
		}

		function astcGetFolderPath(file:String, folder:String)
		{
			#if ATSC_SUPPORT
			if (Native.isASTCSupported())
			{
				var assetPath = Paths.getFolderPath('$file.astc', folder);
				if (NativeFileSystem.exists(assetPath))
					return assetPath;
			}
			#end
			return Paths.getFolderPath('$file.png', folder);
		}
		#if MODS_ALLOWED
		
		function astcModFolders(path:String)
		{
			#if ATSC_SUPPORT
			if (Native.isASTCSupported())
			{
				var assetPath = Paths.modFolders('$path.astc');
				if (NativeFileSystem.exists(assetPath))
					return assetPath;
			}
			#end
			return Paths.modFolders('$path.png');
		}

		var customFile:String = file;
		if (parentfolder != null)
			customFile = '$parentfolder/$file';

		// Load from level folder in a mod
		if (Paths.currentLevel != null && Paths.currentLevel != 'shared')
		{
			var levelPath = astcModFolders('${Paths.currentLevel}/$customFile');
			if (NativeFileSystem.exists(levelPath))
				return levelPath;
		}

		var modded:String = astcModFolders(customFile);
		if (NativeFileSystem.exists(modded))
			return modded;
		#end
		if (parentfolder == "mobile")
			return astcGetSharedPath('mobile/$file');

		if (parentfolder != null)
			return astcGetFolderPath(file, parentfolder);

		// Load from a level folder
		if (Paths.currentLevel != null && Paths.currentLevel != 'shared')
		{
			var levelPath = astcGetFolderPath(file, Paths.currentLevel);
			if (NativeFileSystem.exists(levelPath))
				return levelPath;
		}
		return astcGetSharedPath(file);
	}
}
