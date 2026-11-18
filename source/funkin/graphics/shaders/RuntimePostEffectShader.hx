package funkin.graphics.shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.frames.FlxFrame;
import flixel.addons.display.FlxRuntimeShader;
import lime.graphics.opengl.GLProgram;
import lime.utils.Log;
import openfl.display.ShaderParameter;

class RuntimePostEffectShader extends FlxRuntimeShader
{
  @:glVertexHeader('
		varying vec2 screenCoord;
	', true) @:glVertexBody('
		screenCoord = vec2(
			openfl_TextureCoord.x > 0.0 ? 1.0 : 0.0,
			openfl_TextureCoord.y > 0.0 ? 1.0 : 0.0
		);
	') @:glFragmentHeader('
		varying vec2 screenCoord;

		uniform vec2 uScreenResolution;

		uniform vec4 uCameraBounds;

		uniform vec4 uFrameBounds;

		vec2 screenToWorld(vec2 screenCoord) {
			float left = uCameraBounds.x;
			float top = uCameraBounds.y;
			float right = uCameraBounds.z;
			float bottom = uCameraBounds.w;
			vec2 scale = vec2(right - left, bottom - top);
			vec2 offset = vec2(left, top);
			return screenCoord * scale + offset;
		}

		vec2 worldToScreen(vec2 worldCoord) {
			float left = uCameraBounds.x;
			float top = uCameraBounds.y;
			float right = uCameraBounds.z;
			float bottom = uCameraBounds.w;
			vec2 scale = vec2(right - left, bottom - top);
			vec2 offset = vec2(left, top);
			return (worldCoord - offset) / scale;
		}

		vec2 screenToFrame(vec2 screenCoord) {
			float left = uFrameBounds.x;
			float top = uFrameBounds.y;
			float right = uFrameBounds.z;
			float bottom = uFrameBounds.w;
			float width = right - left;
			float height = bottom - top;

			float clampedX = clamp(screenCoord.x, left, right);
			float clampedY = clamp(screenCoord.y, top, bottom);

			return vec2(
				(clampedX - left) / (width),
				(clampedY - top) / (height)
			);
		}

		vec2 bitmapCoordScale() {
			return openfl_TextureCoordv / screenCoord;
		}

		vec2 screenToBitmap(vec2 screenCoord) {
			return screenCoord * bitmapCoordScale();
		}

		vec4 sampleBitmapScreen(vec2 screenCoord) {
			return texture2D(bitmap, screenToBitmap(screenCoord));
		}

		vec4 sampleBitmapWorld(vec2 worldCoord) {
			return sampleBitmapScreen(worldToScreen(worldCoord));
		}
	', true)
  public function new(fragmentSource:String = null)
  {
    super(fragmentSource, null);
  }

  function setUniform(name:String, value:Array<Float>):Void
  {
    var parameter:ShaderParameter<Float> = Reflect.field(data, name);
    if (parameter != null) parameter.value = value;
  }

  public function updateViewInfo(screenWidth:Float, screenHeight:Float, camera:FlxCamera):Void
  {
    setUniform('uScreenResolution', [screenWidth, screenHeight]);
    setUniform('uCameraBounds', [camera.viewLeft, camera.viewTop, camera.viewRight, camera.viewBottom]);
  }

  public function updateFrameInfo(frame:FlxFrame)
  {
    setUniform('uFrameBounds', [frame.uv.left, frame.uv.top, frame.uv.right, frame.uv.bottom]);
  }

  override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
  {
    try
    {
      final res = super.__createGLProgram(vertexSource, fragmentSource);
      return res;
    }
    catch (error)
    {
      Log.warn(error); // prevent the app from dying immediately
      return null;
    }
  }
}
