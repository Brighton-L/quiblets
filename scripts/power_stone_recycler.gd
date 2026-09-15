extends ColorRect

const MAX_SELECTION:=15
var game:Node
var selected:Dictionary={}
var count_label:Label
var confirm:Button

func setup(owner_game:Node)->void:
 game=owner_game;name="PowerStoneRecycler";color=Color(0,0,0,.72);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP;z_index=100
 var menu:Panel=game.panel(Rect2(90,60,1100,600),Color("#fffdf7"),20);add_child(menu)
 game.label(menu,"RECYCLE POWER STONES",Vector2(24,20),24,GameData.COLORS.ink,true)
 game.label(menu,"Select up to 15 unequipped stones. Click a selected stone to deselect it.",Vector2(24,57),14,GameData.COLORS.muted,false,HORIZONTAL_ALIGNMENT_LEFT,1052)
 var scroll:=ScrollContainer.new();scroll.position=Vector2(24,98);scroll.size=Vector2(1052,390);menu.add_child(scroll)
 var grid:=GridContainer.new();grid.columns=10;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 for index in game.power_stone_inventory.size():
  var stone:=GameData.normalize_power_stone(game.power_stone_inventory[index])
  var card:Button=game.add_button(grid,"",Vector2.ZERO,Vector2(96,112),func():pass,"plain");card.name="RecycleCandidate%d"%index;card.custom_minimum_size=Vector2(96,112);card.toggle_mode=true
  var icon=game.add_power_stone_icon(card,stone,Vector2(16,6),Vector2(64,64));card.tooltip_text=icon.tooltip_text
  var detail:Label=game.label(card,"%s • T%d\n+%d"%[stone.type,stone.tier,stone.power],Vector2(3,73),11,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_CENTER,90);detail.size.y=34;detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
  card.toggled.connect(func(pressed:bool):
   if pressed and not selected.has(index) and selected.size()>=MAX_SELECTION:
    card.set_pressed_no_signal(false);game.toast("Select up to 15 Power Stones.",GameData.COLORS.coral);return
   if pressed:selected[index]=stone.duplicate(true)
   else:selected.erase(index)
   game.style_button(card,"selected" if pressed else "plain");refresh())
 if game.power_stone_inventory.is_empty():game.label(menu,"No unequipped Power Stones to recycle.",Vector2(24,130),18,GameData.COLORS.muted)
 count_label=game.label(menu,"",Vector2(24,509),15,GameData.COLORS.ink,true,HORIZONTAL_ALIGNMENT_LEFT,590)
 game.add_button(menu,"CANCEL",Vector2(670,514),Vector2(170,54),queue_free,"plain").name="CancelBatchRecycle"
 confirm=game.add_button(menu,"REVIEW",Vector2(860,514),Vector2(216,54),func():game.request_recycle_batch(selected.duplicate(true)),"coral");confirm.name="ReviewBatchRecycle"
 refresh()

func refresh()->void:
 var ingredients:=0
 for stone in selected.values():ingredients+=game.power_stone_recycle_count(stone)
 count_label.text="%d / 15 selected • Returns %d ingredients"%[selected.size(),ingredients]
 confirm.disabled=selected.is_empty()
