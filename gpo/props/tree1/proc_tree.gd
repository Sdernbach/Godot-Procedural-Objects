@tool
class_name ProcTree
extends Sprite2D

@export var tree_seed: int = 0
@export_group("Trunk")
@export var trunk_height: float = 100.0
@export var trunk_width: float = 15.0
@export var trunk_curve: float = 0.5
@export var trunk_color1: Color = Color(0.5, 0.25, 0.1)
@export var trunk_color2: Color = Color(0.3, 0.15, 0.05)
@export_group("Branches")
@export var branch_count: int = 5
@export var branch_length: float = 50.0
@export var branch_curve: float = 0.3
@export var branch_angle: float = 60.0 # Degrees
@export var branch_recursion_factor: float = 0.7
@export var guarantee_initial_branches: bool = true
@export_group("Foliage")
@export var foliage_color1: Color = Color(0.1, 0.5, 0.1)
@export var foliage_color2: Color = Color(0.1, 0.3, 0.1)
@export_group("")
@export_tool_button("Redraw") var redraw_tool_button = draw_to_texture
@export_tool_button("Regenerate") var regenerate_tool_button = generate

var trunk : Curve2D
var branches : Array[Curve2D] = []
var foliage = []
var generated_image: Image
var _image_offset: Vector2

func _ready() -> void:
    generate()

func draw_to_texture() -> void:
    var image_size = Vector2i(200, 200)
    _image_offset = Vector2i(image_size.x / 2, image_size.y) #Place origin at the bottom center of the image
    generated_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
    generated_image.fill(Color.TRANSPARENT)

    draw_trunk()
    draw_branches()
    draw_foliage()
    texture.set_image(generated_image)

func generate() -> void:
    if tree_seed != 0:
        seed(tree_seed)
    
    # Build Trunk
    generate_trunk()
    # Build Branches
    branches.clear()
    generate_branches()
    # Build Foliage
    foliage.clear()
    generate_foliage()
    draw_to_texture()

func generate_trunk() -> void:
    var trunk_start = Vector2(0,0)
    var trunk_end = Vector2(0, -trunk_height)

    # Create a new Curve2D for the trunk
    trunk = Curve2D.new()
    
    # Add starting point
    trunk.add_point(trunk_start)
    
    # Calculate curve control points based on trunk_curve
    var curve_offset = Vector2(randf_range(-trunk_curve * 50, trunk_curve * 50), 0)
    var mid_point = (trunk_start + trunk_end) * 0.5 + curve_offset
    
    # Add middle point for curvature if there's significant curve
    if trunk_curve > 0.1:
        var in_control = Vector2(0, trunk_height * 0.2)
        var out_control = Vector2(0, -trunk_height * 0.2)
        trunk.add_point(mid_point, in_control, out_control)
    
    # Add ending point
    var end_in_control = Vector2(randf_range(-trunk_curve * 20, trunk_curve * 20), trunk_height * 0.3)
    trunk.add_point(trunk_end, end_in_control)

func generate_branches() -> void:
    for i in range(branch_count):
        generate_branch_recursive(trunk, 1.0)

func generate_branch_recursive(parent: Curve2D, recursion_factor: float) -> void:
    var branch = Curve2D.new()

    # Start branch from random point on the parent curve
    #Bias branches towards the top of the trunk/parent branch
    var point_index = Geometry_Utils.random_beta_distribution(4.0, 2.0)
    var baked_transform: Transform2D = Geometry_Utils.uniform_point_along_curve(parent, point_index)
    var branch_start = baked_transform.get_origin()
    branch.add_point(branch_start)

    # Calculate branch end position based on length and angle
    var branch_start_angle = baked_transform.get_rotation()
    #Angle branch away from parent between 20d and branch_angle
    var angle_diff = deg_to_rad(randf_range(20, branch_angle) * (-1 if randf() < 0.5 else 1))
    var angle = branch_start_angle + angle_diff
    # Branch length is a random factor of the base branch length reduced by the recursion factor
    var current_branch_length = (branch_length * (randf()*0.4+0.6)) * recursion_factor
    #Branch end is calculated from the start position, angle, and length
    var branch_end = branch_start + (current_branch_length * Vector2(cos(angle), sin(angle)))

    # Calculate curve control points based on branch_curve
    var curve_offset = Vector2(randf_range(-branch_curve * 50, branch_curve * 50), 0)
    var mid_point = (branch_start + branch_end) * 0.5 + curve_offset

    # Add middle point for curvature if there's significant curve
    if branch_curve > 0.1:
        var in_control = Vector2(0, branch_length * 0.2)
        var out_control = Vector2(0, -branch_length * 0.2)
        branch.add_point(mid_point, in_control, out_control)

    # Add ending point
    var end_in_control = Vector2(randf_range(-branch_curve * 20, branch_curve * 20), branch_length *  recursion_factor * 0.3)
    branch.add_point(branch_end, end_in_control)

    # Recursively generate child branches
    branches.append(branch)
    for i in range(branch_count):
        recursion_factor *= branch_recursion_factor
        if randf() < recursion_factor:
            generate_branch_recursive(branch, recursion_factor)

func generate_foliage() -> void:
    pass

func draw_trunk() -> void:
    var curve_points = trunk.tessellate()
    for idx in len(curve_points) - 1:
        var start = curve_points[idx] + _image_offset
        var end = curve_points[idx + 1] + _image_offset
        Drawing.draw_line_on_image(generated_image, start, end, trunk_color1, 
            lerp(trunk_width, trunk_width * 0.4, float(idx)/len(curve_points)),
            lerp(trunk_width, trunk_width * 0.4, float(idx+1)/len(curve_points)))

func draw_branches() -> void:
    for branch in branches:
        var curve_points = branch.tessellate()
        for idx in len(curve_points) - 1:
            var start = curve_points[idx] + _image_offset
            var end = curve_points[idx + 1] + _image_offset
            Drawing.draw_line_on_image(generated_image, start, end, trunk_color2, 
                lerp(trunk_width * 0.4,trunk_width * 0.1,float(idx)/len(curve_points)), 
                lerp(trunk_width * 0.4,trunk_width * 0.1,float(idx+1)/len(curve_points)))

func draw_foliage() -> void:
    # Placeholder for foliage drawing logic
    pass
