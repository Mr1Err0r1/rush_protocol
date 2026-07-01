extends Node
## ItemFactory — Null Protocol
## Erstellt dynamisch Item-Instanzen für das Casino-Schmuggel-Szenario.

func create_revolver() -> ItemDefinition:
	var item = ItemDefinition.new()
	item.item_id = &"revolver"
	item.display_name = "Revolver"
	item.category = "weapon"
	item.is_metallic = true
	item.confiscation_chance = 0.8
	item.special_action_id = &"russian_roulette"
	item.suspicion_on_use = 50
	return item

func create_poison_needle() -> ItemDefinition:
	var item = ItemDefinition.new()
	item.item_id = &"poison_needle"
	item.display_name = "Giftnadel"
	item.category = "weapon"
	item.is_metallic = false
	item.confiscation_chance = 0.2
	item.suspicion_on_use = 10
	return item

func create_ai_lens() -> ItemDefinition:
	var item = ItemDefinition.new()
	item.item_id = &"ai_lens"
	item.display_name = "AI Linse"
	item.category = "gadget"
	item.is_metallic = false
	item.confiscation_chance = 0.1
	item.special_action_id = &"predict_outcome"
	return item

func create_fake_id() -> ItemDefinition:
	var item = ItemDefinition.new()
	item.item_id = &"fake_id"
	item.display_name = "Gefälschter Ausweis"
	item.category = "tool"
	item.is_metallic = false
	item.confiscation_chance = 0.3
	return item
