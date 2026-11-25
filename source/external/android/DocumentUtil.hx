package external.android;

#if android
@:unreflective
class DocumentUtil
{
  public static function copyUriToFile(uri:String, destPath:String):Bool
  {
    final method:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/DocumentUtil', 'copyUriToFile', '(Ljava/lang/String;Ljava/lang/String;)Z');
    if (method == null) return false;
    return method(uri, destPath) == true;
  }

  public static function copyFileToUri(srcPath:String, uri:String):Bool
  {
    final method:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/DocumentUtil', 'copyFileToUri', '(Ljava/lang/String;Ljava/lang/String;)Z');
    if (method == null) return false;
    return method(srcPath, uri) == true;
  }

  public static function getDisplayName(uri:String):String
  {
    final method:Null<Dynamic> = JNIUtil.createStaticMethod('funkin/util/DocumentUtil', 'getDisplayName', '(Ljava/lang/String;)Ljava/lang/String;');
    if (method == null) return '';
    final name:Null<String> = method(uri);
    return name == null ? '' : name;
  }
}
#end
