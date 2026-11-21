
package funkin.graphics.shaders;

import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.utils.Assets;

class RuntimeCustomBlendShader extends RuntimePostEffectShader
{
  public var sourceSwag(default, set):BitmapData;

  function set_sourceSwag(value:BitmapData):BitmapData
  {
    this.setBitmapData('sourceSwag', value);
    return sourceSwag = value;
  }

  public var backgroundSwag(default, set):BitmapData;

  function set_backgroundSwag(value:BitmapData):BitmapData
  {
    this.setBitmapData('backgroundSwag', value);
    return backgroundSwag = value;
  }

  public var blendSwag(default, set):BlendMode;

  function set_blendSwag(value:BlendMode):BlendMode
  {
    this.setInt('blendMode', cast value);
    return blendSwag = value;
  }

  public function new()
  {
    super(Assets.getText('assets/shared/shaders/customBlend.frag'));
  }
}
