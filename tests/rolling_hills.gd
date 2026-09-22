extends SceneTree
func _initialize():
 var terrain:=Expedition3D.new()
 terrain.height_cols=121;terrain.height_rows=121
 var samples:=PackedFloat32Array();samples.resize(121*121)
 # A short four-metre hill should become a wide hill, not disappear.
 for z in 121:
  for x in 121:
   var radius:=Vector2(x-60,z-60).length()/3.0
   samples[z*121+x]=3.0*(1.0-smoothstep(1.5,2.5,radius))
 var shaped:=terrain.shape_rolling_hills(samples)
 var peak:float=shaped[60*121+60]
 assert(peak>2.7,"Broadening must retain at least 90% of the hill height")
 assert(shaped[60*121+66]>peak*.9,"Hill must have a long elevated top")
 assert(shaped[60*121+75]>0.0,"Hill must have a wider shoulder")
 assert(shaped[60*121+90]<.01,"Distant low ground must remain low")
 var steepest:=0.0
 for x in range(1,121):steepest=maxf(steepest,absf(shaped[60*121+x]-shaped[60*121+x-1])*3.0)
 assert(steepest<1.0,"Slopes should stay gradual")
 print("Rolling hills: retained peak=",peak,"m; broad top, gradual shoulders and low ground passed")
 terrain.free();quit()
