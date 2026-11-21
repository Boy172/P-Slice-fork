package funkin.graphics.shaders;

import flixel.system.FlxAssets.FlxShader;

@:keep
class PlainCopyFx extends FlxShader
{
  @:glFragmentSource('
#pragma header

void main()
{
  gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);
}
  ')
  public function new()
  {
    super();
  }
}
