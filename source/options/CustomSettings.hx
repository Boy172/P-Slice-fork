package options;

import options.Option;
import options.Option.OptionType;
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

using StringTools;

typedef CustomSettingDef =
{
	var section:String;
	var name:String;
	var description:String;
	var key:String;
	var type:OptionType;
	var value:Dynamic;
	var options:Array<String>;
	var min:Dynamic;
	var max:Dynamic;
	var step:Dynamic;
	var decimals:Dynamic;
	var scroll:Dynamic;
	var format:String;
}

typedef CustomSection =
{
	var id:String;
	var title:String;
}

class CustomSettings
{
	public static var sections:Array<CustomSection> = [];
	public static var defs:Array<CustomSettingDef> = [];

	static var loaded:Bool = false;
	static var loading:Bool = false;

	static function builtinClass(section:String):String
	{
		if (section == null) return null;
		return switch (section.toLowerCase().trim())
		{
			case 'graphics': 'options.GraphicsSettingsSubState';
			case 'visuals': 'options.VisualsSettingsSubState';
			case 'gameplay': 'options.GameplaySettingsSubState';
			case 'p-slice options' | 'p-slice' | 'pslice': 'options.PSliceSubState';
			case 'v-slice options' | 'v-slice' | 'vslice': 'options.VSliceSubState';
			case 'mobile options' | 'mobile': 'mobile.options.MobileOptionsSubState';
			default: null;
		}
	}

	static function store():Map<String, Dynamic>
	{
		var saved:Map<String, Dynamic> = FlxG.save.data.customSettings;
		if (saved == null)
		{
			saved = new Map<String, Dynamic>();
			FlxG.save.data.customSettings = saved;
		}
		return saved;
	}

	public static function ensureLoaded():Void
	{
		if (!loaded && !loading) load();
	}

	public static function get(key:String, ?fallback:Dynamic):Dynamic
	{
		var saved:Map<String, Dynamic> = store();
		if (saved.exists(key)) return saved.get(key);
		ensureLoaded();
		for (def in defs)
			if (def.key == key) return def.value;
		return fallback;
	}

	public static function set(key:String, value:Dynamic, ?flush:Bool = false):Void
	{
		store().set(key, value);
		if (flush) FlxG.save.flush();
	}

	public static function addSection(id:String, ?title:String):Void
	{
		if (id == null || id.trim() == '') return;
		for (section in sections)
			if (section.id == id)
			{
				if (title != null && title.trim() != '') section.title = title;
				return;
			}
		sections.push({id: id, title: (title == null || title.trim() == '') ? id : title});
	}

	static function field(data:Dynamic, names:Array<String>):Dynamic
	{
		for (name in names)
		{
			var value:Dynamic = Reflect.field(data, name);
			if (value != null) return value;
		}
		return null;
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function textList(value:Dynamic):Array<String>
	{
		var result:Array<String> = [];
		if (value == null) return result;
		if (Std.isOfType(value, Array))
		{
			var items:Array<Dynamic> = cast value;
			for (item in items) result.push(Std.string(item).trim());
		}
		else
		{
			for (part in Std.string(value).split(',')) result.push(part.trim());
		}
		return result;
	}

	static function parseType(value:Dynamic):OptionType
	{
		var text:String = value == null ? 'bool' : Std.string(value).toLowerCase().trim();
		return switch (text)
		{
			case 'int' | 'integer' | 'number': INT;
			case 'float' | 'fl' | 'decimal': FLOAT;
			case 'percent': PERCENT;
			case 'string' | 'str' | 'list' | 'choice': STRING;
			default: BOOL;
		}
	}

	public static function addSetting(section:String, first:Dynamic, ?description:Dynamic, ?key:Dynamic, ?type:Dynamic, ?value:Dynamic, ?extra:Dynamic):Void
	{
		var data:Dynamic = null;
		if (first != null && !Std.isOfType(first, String))
			data = first;
		else
			data = {name: first, description: description, key: key, type: type, value: value, extra: extra};

		var name:String = Std.string(field(data, ['name', 'title']));
		if (name == 'null' || name.trim() == '') return;

		var saveKey:Dynamic = field(data, ['key', 'save', 'variable']);
		var settingKey:String = saveKey == null ? name.toLowerCase().trim().replace(' ', '_') : Std.string(saveKey);

		var kind:OptionType = parseType(field(data, ['type']));
		var extraList:Array<String> = textList(field(data, ['extra']));
		var list:Array<String> = textList(field(data, ['options', 'choices']));
		if (list.length == 0 && kind == STRING) list = extraList;
		if (kind == STRING && list.length == 0) list = ['Off', 'On'];

		var minValue:Float = 0;
		var maxValue:Float = 100;
		var stepValue:Float = kind == FLOAT ? 0.1 : 1;
		if (kind == PERCENT)
		{
			maxValue = 1;
			stepValue = 0.01;
		}
		if (kind == INT || kind == FLOAT)
		{
			if (extraList.length > 0) minValue = number(extraList[0], minValue);
			if (extraList.length > 1) maxValue = number(extraList[1], maxValue);
			if (extraList.length > 2) stepValue = number(extraList[2], stepValue);
		}
		minValue = number(field(data, ['min']), minValue);
		maxValue = number(field(data, ['max']), maxValue);
		stepValue = number(field(data, ['step']), stepValue);

		var rawValue:Dynamic = field(data, ['value', 'default']);
		var defaultValue:Dynamic = null;
		switch (kind)
		{
			case BOOL:
				defaultValue = rawValue == true || Std.string(rawValue).toLowerCase() == 'true';
			case INT:
				defaultValue = Std.int(number(rawValue, minValue));
			case FLOAT:
				defaultValue = number(rawValue, minValue);
			case PERCENT:
				defaultValue = number(rawValue, 1);
			default:
				defaultValue = rawValue == null ? list[0] : Std.string(rawValue);
		}

		var descriptionText:Dynamic = field(data, ['description', 'desc']);
		var formatText:Dynamic = field(data, ['format']);

		var def:CustomSettingDef = {
			section: section,
			name: name,
			description: descriptionText == null ? '' : Std.string(descriptionText),
			key: settingKey,
			type: kind,
			value: defaultValue,
			options: list,
			min: minValue,
			max: maxValue,
			step: stepValue,
			decimals: field(data, ['decimals']),
			scroll: field(data, ['scroll', 'scrollSpeed']),
			format: formatText == null ? null : Std.string(formatText)
		};

		if (builtinClass(section) == null) addSection(section);

		for (i in 0...defs.length)
			if (defs[i].key == settingKey && defs[i].section == section)
			{
				defs[i] = def;
				return;
			}
		defs.push(def);
	}

	static function build(def:CustomSettingDef):Option
	{
		var option:Option = new Option(def.name, def.description, def.key, def.type, def.options);
		option.defaultValue = def.value;

		if (def.type != BOOL && def.type != STRING)
		{
			option.minValue = def.min;
			option.maxValue = def.max;
			option.changeValue = def.step;
			if (def.decimals != null) option.decimals = Std.int(number(def.decimals, 1));
			else if (def.type == FLOAT) option.decimals = 2;
			if (def.scroll != null) option.scrollSpeed = number(def.scroll, option.scrollSpeed);
			else if (def.type != PERCENT) option.scrollSpeed = Math.max(1, (def.max - def.min) / 4);
		}
		if (def.format != null) option.displayFormat = def.format;

		var key:String = def.key;
		var fallback:Dynamic = def.value;
		@:privateAccess
		{
			option.getValue = function() return get(key, fallback);
			option.setValue = function(value:Dynamic)
			{
				set(key, value);
			}
		}

		if (def.type == STRING)
		{
			var index:Int = def.options.indexOf(Std.string(get(key, fallback)));
			if (index > -1) option.curOption = index;
		}
		return option;
	}

	public static function optionsFor(className:String):Array<Option>
	{
		ensureLoaded();
		var result:Array<Option> = [];
		for (def in defs)
			if (builtinClass(def.section) == className) result.push(build(def));
		return result;
	}

	public static function optionsForSection(id:String):Array<Option>
	{
		ensureLoaded();
		var result:Array<Option> = [];
		for (def in defs)
			if (def.section == id && builtinClass(def.section) == null) result.push(build(def));
		return result;
	}

	public static function visibleSections():Array<CustomSection>
	{
		ensureLoaded();
		var result:Array<CustomSection> = [];
		for (section in sections)
			for (def in defs)
				if (def.section == section.id)
				{
					result.push(section);
					break;
				}
		return result;
	}

	public static function load():Void
	{
		sections = [];
		defs = [];
		loaded = true;
		loading = true;

		try
		{
			var folders:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), 'custom_settings/');
			for (folder in folders)
			{
				if (!NativeFileSystem.isDirectory(folder)) continue;
				var files:Array<String> = NativeFileSystem.readDirectory(folder);
				files.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
				for (file in files)
					runScript(folder + file);
			}
		}
		catch (e:Dynamic)
		{
			trace('Custom settings failed to load: $e');
		}

		loading = false;
	}

	static function runScript(path:String):Void
	{
		try
		{
			#if HSCRIPT_ALLOWED
			if (path.endsWith('.hx'))
			{
				runHScript(path);
				return;
			}
			#end
			#if LUA_ALLOWED
			if (path.endsWith('.lua'))
				runLua(path);
			#end
		}
		catch (e:Dynamic)
		{
			trace('Error in settings script $path: $e');
		}
	}

	#if HSCRIPT_ALLOWED
	static function runHScript(path:String):Void
	{
		var script:HScript = new HScript(null, path, null, true);
		script.set('addSettingsSection', addSection);
		script.set('addSetting', addSetting);
		script.set('getCustomSetting', function(key:String, ?fallback:Dynamic) return get(key, fallback));
		script.set('setCustomSetting', function(key:String, value:Dynamic) set(key, value));
		script.execute();
		script.destroy();
	}
	#end

	#if LUA_ALLOWED
	static function runLua(path:String):Void
	{
		var state:State = LuaL.newstate();
		LuaL.openlibs(state);

		Lua_helper.add_callback(state, 'addSettingsSection', addSection);
		Lua_helper.add_callback(state, 'addSetting', addSetting);
		Lua_helper.add_callback(state, 'getCustomSetting', function(key:String, ?fallback:Dynamic) return get(key, fallback));
		Lua_helper.add_callback(state, 'setCustomSetting', function(key:String, value:Dynamic) set(key, value));

		var realName:String = NativeFileSystem.getPathLike(path);
		var result:Int = 0;
		if (realName != null)
			result = LuaL.dofile(state, realName);
		else
			result = LuaL.dostring(state, NativeFileSystem.getContent(path));

		if (result != 0)
			trace('Lua settings error in $path: ' + Lua.tostring(state, -1));

		Lua.close(state);
		for (name in ['addSettingsSection', 'addSetting', 'getCustomSetting', 'setCustomSetting'])
			Lua_helper.callbacks.remove(name);
	}
	#end
}
