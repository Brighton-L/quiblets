extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var trainee:=GameData.make_quiblet(2,10)
 var same:=GameData.make_quiblet(2,100)
 assert(GameData.exp_training_reward(trainee,[same])==107774,"Lv10 + Lv100 same species reaches approximately Lv92.8")
 trainee.level=95;same.level=95
 assert(GameData.exp_training_reward(trainee,[same])==2605,"Normal-training example must round 2605.44 to 2605")
 # Strongest relationship only, using normal training at equal levels.
 for pair in [[2,2605],[3,2520],[4,2407],[6,2266]]:
  assert(GameData.exp_training_reward(trainee,[GameData.make_quiblet(pair[0],95)])==pair[1])
 # Higher helpers always use catch-up, even just one level above the trainee.
 for example in [[89,101,25795],[4,65,46998],[99,100,2260],[101,89,1892],[100,50,342],[100,10,3]]:
  trainee.level=example[0];same.level=example[1]
  assert(GameData.exp_training_reward(trainee,[same])==example[2],"Gap-based catch-up and cubic normal examples")
 trainee.level=10;same.level=100;trainee.exp=123;same.exp=456
 var original:=trainee.duplicate(true);var helper_original:=same.duplicate(true)
 assert(GameData.exp_training_reward(trainee,[same,same,same,same])==431096,"All four rewards use starting Lv10")
 assert(GameData.exp_training_reward(trainee,[same,same,same,same,same])==431096,"At most four helpers")
 assert(GameData.exp_training_reward(trainee,[])==0)
 assert(trainee==original and same==helper_original,"Reward calculations do not mutate participants")
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 game.roster.clear();game.roster.append(trainee);game.roster.append(same)
 game.training_trainee=0;game.training_helpers.assign([1,-1,-1,-1]);game.training_mode="exp"
 var before:=GameData.total_exp(trainee);var preview:Dictionary=game.training_exp_preview()
 assert(preview.level==92 and preview.exp==1953,"Catch-up keeps the starting XP-bar progress")
 game.grant_training_exp(trainee,GameData.exp_training_reward(trainee,[same]))
 assert(trainee.level==preview.level and trainee.exp==preview.exp)
 assert(GameData.total_exp(trainee)==before+107774)
 game.show_training();await process_frame
 assert(game.content.find_child("TrainingBeforeXP",true,false)!=null and game.content.find_child("TrainingAfterXP",true,false)!=null)
 print("EXP training examples, relationships, boundary, four-helper snapshot, XP preservation and UI preview passed")
 game.queue_free();await process_frame;quit()
