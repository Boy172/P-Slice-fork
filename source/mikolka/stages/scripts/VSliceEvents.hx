
package mikolka.stages.scripts;

import haxe.Json;
import flixel.util.FlxTimer;
import mikolka.funkin.custom.mobile.FullScreenScaleMode;
import objects.Character;
import objects.HealthIcon;

class VSliceEvents extends BaseStage {
    private var zoomTween:FlxTween;
    private var camTween:FlxTween;
    private var tempVocals:FlxSound;
    private var tempTarget:Character;
    private var tempTimer:FlxTimer;

    override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float) {
        #if js
        // I hate you JS part 2
        value1 = Std.string(value1);
        value2 = Std.string(value1);
        #end
        switch (eventName){
            case 'FocusCamera':
                focusCameraEvent(value1, value2);
            case 'ZoomCamera':
                zoomCameraEvent(value1, value2);
            case 'PlayAnimation':
                playAnimationEvent(value1, value2);
            case 'ScrollSpeed':
                scrollSpeedEvent(value1, value2);
            case 'SetHealthIcon':
                setHealthIconEvent(value1, value2);
            case 'Vslice Scroll Speed':
				if (game.songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = ClientPrefs.getGameplaySetting('scrollspeed',1.0) * flValue1;
					if(flValue2 <= 0)
						game.songSpeed = newValue;
					else
						game.songSpeedTween = FlxTween.tween(game, {songSpeed: newValue}, flValue2 / game.playbackRate, {ease: FlxEase.quadInOut, onComplete:
							function (twn:FlxTween)
							{
								game.songSpeedTween = null;
							}
						});
				}
            case 'Set Camera Bopping': //P-slice event notes
				var val1 = Std.parseFloat(value1);
				var val2 = Std.parseFloat(value2);
				game.camZoomingMult = !Math.isNaN(val2) ? val2 : 1;
				game.camZoomingFrequency = !Math.isNaN(val1) ? val1 : 4;
            case 'Target Camera': //P-slice event notes val1: char val2: x,y,dur,ease
                var keyValues = value2.split(",");
                if(keyValues.length != 4) {
                    trace("INVALID EVENT VALUE");
                    return;
                }
                var ease = keyValues.pop().toLowerCase();
                var floaties = keyValues.map(s -> Std.parseFloat(s));
                if(mikolka.funkin.utils.ArrayTools.findIndex(floaties,s -> Math.isNaN(s)) != -1) {
                    trace("INVALID FLOATIES");
                    return;
                }
                @:privateAccess
                game.isCameraOnForcedPos = true;

                var targetx = floaties[0];
                var targety = floaties[1];
                var dur = floaties[2]*(Conductor.stepCrochet/1000);
                switch (value1){
                    case "bf"|"0":{
                        targetx += game.boyfriend.getMidpoint().x -100 - boyfriend.cameraPosition[0] + game.boyfriendCameraOffset[0];
                        targety += game.boyfriend.getMidpoint().y -100 + boyfriend.cameraPosition[1] + game.boyfriendCameraOffset[1];
                    }
                    case "dad"|"1":{
                        targetx += game.dad.getMidpoint().x +150 + dad.cameraPosition[0] + game.opponentCameraOffset[0];
                        targety += game.dad.getMidpoint().y -100 + dad.cameraPosition[1] + game.opponentCameraOffset[1];
                    }
                    case "gf"|"2":{
                        targetx += game.gf.getMidpoint().x + gf.cameraPosition[0] - game.girlfriendCameraOffset[0];
                        targety += game.gf.getMidpoint().y + gf.cameraPosition[1] - game.girlfriendCameraOffset[1];
                    }
                }

                if(ease == "classic" || ease == "instant"){
                    game.camFollow.x = targetx;
                    game.camFollow.y = targety;
                    if(ease == "instant") FlxG.camera.snapToTarget();
                }
                else{
                    #if LEGACY_PSYCH
                    var easeFunc = FunkinLua.getFlxEaseByString(ease);
                    #else
                    var easeFunc = psychlua.LuaUtils.getTweenEaseByString(ease);
                    #end
                    camTween?.cancel();
                    camTween = FlxTween.tween(game.camFollow,{x:targetx,y:targety},dur,{
                        ease: easeFunc,
                        onComplete: s -> {
                            camTween = null;
                        }
                    });
                }
			case 'Zoom Camera': //defaultCamZoom
				var keyValues = value1.split(",");
				if(keyValues.length != 2) {
					trace("INVALID EVENT VALUE");
					return;
				}
				var floaties = keyValues.map(s -> Std.parseFloat(s));
				if(mikolka.funkin.utils.ArrayTools.findIndex(floaties,s -> Math.isNaN(s)) != -1) {
					trace("INVALID FLOATIES");
					return;
				}
				#if LEGACY_PSYCH
                var easeFunc = FunkinLua.getFlxEaseByString(value2);
                #else
                var easeFunc = psychlua.LuaUtils.getTweenEaseByString(value2);
                #end
				if(zoomTween != null) zoomTween.cancel();
				var targetZoom = floaties[1]*game.defaultStageZoom;
				zoomTween = FlxTween.tween(this,{ defaultCamZoom:targetZoom},(Conductor.stepCrochet/1000)*floaties[0],{
					onStart: (x) ->{
						//camZooming = false;
						game.camZoomingDecay = 7;
					},
					ease: easeFunc,
					onComplete: (x) ->{
						defaultCamZoom = targetZoom;
						game.camZoomingDecay = 1;
						//camZooming = true;
						zoomTween = null;
					}
				});
        }
    }

    static function readData(value1:String, value2:String, key1:String, key2:String):Dynamic {
        var raw:String = value1 == null ? '' : value1.trim();
        if (raw.length > 0 && raw.charAt(0) == '{') {
            try {
                return Json.parse(raw);
            } catch (e:Dynamic) {}
        }
        var data:Dynamic = {};
        if (raw.length > 0) Reflect.setField(data, key1, raw);
        var second:String = value2 == null ? '' : value2.trim();
        if (second.length > 0) Reflect.setField(data, key2, second);
        return data;
    }

    static function num(data:Dynamic, key:String, def:Float):Float {
        var value:Dynamic = Reflect.field(data, key);
        if (value == null) return def;
        var parsed:Float = Std.parseFloat(Std.string(value));
        return Math.isNaN(parsed) ? def : parsed;
    }

    static function text(data:Dynamic, key:String, def:String):String {
        var value:Dynamic = Reflect.field(data, key);
        return value == null ? def : Std.string(value);
    }

    static function flag(data:Dynamic, key:String, def:Bool):Bool {
        var value:Dynamic = Reflect.field(data, key);
        if (value == null) return def;
        var s:String = Std.string(value).toLowerCase();
        return s == 'true' || s == '1';
    }

    static function easeFunc(ease:String, dir:String):Null<Float->Float> {
        var lower:String = ease.toLowerCase();
        var suffix:String = dir;
        if (lower == 'linear' || lower.endsWith('in') || lower.endsWith('out')) suffix = '';
        var fn:Null<Float->Float> = Reflect.getProperty(FlxEase, ease + suffix);
        return fn;
    }

    static function stepsToSeconds(steps:Float):Float {
        return Conductor.stepCrochet * steps / 1000;
    }

    function focusCameraEvent(value1:String, value2:String):Void {
        var data:Dynamic = readData(value1, value2, 'char', 'duration');
        var char:Int = Std.int(num(data, 'char', 0));
        var targetX:Float = num(data, 'x', 0);
        var targetY:Float = num(data, 'y', 0);
        var duration:Float = num(data, 'duration', 4);
        var ease:String = text(data, 'ease', 'CLASSIC');
        var easeDir:String = text(data, 'easeDir', 'In');

        if (char >= 0 && char <= 2) {
            var point = game.getCameraFocusPoint(char);
            if (point == null) return;
            targetX += point.x;
            targetY += point.y;
            point.put();
        }

        if (ease == 'CLASSIC') {
            game.cancelCameraFollowTween();
            game.resetCameraFollow(false);
            game.isCameraOnForcedPos = true;
            game.camFollow.setPosition(targetX, targetY);
        } else if (ease == 'INSTANT') {
            game.tweenCameraToPosition(targetX, targetY, 0);
        } else {
            var fn = easeFunc(ease, easeDir);
            if (fn == null) return;
            game.tweenCameraToPosition(targetX, targetY, stepsToSeconds(duration), fn);
        }
    }

    function zoomCameraEvent(value1:String, value2:String):Void {
        var data:Dynamic = readData(value1, value2, 'zoom', 'duration');
        var zoom:Float = num(data, 'zoom', 1);
        var scaleX:Float = num(data, 'widescreenScaleX', 0);
        var scaleY:Float = num(data, 'widescreenScaleY', 0);
        var duration:Float = num(data, 'duration', 4);
        var direct:Bool = text(data, 'mode', 'direct') == 'direct';
        var ease:String = text(data, 'ease', 'linear');
        var easeDir:String = text(data, 'easeDir', 'In');

        var wide = FullScreenScaleMode.wideScale;
        var scaledZoom:Float = zoom + zoom * ((wide.x - 1) * scaleX + (wide.y - 1) * scaleY);

        if (ease == 'INSTANT') {
            game.tweenCameraZoom(scaledZoom, 0, direct);
        } else {
            var fn = easeFunc(ease, easeDir);
            if (fn == null) return;
            game.tweenCameraZoom(scaledZoom, stepsToSeconds(duration), direct, fn);
        }
    }

    function playAnimationEvent(value1:String, value2:String):Void {
        var data:Dynamic = readData(value1, value2, 'target', 'anim');
        var targetName:String = text(data, 'target', 'boyfriend');
        var anim:String = text(data, 'anim', 'idle');
        var force:Bool = flag(data, 'force', false);

        var target:Dynamic = null;
        var vocals:FlxSound = null;
        switch (targetName) {
            case 'boyfriend' | 'bf' | 'player':
                target = game.boyfriend;
                vocals = game.vocals;
            case 'dad' | 'opponent':
                target = game.dad;
                vocals = game.opponentVocals;
            case 'girlfriend' | 'gf':
                target = game.gf;
            default:
                target = game.getLuaObject(targetName);
        }

        if (target == null) return;

        if (Std.isOfType(target, Character)) {
            var char:Character = cast target;
            if (!force && char.specialAnim) return;
            if (!char.hasAnimation(anim)) return;

            if (force && vocals != null) {
                if (vocals.volume == 0) {
                    vocals.volume = 1;
                    tempVocals = vocals;
                }
                tempTarget = char;
                if (tempTimer == null) tempTimer = new FlxTimer();
                tempTimer.start(0.05, checkTempVocals, 0);
            }

            char.playAnim(anim, force);
            char.specialAnim = force;
        } else {
            var sprite:FlxSprite = cast target;
            if (sprite.animation != null) sprite.animation.play(anim, force);
        }
    }

    function checkTempVocals(timer:FlxTimer):Void {
        if (tempTarget != null && tempTarget.specialAnim) return;
        if (tempVocals != null) tempVocals.volume = 0;
        tempVocals = null;
        tempTarget = null;
        timer.cancel();
    }

    function scrollSpeedEvent(value1:String, value2:String):Void {
        if (game.songSpeedType == 'constant') return;

        var data:Dynamic = readData(value1, value2, 'scroll', 'duration');
        var scroll:Float = num(data, 'scroll', 1);
        var duration:Float = num(data, 'duration', 4);
        var ease:String = text(data, 'ease', 'linear');
        var easeDir:String = text(data, 'easeDir', 'In');
        var strumline:String = text(data, 'strumline', 'both');
        var absolute:Bool = flag(data, 'absolute', false);

        if (!absolute) scroll = scroll * PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');

        var names:Array<String> = strumline == 'both' ? ['playerStrumline', 'opponentStrumline'] : [strumline + 'Strumline'];

        if (ease == 'INSTANT') {
            game.tweenScrollSpeed(scroll, 0, null, names);
        } else {
            var fn = easeFunc(ease, easeDir);
            if (fn == null) return;
            game.tweenScrollSpeed(scroll, stepsToSeconds(duration), fn, names);
        }
    }

    function setHealthIconEvent(value1:String, value2:String):Void {
        var data:Dynamic = readData(value1, value2, 'char', 'id');
        var char:Int = Std.int(num(data, 'char', 0));
        var id:String = text(data, 'id', 'face');

        var icon:HealthIcon = char == 0 ? game.iconP1 : (char == 1 ? game.iconP2 : null);
        if (icon == null) return;

        icon.configure(id, num(data, 'scale', 1), flag(data, 'flipX', false), flag(data, 'isPixel', false), flag(data, 'shouldBop', true),
            num(data, 'offsetX', 0), num(data, 'offsetY', 0));
        icon.y = game.healthBar.y - icon.restWidth / 2;
        game.health = game.health;
    }
}
