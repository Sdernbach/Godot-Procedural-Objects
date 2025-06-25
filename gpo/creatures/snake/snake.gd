@tool
class_name Snake
extends CharacterBody2D

@export_tool_button("Regenerate") var regenerate_tool_button = construct_snake

@export var random_seed: int = 0
@export var num_segments: int = 10
@export var segment_length: float = 20.0

@export var apply_camoflage: bool = false
@export var colors: Array[Color] = [
    Color(1, 0, 0),  # red
    Color(1, 1, 0),  # yellow
    Color(0, 0, 1)   # blue
]

var snake_body: Line2D

func construct_snake() -> void:
    if random_seed != 0:
        RandomNumberGenerator.new().seed = random_seed
    else:
        randomize()

    if apply_camoflage:
        colors = Drawing_Utils.get_most_common_colors(get_viewport().get_texture(), 3, 16)

    $SnakeBody.construct_body(num_segments, segment_length, colors)

func _ready() -> void:
    # This function is called when the node is added to the scene.
    construct_snake()