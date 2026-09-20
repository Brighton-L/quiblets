extends SceneTree
func _initialize():call_deferred("run")
func run():
 var e:=Expedition3D.new();root.add_child(e);e.set_process(false);e.field_rect=Rect2i(-12,-12,25,25)
 # A U-shaped wall requires going away from the destination before turning back.
 for x in range(-10,11):
  for y in range(-10,11):
   if (x in [-3,3] and y>=-3 and y<=5) or (y==-3 and x>=-3 and x<=3):continue
   e.walkable[Vector2i(x,y)]=true
 var start:=Vector2(0,0);var goal:=Vector2(0,-6)
 var path:=e.find_path(start,goal)
 assert(path.size()>2 and not e.line_walkable(start,goal))
 var previous:=start;var went_around:=false
 for step in path:
  var point:=Vector2(step.x,step.z)
  assert(e.line_walkable(previous,point),"Every bend must be safe for the actor's width")
  if point.y>5:went_around=true
  previous=point
 assert(went_around and previous==goal)
 # A tight L: don't skip the corner from 0.5 units away.
 e.walkable.clear()
 for x in range(0,5):e.walkable[Vector2i(x,0)]=true
 for y in range(0,5):e.walkable[Vector2i(4,y)]=true
 var actor:=QuibletActor3D.new();actor.setup(GameData.make_quiblet(0,5));e.add_child(actor);actor.set_physics_process(false)
 actor.position=Vector3(3.5,0,0);actor.command_path.assign([Vector3(4,0,4)])
 assert(not actor.next_path_segment_clear())
 actor.position=Vector3(4,0,0);assert(actor.next_path_segment_clear())
 var bent:=e.find_path(Vector2.ZERO,Vector2(4,4));assert(bent.size()>=2)
 # Touching blocked corners cannot be crossed diagonally.
 e.walkable.clear();e.walkable[Vector2i.ZERO]=true;e.walkable[Vector2i.ONE]=true
 assert(e.find_path(Vector2.ZERO,Vector2.ONE).is_empty())
 print("Bent routes around U-walls, safe L-turns and blocked diagonal corners passed")
 e.free();await process_frame;quit()
