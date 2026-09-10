class_name MoveBehaviors
extends RefCounted

# Gameplay definitions, separate from names, artwork, and base damage/cooldowns.
# Distances are world units; times are seconds. Each named move has an explicit
# delivery method and effect, rather than falling back to a generic attack.
const PROFILES:={
	"Water Shot":{"mode":"projectile","speed":16.0,"radius":.18},
	"Water Jet":{"mode":"beam","duration":1.8,"tick":.2,"radius":.32},
	"Bubble Shot":{"mode":"projectile","speed":4.0,"radius":.42,"splash":1.25,"knockback":.45},
	"Bubble Burst":{"mode":"area","anchor":"self","radius":2.7,"visual":"bubbles"},
	"Bubble Trap":{"mode":"projectile","speed":5.0,"radius":.4,"status":"bubble","status_duration":3.5},
	"Bubble Shield":{"mode":"buff","status":"shield","duration":6.0,"amount":.35},
	"Big Bubble":{"mode":"wave","speed":2.5,"radius":1.1,"width":2.2,"carry":true,"knockback":.6,"visual":"bubble"},
	"Splash Dash":{"mode":"dash","speed":12.0,"radius":.65,"physical":true},
	"Backwash":{"mode":"cone","angle":.65,"knockback":2.6},
	"Water Burst":{"mode":"area","anchor":"self","radius":3.0,"knockback":.5},
	"Rain Drop":{"mode":"area","anchor":"target","radius":1.7,"delay":.85,"visual":"rain"},
	"Hydro Shot":{"mode":"projectile","speed":14.0,"radius":.5,"pierce":true},
	"Breaker":{"mode":"cone","angle":.9,"delay":.35,"knockback":1.1,"visual":"wave"},
	"Riptide":{"mode":"wave","speed":3.6,"width":1.8,"radius":.55,"carry":true,"knockback":.5},
	"Undertow":{"mode":"area","anchor":"self","radius":3.2,"pull":2.4},
	"Whirlpool":{"mode":"field","anchor":"self_follow","radius":3.0,"duration":3.0,"tick":.35,"pull":.45,"swirl":.6},
	"Wave Rush":{"mode":"dash","speed":8.0,"radius":1.2,"knockback":1.0,"physical":true,"visual":"wave"},
	"Tidal Wave":{"mode":"wave","speed":4.5,"width":5.0,"radius":.65,"carry":true,"knockback":.8},
	"Water Spout":{"mode":"area","anchor":"target","radius":1.0,"delay":.4,"launch":1.8,"visual":"pillar"},
	"Spray":{"mode":"cone","angle":1.15},
	"Downpour":{"mode":"field","anchor":"target","radius":2.7,"delay":.4,"duration":4.0,"tick":.4,"visual":"rain"},
	"Tsunami":{"mode":"wave","speed":4.0,"width":8.0,"radius":1.0,"carry":true,"knockback":1.2},
	"Leaf Shot":{"mode":"projectile","speed":18.0,"radius":.18,"visual":"leaf"},
	"Vine Whip":{"mode":"cone","angle":1.15,"physical":true,"visual":"vine"},
	"Vine Spear":{"mode":"line","radius":.3,"physical":true,"visual":"vine"},
	"Vine Grab":{"mode":"projectile","speed":12.0,"radius":.22,"pull":2.8,"visual":"vine"},
	"Rootbind":{"mode":"area","anchor":"target","radius":.7,"status":"root","status_duration":3.0,"visual":"roots"},
	"Thorn Burst":{"mode":"area","anchor":"target","radius":1.9,"delay":.35,"visual":"thorns"},
	"Sprout":{"mode":"area","anchor":"target","radius":.7,"delay":.3,"launch":.8,"visual":"plant"},
	"Seed Pop":{"mode":"projectile","speed":8.0,"radius":.2,"splash":1.5,"fuse":.65,"visual":"seed"},
	"Healing Bloom":{"mode":"heal_field","anchor":"self","radius":3.0,"duration":4.0,"tick":.5,"amount":.055,"visual":"flower"},
	"Pollen Puff":{"mode":"heal","radius":3.0,"amount":.25},
	"Soothing Scent":{"mode":"cleanse"},
	"Overgrowth":{"mode":"area","anchor":"target","radius":3.3,"delay":.5,"knockback":2.0,"visual":"plant"},
	"Spore Cloud":{"mode":"field","anchor":"target","radius":2.2,"duration":3.5,"tick":.5,"status":"stun","status_duration":1.0,"visual":"cloud"},
	"Thorn Armor":{"mode":"buff","status":"thorns","duration":5.0,"amount":.4},
	"Seed Mine":{"mode":"mine","anchor":"self","radius":2.0,"trigger_radius":1.3,"delay":.45,"duration":10.0,"visual":"seed"},
	"Root Slam":{"mode":"area","anchor":"target","radius":2.5,"delay":.85,"physical":true,"knockback":.7,"visual":"root_slam"},
	"Vine Swing":{"mode":"dash","speed":15.0,"radius":.45,"physical":true,"stop_at_target":true,"visual":"vine"},
	"Growth Spurt":{"mode":"buff","status":"growth","duration":6.0,"amount":1.5},
	"Cocoon":{"mode":"buff","status":"cocoon","duration":4.0,"amount":.125},
	"Leech Bloom":{"mode":"projectile","speed":8.0,"radius":.25,"leech":.5,"status":"leech","status_duration":3.0,"visual":"flower"},
	"Last Bloom":{"mode":"heal","radius":4.5,"amount":.6,"low_hp":.35},
	"Fireball":{"mode":"projectile","speed":11.0,"radius":.3,"splash":1.6},
	"Flame Burst":{"mode":"cone","angle":.6},
	"Spark Burst":{"mode":"area","anchor":"self","radius":2.6},
	"Flare":{"mode":"area","anchor":"self","radius":3.0,"knockback":2.0},
	"Flame Dash":{"mode":"dash","speed":12.0,"radius":.75,"physical":true,"burn":3.0},
	"Blazing Rush":{"mode":"dash","speed":9.0,"radius":1.1,"physical":true,"knockback":1.8,"burn":3.0},
	"Fire Trail":{"mode":"dash","speed":10.0,"radius":.7,"physical":true,"trail":3.5,"burn":3.0},
	"Flame Wave":{"mode":"wave","speed":5.0,"width":4.5,"radius":.6,"burn":3.0},
	"Firestorm":{"mode":"field","anchor":"target","radius":3.2,"duration":3.0,"tick":.45,"burn":3.0,"visual":"eruptions"},
	"Inferno":{"mode":"area","anchor":"self","radius":4.8,"delay":.6,"knockback":1.2,"burn":4.0},
	"Flame Pillar":{"mode":"area","anchor":"target","radius":1.15,"delay":.45,"burn":3.0,"visual":"pillar"},
	"Meteor Ember":{"mode":"area","anchor":"target","radius":2.3,"delay":1.0,"burn":3.0,"visual":"meteor"},
	"Flame Spin":{"mode":"field","anchor":"self_follow","radius":2.6,"duration":2.4,"tick":.3,"burn":2.0,"spin":true},
	"Heat Haze":{"mode":"buff","status":"evade","duration":5.0,"amount":.45},
	"Ignite":{"mode":"projectile","speed":12.0,"radius":.22,"burn":4.0,"direct_scale":.2},
	"Fire Mine":{"mode":"mine","anchor":"self","radius":2.3,"trigger_radius":1.3,"delay":.45,"duration":10.0,"burn":3.0,"visual":"ember"},
	"Combust":{"mode":"combust","radius":1.8},
	"Smoke Cloud":{"mode":"field","anchor":"target","radius":2.8,"duration":4.0,"tick":.4,"status":"smoke","status_duration":1.0,"visual":"cloud"},
	"Cauterize":{"mode":"cleanse","self_cost":.06},
	"Firework":{"mode":"firework","anchor":"target","radius":3.2,"delay":.7,"duration":1.2,"tick":.2,"burn":3.0}
}

static func profile(move_name:String)->Dictionary:
	assert(PROFILES.has(move_name),"Missing gameplay definition: "+move_name)
	return PROFILES[move_name].duplicate(true)

static func supports(move_name:String,stone:String)->bool:
	var p:Dictionary=PROFILES[move_name];var mode:String=p.mode
	var support:bool=mode in ["heal","heal_field","buff","cleanse"]
	match stone:
		"echo","rush","link":return true
		"heavy":return mode!="cleanse"
		"reach":return not support and p.get("anchor","") not in ["self","self_follow"]
		"sharing":return support
		"chain","drain":return not support
		"split":return mode in ["projectile","wave","area","field","mine","firework"]
		"seeking":return mode=="projectile" or (mode=="wave" and p.get("visual","")=="bubble")
		"lingering":return p.has("duration") or p.has("burn") or p.has("status_duration") or p.has("trail")
		"blast":return p.has("splash") or mode in ["area","cone","line","wave","field","heal","heal_field","mine","firework"]
		"force":return p.has("knockback") or p.has("pull") or p.has("launch") or p.get("physical",false)
	return false

static func is_support(move_name:String)->bool:
	return PROFILES[move_name].mode in ["heal","heal_field","buff","cleanse"]
