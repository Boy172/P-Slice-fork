package external.android;

#if android
@:unreflective
class ResolutionUtil
{
  public static function setScale(percent:Int):Bool
  {
    final method:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/ResolutionUtil', 'setScale', '(F)Z');
    if (method == null) return false;
    return method(percent / 100) == true;
  }
}
#end
