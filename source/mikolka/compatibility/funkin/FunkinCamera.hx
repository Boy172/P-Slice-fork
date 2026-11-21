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
import funkin.graphics.shaders.RuntimeCustomBlendShader;
import funkin.graphics.shaders.RuntimePostEffectShader;
import openfl.display.OpenGLRenderer;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;

using funkin.graphics.framebuffer.BitmapDataUtil;

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

  var _blendShader:RuntimeCustomBlendShader;
  var _backgroundFrame:FlxFrame;
  var _blendRenderTexture:RenderTexture;
  var _backgroundRenderTexture:RenderTexture;
  var _cameraTexture:FixedBitmapData;
  var _cameraMatrix:FlxMatrix;
  var _dbgMatrix:FlxMatrix;
  var _dbgCount:Int = 0;
  var _dbgAlerted:Bool = false;
  var _dbgFrame:FlxFrame;
  var _dbgMatrix:FlxMatrix;

  public function new(id:String = 'unknown', x:Float = 0, y:Float = 0, width:Int = 0, height:Int = 0, zoom:Float = 0)
  {
    super(x, y, width, height, zoom);

    this.id = id;

    _backgroundFrame = new FlxFrame(new FlxGraphic('', null));
    _backgroundFrame.frame = new FlxRect();

    _cameraMatrix = new FlxMatrix();

    crossCameraBlending = false;
  }

  function ensureBlendResources():Void
  {
    if (_blendShader != null) return;

    _blendShader = new RuntimeCustomBlendShader();

    _backgroundRenderTexture = new RenderTexture(this.width, this.height);
    _blendRenderTexture = new RenderTexture(this.width, this.height);

    _cameraTexture = FixedBitmapData.create(this.width, this.height);
  }

  override function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false,
      ?shader:FlxShader):Void
  {
    var shouldUseShader:Bool = ((!hasKhronosExtension && KHR_BLEND_MODES.contains(blend)) || SHADER_REQUIRED_BLEND_MODES.contains(blend))
      && !RuntimePostEffectShader.compileFailed;

    if (shouldUseShader)
    {
      ensureBlendResources();

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

        _cameraTexture.drawCameraScreens(camerasUnderneath);

        for (camera in camerasUnderneath)
        {
          camera.clearDrawStack();
          camera.canvas.graphics.clear();
        }
      }
      else
      {
        _cameraTexture.drawCameraScreen(this);
      }

      _backgroundFrame.frame.set(0, 0, this.width, this.height);

      this.clearDrawStack();
      this.canvas.graphics.clear();

      _blendRenderTexture.init(this.width, this.height);
      _blendRenderTexture.drawToCamera((camera, frameMatrix) ->
      {
        var pivotX:Float = width / 2;
        var pivotY:Float = height / 2;

        frameMatrix.copyFrom(matrix);
        frameMatrix.translate(-pivotX, -pivotY);
        frameMatrix.scale(this.scaleX, this.scaleY);
        frameMatrix.translate(pivotX, pivotY);
        camera.drawPixels(frame, pixels, frameMatrix, transform, null, smoothing, shader);
      });
      _blendRenderTexture.render();

      _blendShader.sourceSwag = _blendRenderTexture.graphic.bitmap;
      _blendShader.backgroundSwag = _cameraTexture;

      var stage:Int = Std.int(Lib.getTimer() / 6000) % 4;
      _blendShader.blendSwag = blend;
      _blendShader.setInt('debugOut', 0);
      _blendShader.setInt('debugOut', Std.int(Lib.getTimer() / 5000) % 8);
      _blendShader.updateViewInfo(width, height, this);

      _backgroundFrame.parent.bitmap = _blendRenderTexture.graphic.bitmap;

      var clampedScale:Float = Math.max(1, Lib.current.stage.window.scale);

      _backgroundRenderTexture.init(Std.int(this.width * clampedScale), Std.int(this.height * clampedScale));
      _backgroundRenderTexture.drawToCamera((camera, matrix) ->
      {
        camera.zoom = this.zoom;
        matrix.scale(clampedScale, clampedScale);
        camera.drawPixels(_backgroundFrame, null, matrix, canvas.transform.colorTransform, null, false, stage == 3 ? null : _blendShader);
      });

      _backgroundRenderTexture.render();

      _cameraMatrix.identity();
      _cameraMatrix.scale(1 / (this.scaleX * clampedScale), 1 / (this.scaleY * clampedScale));
      _cameraMatrix.translate(((width - width / this.scaleX) * 0.5), ((height - height / this.scaleY) * 0.5));

      var stage:Int = Std.int(Lib.getTimer() / 6000) % 4;

      if (stage == 0)
      {
        _dbgCount++;
      if (!_dbgAlerted && _dbgCount > 300)
      {
        _dbgAlerted = true;
        var info:String = 'prog=' + (_blendShader.glProgram != null) + ' src=' + (Reflect.field(_blendShader.data, 'sourceSwag') != null) + ' bg='
          + (Reflect.field(_blendShader.data, 'backgroundSwag') != null) + ' mode=' + (Reflect.field(_blendShader.data, 'blendMode') != null) + ' dbg='
          + (Reflect.field(_blendShader.data, 'debugOut') != null) + ' pre=' + (Reflect.field(_blendShader.data, 'premultiplyAlpha') != null) + '\n'
          + _blendShader.debugInfo();
        try
        {
          Lib.application.window.alert(info, 'Shader');
        }
        catch (e)
        {
        }
      }

      if (stage == 1 || stage == 2)
      {
        if (_dbgMatrix == null) _dbgMatrix = new FlxMatrix();
        _dbgMatrix.identity();
        _dbgMatrix.scale(1 / this.scaleX, 1 / this.scaleY);
        _dbgMatrix.translate(((width - width / this.scaleX) * 0.5), ((height - height / this.scaleY) * 0.5));
        _blendShader.setInt('debugOut', stage == 2 ? 4 : 0);
        super.drawPixels(_backgroundFrame, null, _dbgMatrix, null, null, smoothing, _blendShader);
      }
      else
      {
        super.drawPixels(_backgroundRenderTexture.graphic.imageFrame.frame, null, _cameraMatrix, null, null, smoothing, null);
      }
      }
      else
      {
        if (_dbgFrame == null)
        {
          _dbgFrame = new FlxFrame(new FlxGraphic('', null));
          _dbgFrame.frame = new FlxRect();
          _dbgMatrix = new FlxMatrix();
        }

        _dbgFrame.frame.set(0, 0, this.width, this.height);
        if (stage == 1) _dbgFrame.parent.bitmap = _cameraTexture;
        else if (stage == 2) _dbgFrame.parent.bitmap = _blendRenderTexture.graphic.bitmap;
        else _dbgFrame.parent.bitmap = _backgroundRenderTexture.graphic.bitmap;

        _dbgMatrix.identity();
        _dbgMatrix.scale(1 / this.scaleX, 1 / this.scaleY);
        _dbgMatrix.translate(((width - width / this.scaleX) * 0.5), ((height - height / this.scaleY) * 0.5));

        super.drawPixels(_dbgFrame, null, _dbgMatrix, null, null, smoothing, null);
      }
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

    if (_blendRenderTexture != null) _blendRenderTexture.destroy();
    if (_backgroundRenderTexture != null) _backgroundRenderTexture.destroy();
    if (_cameraTexture != null) _cameraTexture.dispose();
  }
}
