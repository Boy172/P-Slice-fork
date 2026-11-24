package states.editors.content;

import haxe.io.Path;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;

import haxe.Exception;
#if sys
import sys.io.File;
#end
import lime.ui.FileDialog;
import lime.ui.FileDialogFilter;
import openfl.Lib;

import flixel.FlxBasic;
import StringTools;

enum abstract FileDialogType(Int)
{
	var OPEN;
	var SAVE;
	var OPEN_DIRECTORY;
}

//Currently only supports OPEN and SAVE, might change that in the future, who knows
class FileDialogHandler extends FlxBasic
{
	var _fileRef:FileReferenceCustom;
	var _dialogMode:FileDialogType = OPEN;
	public function new()
	{
		_fileRef = new FileReferenceCustom();
		_fileRef.addEventListener(Event.CANCEL, onCancelFn);
		_fileRef.addEventListener(IOErrorEvent.IO_ERROR, onErrorFn);

		super();
	}

	// callbacks
	public var onComplete:Void->Void;
	public var onCancel:Void->Void;
	public var onError:Void->Void;

	var _currentEvent:openfl.events.Event->Void;

	public function save(?fileName:String = '', ?dataToSave:String = '', ?onComplete:Void->Void, ?onCancel:Void->Void, ?onError:Void->Void)
	{
		if(!completed)
		{
			throw new Exception('You must finish previous operation before starting a new one.');
		}

		this._dialogMode = SAVE;
		_startUp(onComplete, onCancel, onError);

		#if mobile
		mobileSave(fileName, dataToSave);
		return;
		#end

		removeEvents();
		_currentEvent = onSaveComplete;
		_fileRef.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, _currentEvent);
		_fileRef.save(dataToSave, fileName);
	}

	public function open(?defaultName:String = null, ?title:String = null, ?filter:Array<FileFilter> = null, ?onComplete:Void->Void, ?onCancel:Void->Void, ?onError:Void->Void)
	{
		if(!completed)
		{
			throw new Exception('You must finish previous operation before starting a new one.');
		}

		this._dialogMode = OPEN;
		_startUp(onComplete, onCancel, onError);
		if(filter == null) filter = [new FileFilter('JSON', 'json')];
		#if mac
		filter = [];
		#end

		#if mobile
		mobileOpen(title, filter);
		return;
		#end

		removeEvents();
		_currentEvent = onLoadComplete;
		_fileRef.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, _currentEvent);
		_fileRef.browseEx(OPEN, defaultName, title, filter);
	}

	public function openDirectory(?title:String = null, ?onComplete:Void->Void, ?onCancel:Void->Void, ?onError:Void->Void)
	{
		if(!completed)
		{
			throw new Exception('You must finish previous operation before starting a new one.');
		}

		this._dialogMode = OPEN_DIRECTORY;
		_startUp(onComplete, onCancel, onError);

		#if mobile
		mobileDirectory(title);
		return;
		#end

		removeEvents();
		_currentEvent = onLoadDirectoryComplete;
		_fileRef.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, _currentEvent);
		_fileRef.browseEx(OPEN_DIRECTORY, null, title);
	}

	public var data:String;
	public var path:String;
	public var completed:Bool = true;

	#if mobile
	function mobileCancelled():Void
	{
		this.completed = true;
		if(onCancel != null) onCancel();
	}

	function mobileFailed():Void
	{
		this.completed = true;
		if(onError != null) onError();
	}

	function mobileExtensions(filter:Array<FileFilter>):Array<String>
	{
		var result:Array<String> = [];
		if(filter == null) return result;

		for (item in filter)
		{
			if(item == null || item.extension == null) continue;
			for (raw in item.extension.split(';'))
			{
				var ext:String = raw.trim().toLowerCase();
				if(ext.startsWith('*.')) ext = ext.substr(2);
				else if(ext.startsWith('.')) ext = ext.substr(1);
				if(ext.length > 0 && ext != '*') result.push(ext);
			}
		}
		return result;
	}

	function mobileOpen(title:String, filter:Array<FileFilter>):Void
	{
		var browser:MobileFileBrowser = new MobileFileBrowser(PICK_FILE, title == null ? 'Select a file' : title, mobileExtensions(filter), null,
			function(picked:String)
			{
				this.path = picked;
				try
				{
					this.data = File.getContent(picked);
				}
				catch(e:Dynamic)
				{
					trace('Failed to read: $picked ($e)');
					mobileFailed();
					return;
				}

				this.completed = true;
				trace('Loaded file from: $path');
				if(onComplete != null) onComplete();
			},
			mobileCancelled);
		FlxG.state.openSubState(browser);
	}

	function mobileDirectory(title:String):Void
	{
		var browser:MobileFileBrowser = new MobileFileBrowser(PICK_DIRECTORY, title == null ? 'Select a folder' : title, null, null,
			function(picked:String)
			{
				this.path = picked;
				this.completed = true;
				trace('Loaded directory: $path');
				if(onComplete != null) onComplete();
			},
			mobileCancelled);
		FlxG.state.openSubState(browser);
	}

	function mobileSave(fileName:String, dataToSave:String):Void
	{
		var browser:MobileFileBrowser = new MobileFileBrowser(SAVE_FILE, 'Save "$fileName"', null, fileName,
			function(picked:String)
			{
				try
				{
					File.saveContent(picked, dataToSave);
				}
				catch(e:Dynamic)
				{
					trace('Failed to save: $picked ($e)');
					mobileFailed();
					return;
				}

				this.path = picked;
				this.completed = true;
				trace('Saved file to: $path');
				if(onComplete != null) onComplete();
			},
			mobileCancelled);
		FlxG.state.openSubState(browser);
	}
	#end
	function onSaveComplete(_)
	{
		@:privateAccess
		this.path = _fileRef._trackSavedPath;
		this.completed = true;
		trace('Saved file to: $path');

		removeEvents();
		this.completed = true;
		if(onComplete != null) onComplete();
	}

	function onLoadComplete(_)
	{
		@:privateAccess
		this.path = _fileRef.__path;
		_fileRef.load();
		this.data = _fileRef.data.toString(); //TODO Test this File.getContent(this.path);
		this.completed = true;
		trace('Loaded file from: $path');

		removeEvents();
		this.completed = true;
		if(onComplete != null)
			onComplete();
	}

	function onLoadDirectoryComplete(_)
	{
		@:privateAccess
		this.path = _fileRef.__path;
		this.completed = true;
		trace('Loaded directory: $path');

		removeEvents();
		this.completed = true;
		if(onComplete != null)
			onComplete();
	}

	function onCancelFn(_)
	{
		removeEvents();
		this.completed = true;
		if(onCancel != null) onCancel();
	}

	function onErrorFn(_)
	{
		removeEvents();
		this.completed = true;
		if(onError != null) onError();
	}

	function _startUp(onComplete:Void->Void, onCancel:Void->Void, onError:Void->Void)
	{
		this.onComplete = onComplete;
		this.onCancel = onCancel;
		this.onError = onError;
		this.completed = false;

		this.data = null;
		this.path = null;
	}

	function removeEvents()
	{
		if(_currentEvent == null) return;
		
		_fileRef.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, _currentEvent);
		_currentEvent = null;
	}

	override function destroy()
	{
		removeEvents();
		_fileRef = null;
		_currentEvent = null;
		onComplete = null;
		onCancel = null;
		onError = null;
		data = null;
		path = null;
		completed = true;
		super.destroy();
	}
}

//Only way I could find to keep the path after saving a file
class FileReferenceCustom extends FileReference
{
	@:allow(backend.FileDialogHandler)
	var _trackSavedPath:String;
	override function saveFileDialog_onSelect(path:String):Void
	{
		_trackSavedPath = path;
		super.saveFileDialog_onSelect(path);
	}
	
	public function browseEx(browseType:FileDialogType = OPEN, ?defaultName:String, ?title:String = null, ?typeFilter:Array<FileFilter> = null):Bool
	{
		__data = null;
		__path = null;

		#if desktop
		var window = Lib.current.stage.window;
		var filters:Array<FileDialogFilter> = null;

		if (typeFilter != null)
		{
			filters = @:privateAccess openfl.filesystem.File.__getFilterTypes(typeFilter);
		}

		switch (browseType)
		{
			case OPEN_DIRECTORY:
				FileDialog.openDirectory(window, title, function(paths:Array<String>):Void
				{
					if (paths != null && paths.length > 0) openFileDialog_onSelect(paths[0]);
					else openFileDialog_onCancel();
				}, defaultName, false);
			case SAVE:
				FileDialog.saveFile(window, title, function(path:String, filter:FileDialogFilter):Void
				{
					if (path != null && path.length > 0) saveFileDialog_onSelect(path);
					else saveFileDialog_onCancel();
				}, filters, defaultName);
			default:
				FileDialog.openFile(window, title, function(paths:Array<String>, filter:FileDialogFilter):Void
				{
					if (paths != null && paths.length > 0) openFileDialog_onSelect(paths[0]);
					else openFileDialog_onCancel();
				}, filters, defaultName, false);
		}
		return true;
		#elseif (js && html5)
		var filter = null;
		if (typeFilter != null)
		{
			var filters = [];
			for (type in typeFilter)
			{
				filters.push(StringTools.replace(StringTools.replace(type.extension, "*.", "."), ";", ","));
			}
			filter = filters.join(",");
		}
		if (filter != null)
		{
			__inputControl.setAttribute("accept", filter);
		}
		__inputControl.onchange = function()
		{
			var file = __inputControl.files[0];
			modificationDate = Date.fromTime(file.lastModified);
			creationDate = modificationDate;
			size = file.size;
			type = "." + Path.extension(file.name);
			name = Path.withoutDirectory(file.name);
			__path = file.name;
			dispatchEvent(new Event(Event.SELECT));
		}
		__inputControl.click();
		return true;
		#end

		return false;
	}
}
