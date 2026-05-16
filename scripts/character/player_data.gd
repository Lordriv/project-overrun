extends Node
# AutoLoad: PlayerData
# Persistent player stats/equipment/cosmetics that survive scene changes.
# Lobby and Mission scenes both read from / write to this.
#
# Currently a scaffold - real fields/load/save logic to be added as
# the related systems (equipment, cosmetics, progression) come online.

# === Health/Shield ===
# These get synced with HealthComponent on scene load and back when leaving
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_shield: float = 75.0
var max_shield: float = 75.0
var tutorial_completed: bool = false

# === Equipment slots (placeholders for later) ===
# var armor_equipped: Resource = null
# var primary_weapon: Resource = null
# var secondary_weapon: Resource = null

# === Cosmetics (placeholders for later) ===
# var character_color: Color = Color.WHITE
# var helmet_id: String = ""
# var skin_id: String = "default"

# === Progression ===
var max_wave_reached: int = 0
# var credits: int = 0
# var level: int = 1
# var xp: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

# Called by Character on _exit_tree to save state before scene change
func save_from_character(character: Node):
	var health = character.get_node_or_null("HealthComponent")
	if health:
		current_hp = health.current_hp
		current_shield = health.current_shield
	# Future: save equipment, cosmetics, position, etc.

# Called by Character on _ready to apply persisted state to fresh node
func apply_to_character(character: Node):
	var health = character.get_node_or_null("HealthComponent")
	if health:
		# Only override if PlayerData has been initialized (HP > 0)
		# Allows fresh starts without forcing 0 HP
		if current_hp > 0:
			health.current_hp = current_hp
		if current_shield > 0:
			health.current_shield = current_shield
	# Future: apply equipment, cosmetics, etc.
