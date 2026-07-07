extends Control
class_name SoloCharacterSelect


@onready var mafia_btn: Button = $VBoxContainer/MafiaBoss
@onready var assassin_btn: Button = $VBoxContainer/Assassin
@onready var millionaire_btn: Button = $VBoxContainer/Millionaire
@onready var agent_btn: Button = $VBoxContainer/Agent
@onready var citizen_btn: Button = $VBoxContainer/Citizen

@onready var status: Label = $VBoxContainer/Status

@onready var start_btn: Button = $VBoxContainer/StartButton
@onready var back_btn: Button = $VBoxContainer/BackButton


var player_name := "Spieler"
var difficulty := 1

var character_selected := false


func _ready():

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	start_btn.disabled = true


	mafia_btn.text = "Mafia Boss"

	assassin_btn.text = "Assassin (GESPERRT)"
	millionaire_btn.text = "Millionär (GESPERRT)"
	agent_btn.text = "Agent (GESPERRT)"
	citizen_btn.text = "Bürger (GESPERRT)"


	assassin_btn.disabled = true
	millionaire_btn.disabled = true
	agent_btn.disabled = true
	citizen_btn.disabled = true


	mafia_btn.pressed.connect(_select_mafia)

	start_btn.pressed.connect(_start_game)

	back_btn.pressed.connect(_go_back)

	status.text = "Bitte Mafia Boss auswählen."


func setup(name:String,diff:int):

	player_name = name
	difficulty = diff


func _select_mafia():

	character_selected = true

	start_btn.disabled = false

	status.text = "Mafia Boss ausgewählt."


func _start_game():

	GameManager.start_solo(
		player_name,
		difficulty
	)


func _go_back():

	get_tree().change_scene_to_file(
		"res://scenes/world/main_menu.tscn"
	)
