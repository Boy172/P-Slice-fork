package mikolka;

#if macro
class FlxMacro
{
  public static macro function buildFlxBasic():Array<haxe.macro.Expr.Field>
  {
    var pos:haxe.macro.Expr.Position = haxe.macro.Context.currentPos();
    var fields:Array<haxe.macro.Expr.Field> = haxe.macro.Context.getBuildFields();

    for (f in fields)
    {
      if (f.name == "zIndex") return fields;
    }

    fields.push({
      name: "zIndex",
      access: [haxe.macro.Expr.Access.APublic],
      kind: haxe.macro.Expr.FieldType.FVar(macro :Int, macro $v{0}),
      pos: pos,
    });

    return fields;
  }
}
#end
