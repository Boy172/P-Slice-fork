package mikolka.funkin.custom.mobile;

import flixel.math.FlxPoint;
import flixel.util.FlxAxes;

/**
 * Backwards-compatible facade for existing P-Slice code.
 * Static members are forwarded because Haxe does not inherit static fields.
 */
class MobileScaleMode extends FullScreenScaleMode
{
    public function new(enable:Bool = true)
    {
        super(enable);
    }

    public static var cutoutSize(get, never):FlxPoint;
    static function get_cutoutSize():FlxPoint return FullScreenScaleMode.cutoutSize;

    public static var notchPosition(get, never):FlxPoint;
    static function get_notchPosition():FlxPoint return FullScreenScaleMode.notchPosition;

    public static var notchSize(get, never):FlxPoint;
    static function get_notchSize():FlxPoint return FullScreenScaleMode.notchSize;

    public static var logicalSize(get, never):FlxPoint;
    static function get_logicalSize():FlxPoint return FullScreenScaleMode.logicalSize;

    public static var maxAspectRatio(get, never):FlxPoint;
    static function get_maxAspectRatio():FlxPoint return FullScreenScaleMode.maxAspectRatio;

    public static var maxRatioAxis(get, never):FlxAxes;
    static function get_maxRatioAxis():FlxAxes return FullScreenScaleMode.maxRatioAxis;

    public static var gameRatio(get, never):Float;
    static function get_gameRatio():Float return FullScreenScaleMode.gameRatio;

    public static var gameCutoutSize(get, never):FlxPoint;
    static function get_gameCutoutSize():FlxPoint return FullScreenScaleMode.gameCutoutSize;

    public static var gameNotchPosition(get, never):FlxPoint;
    static function get_gameNotchPosition():FlxPoint return FullScreenScaleMode.gameNotchPosition;

    public static var gameNotchSize(get, never):FlxPoint;
    static function get_gameNotchSize():FlxPoint return FullScreenScaleMode.gameNotchSize;

    public static var screenRatio(get, never):Float;
    static function get_screenRatio():Float return FullScreenScaleMode.screenRatio;

    public static var wideScale(get, never):FlxPoint;
    static function get_wideScale():FlxPoint return FullScreenScaleMode.wideScale;

    public static var ratioAxis(get, never):FlxAxes;
    static function get_ratioAxis():FlxAxes return FullScreenScaleMode.ratioAxis;

    public static var instance(get, never):FullScreenScaleMode;
    static function get_instance():FullScreenScaleMode return FullScreenScaleMode.instance;

    public static var enabled(get, set):Bool;
    static function get_enabled():Bool return FullScreenScaleMode.enabled;
    static function set_enabled(value:Bool):Bool return FullScreenScaleMode.enabled = value;

    public static var hasFakeCutouts(get, never):Bool;
    static function get_hasFakeCutouts():Bool return FullScreenScaleMode.hasFakeCutouts;

    public static function addCutouts(tweenDuration:Float = 0.0, ?ease:Float->Float):Void
        FullScreenScaleMode.addCutouts(tweenDuration, ease);

    public static function removeCutouts(tweenDuration:Float = 0.0, ?ease:Float->Float):Void
        FullScreenScaleMode.removeCutouts(tweenDuration, ease);
}
