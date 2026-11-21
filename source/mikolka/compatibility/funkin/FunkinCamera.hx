package mikolka.compatibility.funkin;

import animate.internal.RenderTexture;
import flash.geom.ColorTransform;
import backend.PsychCamera;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import funkin.graphics.framebuffer.FixedBitmapData;
import flixel.addons.display.FlxRuntimeShader;
import funkin.graphics.shaders.PlainCopyFx;
import funkin.graphics.shaders.RuntimeSceneBlendShader;
import funkin.graphics.shaders.SceneBlendFx;
import funkin.graphics.shaders.RuntimePostEffectShader;
import openfl.display.OpenGLRenderer;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;

using funkin.graphics.framebuffer.BitmapDataUtil;

typedef BlendSlot =
{
  var cam:FixedBitmapData;
  var blend:RenderTexture;
  var frame:FlxFrame;
  var shaders:Map<Int, RuntimeSceneBlendShader>;
  var fx:SceneBlendFx;
}

@:access(openfl.display.DisplayObject) @:access(openfl.display.BitmapData) @:access(openfl.display3D.Context3D) @:access(openfl.display3D.textures.TextureBase) @:access(flixel.graphics.FlxGraphic) @:access(flixel.graphics.frames.FlxFrame) @:access(openfl.display.OpenGLRenderer) @:access(openfl.geom.ColorTransform)
class FunkinCamera extends PsychCamera
{
    public static var hasKhronosExtension(get, never):Bool;

  static inline function get_hasKhronosExtension():Bool
  {
    return false;
  }

  static var coherentBlendsSupported(get, never):Bool;

  static function get_coherentBlendsSupported():Bool
  {
    @:privateAccess
    return OpenGLRenderer.__coherentBlendsSupported ?? false;
  }

    static final KHR_BLEND_MODES:Array<BlendMode> = [
    DARKEN,
    HARDLIGHT,
    #if !desktop LIGHTEN, #end
    OVERLAY,
    DIFFERENCE,
    COLORDODGE,
    COLORBURN,
    SOFTLIGHT,
    EXCLUSION,
    HUE,
    SATURATION,
    COLOR,
    LUMINOSITY
  ];

    static final SHADER_REQUIRED_BLEND_MODES:Array<BlendMode> = [INVERT];

    public var id:String;

    public var crossCameraBlending:Bool;

  var _slots:Array<BlendSlot>;
  var _slot:Int = 0;
  var _slotTick:Float = -1;
  var _blendMatrix:FlxMatrix;
  var _plain:FlxRuntimeShader;
  var _copyFx:PlainCopyFx;
  var _dbgCount:Int = 0;

  public function new(id:String = 'unknown', x:Float = 0, y:Float = 0, width:Int = 0, height:Int = 0, zoom:Float = 0)
  {
    super(x, y, width, height, zoom);

    this.id = id;

    _slots = [];
    _blendMatrix = new FlxMatrix();

    crossCameraBlending = false;
  }

  function getSlot(index:Int):BlendSlot
  {
    while (_slots.length <= index)
    {
      var cam:FixedBitmapData = FixedBitmapData.create(this.width, this.height);
      var graphic:FlxGraphic = new FlxGraphic('', null);
      graphic.bitmap = cam;
      var slotFrame:FlxFrame = new FlxFrame(graphic);
      slotFrame.frame = new FlxRect(0, 0, this.width, this.height);
      _slots.push({
        cam: cam,
        blend: new RenderTexture(this.width, this.height),
        frame: slotFrame,
        shaders: new Map(),
        fx: new SceneBlendFx()
      });
    }

    return _slots[index];
  }

  override function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false,
      ?shader:FlxShader):Void
  {
    var shouldUseShader:Bool = ((!hasKhronosExtension && KHR_BLEND_MODES.contains(blend)) || SHADER_REQUIRED_BLEND_MODES.contains(blend))
      && !RuntimePostEffectShader.compileFailed;

    if (shouldUseShader)
    {
      if (FlxG.game.ticks != _slotTick)
      {
        _slotTick = FlxG.game.ticks;
        _slot = 0;
      }

      var slot:BlendSlot = getSlot(_slot < 3 ? _slot : 3);
      _slot++;

      if (crossCameraBlending)
      {
        var camerasUnderneath:Array<FlxCamera> = FlxG.cameras.list.copy();

        for (i in camerasUnderneath.length - 1...-1)
        {
          if (i > FlxG.cameras.list.indexOf(this))
          {
            camerasUnderneath.remove(camerasUnderneath[i]);
          }
        }

        slot.cam.drawCameraScreens(camerasUnderneath);

        for (camera in camerasUnderneath)
        {
          camera.clearDrawStack();
          camera.canvas.graphics.clear();
        }
      }
      else
      {
        slot.cam.drawCameraScreen(this);
      }

      this.clearDrawStack();
      this.canvas.graphics.clear();

      slot.blend.init(this.width, this.height);
      slot.blend.drawToCamera((camera, frameMatrix) ->
      {
        var pivotX:Float = width / 2;
        var pivotY:Float = height / 2;

        frameMatrix.copyFrom(matrix);
        frameMatrix.translate(-pivotX, -pivotY);
        frameMatrix.scale(this.scaleX, this.scaleY);
        frameMatrix.translate(pivotX, pivotY);
        camera.drawPixels(frame, pixels, frameMatrix, transform, null, smoothing, shader);
      });
      slot.blend.render();

      var modeId:Int = cast blend;
      var stage:Int = _dbgCount < 1200 ? Std.int(_dbgCount / 240) : 3;
      var blendShader:FlxShader = null;

      if (stage == 0)
      {
        if (_plain == null) _plain = new FlxRuntimeShader('#pragma header\nvoid main()\n{\n  gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);\n}\n', null);
        blendShader = _plain;
      }
      else if (stage == 1)
      {
        if (_copyFx == null) _copyFx = new PlainCopyFx();
        blendShader = _copyFx;
      }
      else if (stage == 4)
      {
        var scene:RuntimeSceneBlendShader = slot.shaders.get(modeId);
        if (scene == null)
        {
          scene = new RuntimeSceneBlendShader(modeId);
          slot.shaders.set(modeId, scene);
        }
        scene.sourceSwag = slot.blend.graphic.bitmap;
        scene.updateViewInfo(width, height, this);
        blendShader = scene;
      }
      else
      {
        slot.fx.overlayTex.input = slot.blend.graphic.bitmap;
        slot.fx.blendId.value = [modeId * 1.0];
        slot.fx.dbgId.value = [stage == 2 ? 1.0 : 0.0];
        blendShader = slot.fx;
      }

      _dbgCount++;
      if (_dbgCount % 240 == 1 && _dbgCount < 1200)
      {
        var names:Array<String> = ['0 FlxRuntimeShader simple', '1 shader de compilacion simple', '2 solo overlay (compilacion)', '3 mezcla (compilacion)', '4 mezcla (ejecucion)'];
        try
        {
          Lib.application.window.alert('Etapa ' + names[stage], 'Etapa');
        }
        catch (e)
        {
        }
      }

      _blendMatrix.identity();
      _blendMatrix.scale(1 / this.scaleX, 1 / this.scaleY);
      _blendMatrix.translate(((width - width / this.scaleX) * 0.5), ((height - height / this.scaleY) * 0.5));

      super.drawPixels(slot.frame, null, _blendMatrix, null, null, smoothing, blendShader);
    }
    else
    {
      super.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader);
    }
  }

  override function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false,
      ?shader:FlxShader):FlxDrawQuadsItem
  {
    if (hasKhronosExtension && !coherentBlendsSupported && KHR_BLEND_MODES.contains(blend))
    {
      var itemToReturn = null;

      if (FlxCamera._storageTilesHead != null)
      {
        itemToReturn = FlxCamera._storageTilesHead;
        var newHead = FlxCamera._storageTilesHead.nextTyped;
        itemToReturn.reset();
        FlxCamera._storageTilesHead = newHead;
      }
      else
      {
        itemToReturn = new FlxDrawQuadsItem();
      }

      if (graphic.isDestroyed) throw 'Cannot queue ${graphic.key}. This sprite was destroyed.';

      itemToReturn.graphics = graphic;
      itemToReturn.antialiasing = smooth;
      itemToReturn.colored = colored;
      itemToReturn.hasColorOffsets = hasColorOffsets;
      itemToReturn.blend = blend;
          itemToReturn.shader = shader;

      itemToReturn.nextTyped = _headTiles;
      _headTiles = itemToReturn;

      if (_headOfDrawStack == null)
      {
        _headOfDrawStack = itemToReturn;
      }

      if (_currentDrawItem != null)
      {
        _currentDrawItem.next = itemToReturn;
      }

      _currentDrawItem = itemToReturn;

      return itemToReturn;
    }

    return super.startQuadBatch(graphic, colored, hasColorOffsets, blend, smooth, shader);
  }

  override function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool,
      ?shader:FlxShader):FlxDrawTrianglesItem
  {
    if (hasKhronosExtension
      && !coherentBlendsSupported
      && KHR_BLEND_MODES.contains(blend)) return getNewDrawTrianglesItem(graphic, smoothing, isColored, blend, hasColorOffsets, shader);

    return super.startTrianglesBatch(graphic, smoothing, isColored, blend, hasColorOffsets, shader);
  }

  override function destroy():Void
  {
    super.destroy();

    if (_slots != null)
    {
      for (slot in _slots)
      {
        slot.blend.destroy();
        slot.cam.dispose();
      }
    }
  }
}
