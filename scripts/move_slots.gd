extends RefCounted

const MAX_TOTAL_SLOTS_PER_MOVE:=8
const MAX_TRANSFERRED_SLOTS_PER_MOVE:=4
const NATIVE:="NATIVE"
const CRYSTAL:="CRYSTAL"

# Slot identity belongs to a move entry, not its name or position in the moveset.
# Retraining and reordering preserve that identity. Legacy counts have no origin
# history, so their existing slots are initialized as native/home slots once.
static func ensure(q:Dictionary)->void:
 # Retired crystallization penalties no longer affect development.
 q.erase("skipped_development_rolls")
 var used:Array=[]
 for move in q.moves:
  if move.has("move_id"):used.append(str(move.move_id))
 var next_id:=int(q.get("next_move_id",0))
 for move in q.moves:
  if not move.has("move_id"):
   while used.has("move_%d"%next_id):next_id+=1
   move.move_id="move_%d"%next_id;used.append(move.move_id);next_id+=1
  if not move.has("slot_data"):
   move.slot_data=[]
   for i in maxi(0,int(move.get("slots",0))):
    move.slot_data.append({"origin":NATIVE,"home_move_id":move.move_id,"current_move_id":move.move_id})
  move.slots=move.slot_data.size()
  for slot in move.slot_data:slot.current_move_id=move.move_id
 q.next_move_id=next_id

static func transferred(move:Dictionary)->int:
 var result:=0
 for slot in move.slot_data:
  if str(slot.home_move_id)!=str(move.move_id):result+=1
 return result

static func add_slot(q:Dictionary,index:int,origin:String)->bool:
 ensure(q)
 if index<0 or index>=q.moves.size() or origin not in [NATIVE,CRYSTAL]:return false
 var move:Dictionary=q.moves[index]
 if int(move.slots)>=MAX_TOTAL_SLOTS_PER_MOVE:return false
 move.slot_data.append({"origin":origin,"home_move_id":move.move_id,"current_move_id":move.move_id})
 move.slots=move.slot_data.size()
 return true

static func transfer_problem(q:Dictionary,source:int,target:int,slot_index:int)->String:
 ensure(q)
 if source<0 or source>=q.moves.size() or target<0 or target>=q.moves.size() or source==target:return "Choose two different moves."
 var donor:Dictionary=q.moves[source];var receiver:Dictionary=q.moves[target]
 if slot_index<0 or slot_index>=int(donor.slots):return "Choose a slot to transfer."
 if int(donor.slots)<=1:return "A donating move must keep at least one slot."
 if int(receiver.slots)>=MAX_TOTAL_SLOTS_PER_MOVE:return "A move can have at most 8 slots."
 if str(donor.slot_data[slot_index].home_move_id)!=str(receiver.move_id) and transferred(receiver)>=MAX_TRANSFERRED_SLOTS_PER_MOVE:return "A move can receive at most 4 transferred slots."
 return ""

# Callers return any fitted stone before moving/removing its slot.
static func transfer(q:Dictionary,source:int,target:int,slot_index:int)->bool:
 if transfer_problem(q,source,target,slot_index)!="":return false
 var donor:Dictionary=q.moves[source];var receiver:Dictionary=q.moves[target]
 if slot_index<donor.stones.size() and not str(donor.stones[slot_index]).is_empty():return false
 var slot:Dictionary=donor.slot_data[slot_index]
 donor.slot_data.remove_at(slot_index)
 if slot_index<donor.stones.size():donor.stones.remove_at(slot_index)
 slot.current_move_id=receiver.move_id;receiver.slot_data.append(slot)
 donor.slots=donor.slot_data.size();receiver.slots=receiver.slot_data.size()
 return true

# Picks are [move index, slot index]. Reject duplicates/stale selections atomically.
static func quote(q:Dictionary,picks:Array,full_extraction:=false)->Dictionary:
 ensure(q)
 var seen:={};var native:=0;var crystal:=0
 for pick in picks:
  if not pick is Array or pick.size()!=2:return {"error":"Invalid slot selection."}
  var mi:=int(pick[0]);var si:=int(pick[1]);var key:="%d:%d"%[mi,si]
  if mi<0 or mi>=q.moves.size() or si<0 or si>=int(q.moves[mi].slots) or seen.has(key):return {"error":"The slot selection changed. Please select again."}
  seen[key]=true
  if q.moves[mi].slot_data[si].origin==CRYSTAL:crystal+=1
  else:native+=1
 if not full_extraction and (picks.is_empty() or native%2!=0):return {"error":"Select Native slots in pairs. Crystal slots refund individually."}
 return {"error":"","native":native,"refunds":crystal,"created":native/2,"total":crystal+native/2,"unused_native":native%2}

static func all_slots(q:Dictionary)->Array:
 ensure(q)
 var picks:Array=[]
 for mi in q.moves.size():
  for si in int(q.moves[mi].slots):picks.append([mi,si])
 return picks

static func extract(q:Dictionary,picks:Array,full_extraction:=false)->Dictionary:
 var result:=quote(q,picks,full_extraction)
 if result.error!="":return result
 for pick in picks:
  var move:Dictionary=q.moves[int(pick[0])];var si:=int(pick[1])
  if si<move.stones.size() and not str(move.stones[si]).is_empty():return {"error":"Return fitted stones before extracting slots."}
 var ordered:=picks.duplicate(true)
 ordered.sort_custom(func(a,b):return int(a[0])>int(b[0]) or (a[0]==b[0] and int(a[1])>int(b[1])))
 for pick in ordered:
  var move:Dictionary=q.moves[int(pick[0])];var si:=int(pick[1])
  move.slot_data.remove_at(si)
  if si<move.stones.size():move.stones.remove_at(si)
  move.slots=move.slot_data.size()
 return result
