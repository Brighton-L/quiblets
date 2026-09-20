extends Node3D

# A recipe-coloured broth and deterministic garnish, fitted inside the pot rim.
func setup(recipe:Dictionary,bounds:AABB)->void:
 var surface_size:=Vector2(bounds.size.x,bounds.size.z)*.84
 position=Vector3(bounds.get_center().x,bounds.end.y-.06,bounds.get_center().z)
 var broth:=MeshInstance3D.new();broth.name="Broth"
 var mesh:=BoxMesh.new();mesh.size=Vector3(surface_size.x,.035,surface_size.y);broth.mesh=mesh
 var material:=StandardMaterial3D.new();material.albedo_color=recipe.color;material.roughness=.3;broth.material_override=material;add_child(broth)
 var rng:=RandomNumberGenerator.new();rng.seed=hash(str(recipe.name))
 var palette:Array[Color]=[Color("#f4d389"),Color("#82a746"),Color(recipe.color).lightened(.28)]
 if recipe.need.has("spicy"):palette[0]=Color("#de5139")
 if recipe.need.has("fungus") or recipe.need.has("savory"):palette[1]=Color("#c7ac83")
 if recipe.need.has("sweet"):palette[1]=Color("#b85785")
 if recipe.need.has("salty"):palette[0]=Color("#eee4be")
 for i in 16:
  var chunk:=MeshInstance3D.new();chunk.name="Garnish%d"%i
  var chunk_size:=rng.randf_range(.07,.14)
  chunk.mesh=GameData.rounded_box(Vector3(chunk_size,chunk_size*.45,chunk_size*rng.randf_range(.7,1.5)),.02)
  chunk.position=Vector3(rng.randf_range(-.42,.42)*surface_size.x,.025,rng.randf_range(-.42,.42)*surface_size.y);chunk.rotation.y=rng.randf_range(0,TAU)
  var garnish:=StandardMaterial3D.new();garnish.albedo_color=palette[i%palette.size()];chunk.material_override=garnish;add_child(chunk)
