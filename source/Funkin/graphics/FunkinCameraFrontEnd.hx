package funkin.graphics;

import flixel.FlxCamera;
import mikolka.compatibility.funkin.FunkinCamera;
import flixel.system.frontEnds.CameraFrontEnd;

class FunkinCameraFrontEnd extends CameraFrontEnd
{
  override public function reset(?newCamera:FlxCamera):Void
  {
    super.reset(newCamera ?? new FunkinCamera());
  }
}
