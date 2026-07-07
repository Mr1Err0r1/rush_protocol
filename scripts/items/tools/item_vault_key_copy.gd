extends ItemDefinition
## class_name ItemVaultKeyCopy
## Vault-Schlüssel-Kopie — Null Protocol
## Gibt dem Träger Zugang zum Vault-Korridor und Vault,
## ohne vorher den Boss besiegen zu müssen.
## Seltenster und wertvollster Gegenstand — kann nur im Backroom
## gefunden oder vom Boss gestohlen werden (nicht einschmuggeln).

func _init() -> void:
	item_id             = &"vault_key_copy"
	display_name        = "Vault-Schlüssel (Kopie)"
	description         = "Eine perfekte Kopie des Casino-Hauptschlüssels. Jemand hatte Zugang zur Schmiede. Wer diesen Schlüssel hat, braucht keinen Boss mehr."
	category            = "tool"
	item_type           = "access"
	can_be_smuggled     = false   # Zu wertvoll — wird nur ingame gefunden
	detection_weight    = 8
	confiscation_chance = 0.9
	requires_target     = false
	can_target_self     = true
	max_uses_per_match  = 1
	suspicion_on_use    = 0
	usable_in_zones     = ["backroom", "vault_corridor"]


func execute_effect(user_state: PlayerState, _target_state: PlayerState,
		_match_ctrl: Node) -> Dictionary:
	if user_state.has_vault_key:
		return {"success": false, "reason": "already_have_key"}

	user_state.has_vault_key = true
	EventBus.ui_toast.emit("🔑 Vault-Schlüssel aktiviert!", "win", 3.0)

	return {
		"success":      true,
		"vault_access": true,
		"sound_key":    "item_generic",
	}
