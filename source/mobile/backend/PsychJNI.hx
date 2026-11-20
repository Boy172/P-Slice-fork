package mobile.backend;

#if android
import lime.system.JNI;

class PsychJNI #if (lime >= "8.0.0") implements JNISafety #end
{
	public static final SDL_ORIENTATION_UNKNOWN:Int = 0;
	public static final SDL_ORIENTATION_LANDSCAPE:Int = 1;
	public static final SDL_ORIENTATION_LANDSCAPE_FLIPPED:Int = 2;
	public static final SDL_ORIENTATION_PORTRAIT:Int = 3;
	public static final SDL_ORIENTATION_PORTRAIT_FLIPPED:Int = 4;

	public static inline function setOrientation(width:Int, height:Int, resizeable:Bool, hint:String):Dynamic
		return setOrientation_jni(width, height, resizeable, hint);

	public static function getCurrentOrientationAsString():String
	{
		var orientation:Int = SDL_ORIENTATION_UNKNOWN;

		if (getCurrentOrientation_jni != null)
		{
			orientation = getCurrentOrientation_jni();
		}
		else if (getCurrentRotation_jni != null)
		{
			orientation = switch (Std.int(getCurrentRotation_jni()))
			{
				case 0: SDL_ORIENTATION_PORTRAIT;
				case 90: SDL_ORIENTATION_LANDSCAPE;
				case 180: SDL_ORIENTATION_PORTRAIT_FLIPPED;
				case 270: SDL_ORIENTATION_LANDSCAPE_FLIPPED;
				default: SDL_ORIENTATION_UNKNOWN;
			}
		}

		return switch (orientation)
		{
			case SDL_ORIENTATION_PORTRAIT: "Portrait";
			case SDL_ORIENTATION_LANDSCAPE: "LandscapeRight";
			case SDL_ORIENTATION_PORTRAIT_FLIPPED: "PortraitUpsideDown";
			case SDL_ORIENTATION_LANDSCAPE_FLIPPED: "LandscapeLeft";
			default: "Unknown";
		}
	}

	public static function isScreenKeyboardShown():Dynamic
		return isScreenKeyboardShown_jni != null ? isScreenKeyboardShown_jni() : false;

	public static inline function clipboardHasText():Dynamic
		return clipboardHasText_jni();

	public static inline function clipboardGetText():Dynamic
		return clipboardGetText_jni();

	public static inline function clipboardSetText(string:String):Dynamic
		return clipboardSetText_jni(string);

	public static inline function manualBackButton():Dynamic
		return manualBackButton_jni();

	public static inline function setActivityTitle(title:String):Dynamic
		return setActivityTitle_jni(title);

	@:noCompletion private static var setOrientation_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'setOrientation',
		'(IIZLjava/lang/String;)V', false, true);
	@:noCompletion private static var getCurrentOrientation_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'getCurrentOrientation', '()I', false, true);
	@:noCompletion private static var getCurrentRotation_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'getCurrentRotation', '()I', false, true);
	@:noCompletion private static var isScreenKeyboardShown_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'isScreenKeyboardShown', '()Z', false, true);
	@:noCompletion private static var clipboardHasText_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'clipboardHasText', '()Z', false, true);
	@:noCompletion private static var clipboardGetText_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'clipboardGetText',
		'()Ljava/lang/String;', false, true);
	@:noCompletion private static var clipboardSetText_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'clipboardSetText',
		'(Ljava/lang/String;)V', false, true);
	@:noCompletion private static var manualBackButton_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'manualBackButton', '()V', false, true);
	@:noCompletion private static var setActivityTitle_jni:Dynamic = JNI.createStaticMethod('org/libsdl/app/SDLActivity', 'setActivityTitle',
		'(Ljava/lang/String;)Z', false, true);
}
#end
