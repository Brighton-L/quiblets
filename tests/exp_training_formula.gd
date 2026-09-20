extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var trainee:=GameData.make_quiblet(2,10)
 var same:=GameData.make_quiblet(2,100)
 assert(GameData.exp_training_reward(trainee,[same])==88090,"Lv10 + Lv100 same species reaches approximately Lv83.8")
 trainee.level=95;same.level=95
 assert(GameData.exp_training_reward(trainee,[same])==6514,"Normal-training example must round 6513.6 to 6514")
 # Strongest relationship only, using normal training at equal levels.
 for pair in [[2,6514],[3,6301],[4,6018],[6,5664]]:
  assert(GameData.exp_training_reward(trainee,[GameData.make_quiblet(pair[0],95)])==pair[1])
 trainee.level=92;same.level=100
 assert(GameData.exp_training_reward(trainee,[same])==6864,"Exact effective target uses normal training")
 trainee.level=10;same.level=100;trainee.exp=123;same.exp=456
 var original:=trainee.duplicate(true);var helper_original:=same.duplicate(true)
 assert(GameData.exp_training_reward(trainee,[same,same,same,same])==352360,"All four rewards use starting Lv10")
 assert(GameData.exp_training_reward(trainee,[same,same,same,same,same])==352360,"At most four helpers")
 assert(GameData.exp_training_reward(trainee,[])==0)
 assert(trainee==original and same==helper_original,"Reward calculations do not mutate participants")
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 assert(game.save_access_blocked())
 game.roster.clear();game.roster.append(trainee);game.roster.append(same)
 game.training_trainee=0;game.training_helpers.assign([1,-1,-1,-1]);game.training_mode="exp"
 var before:=GameData.total_exp(trainee);var preview:Dictionary=game.training_exp_preview()
 assert(preview.level==83 and preview.exp==1781,"Catch-up keeps the starting XP-bar progress")
 game.grant_training_exp(trainee,GameData.exp_training_reward(trainee,[same]))
 assert(trainee.level==preview.level and trainee.exp==preview.exp)
 assert(GameData.total_exp(trainee)==before+88090)
 game.show_training();await process_frame
 assert(game.content.find_child("TrainingBeforeXP",true,false)!=null and game.content.find_child("TrainingAfterXP",true,false)!=null)
 print("EXP training examples, relationships, boundary, four-helper snapshot, XP preservation and UI preview passed")
 game.queue_free();await process_frame;quit()
