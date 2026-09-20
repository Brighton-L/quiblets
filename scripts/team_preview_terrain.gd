extends Node3D
# A separate meadow clearing for formation previews.
func terrain_height_at(point:Vector2)->float:
 var edge:=smoothstep(3.5,10.0,point.length())
 return edge*(.8+.45*sin(point.x*.45)+.3*cos(point.y*.55))

func terrain_coordinate(index:float)->float:
 # Keep the clearing detailed and use broad cells for the distant surroundings.
 return index*.5 if absf(index)<=32.0 else signf(index)*(16.0+(absf(index)-32.0)*8.0)

func build()->void:
 var biome:=GameData.expedition_biome(0)
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-40,40):
  for z in range(-40,40):
   for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
    var point:=Vector2(terrain_coordinate(x+offset.x),terrain_coordinate(z+offset.y))
    var height:=terrain_height_at(point)
    var color:Color=Color(biome.ground).lerp(Color(biome.path),.18*(1.0-smoothstep(2.0,4.0,point.length())))
    color=color.lightened(.035*sin(point.x*2.2)*cos(point.y*1.7)+height*.035)
    surface.set_color(color.srgb_to_linear());surface.add_vertex(Vector3(point.x,height,point.y))
 surface.generate_normals()
 var ground:=MeshInstance3D.new();ground.name="PreviewMeadow";ground.mesh=surface.commit()
 var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=1.0;ground.material_override=material;add_child(ground)
 var rng:=RandomNumberGenerator.new();rng.seed=7182
 for i in 44:
  var angle:=rng.randf()*TAU;var radius:=rng.randf_range(5.8,13.0);var point:=Vector2(cos(angle),sin(angle))*radius
  var kind:String=["tree","bush","flower","boulder","grass"][i%5]
  var prop:=ExpeditionProp3D.new();prop.setup(kind,Vector2i.ZERO,biome,1,rng);prop.bears_fruit=false;prop.set_process(false)
  prop.position=Vector3(point.x,terrain_height_at(point),point.y);prop.scale=Vector3.ONE*rng.randf_range(.55,.85);add_child(prop)
