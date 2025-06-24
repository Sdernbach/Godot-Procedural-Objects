@tool
extends CharacterBody2D
class_name Koi

@export_tool_button("Regenerate") var regenerate_tool_button = construct_koi

# Export variables for customization
@export var length: float = 300.0
@export var width_ratio: float = 0.2  # width as a ratio of length
@export var tail_size_ratio: float = 0.4  # tail size as a ratio of length
@export var vertex_resolution = 16  # Number of vertices for curved shapes
@export var pattern_seed: int = 0  # Seed for random pattern generation
@export var alpha_transparency = 1.0
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.ORANGE_RED
@export var spot_color: Color = Color.BLACK

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite : KoiSprite = $KoiSprite

# Node references
var _body: Polygon2D
var _tail: Array[Polygon2D] = []
var _fins: Array[Polygon2D] = []
var _dorsal_fin: Polygon2D
var _eyes: Array[Polygon2D] = []
var _whiskers: Array[Line2D] = []
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var fin_color : Color
var tilemap_viewport = null
var tilemap_texture = null

#Movement Properties
var is_moving := false
@export var move_speed = 200.0
@export var turn_speed = PI

# Animation State properties
enum TurnState {NEUTRAL, SLIGHT_LEFT, LEFT, SLIGHT_RIGHT, RIGHT}
var current_turn_state : TurnState = TurnState.NEUTRAL
var turn_values = {
    TurnState.NEUTRAL: 0.0,
    TurnState.SLIGHT_LEFT: -0.075,
    TurnState.LEFT: -0.15,
    TurnState.SLIGHT_RIGHT: 0.075,
    TurnState.RIGHT: 0.15
}

#Debug properties
var line : Line2D

# Called when the node enters the scene tree for the first time
func _ready():
    primary_color.a = alpha_transparency
    fin_color = primary_color
    fin_color.a *= 0.8
    secondary_color.a = alpha_transparency
    spot_color.a = alpha_transparency

    construct_koi()
    setup_collision_shape()

func generate_frame_for_state(state):
    #Remove old elements
    for child in get_children():
        if child is Polygon2D or child is Line2D:
            child.queue_free()
    
    #Calculate max x value (length of fish)
    var max_x = 0
    for tail in _tail:
        for point in tail.polygon:
            max_x = max(max_x, point.x)
            
    #Deform Fish
    var body_copy = _body.duplicate()
    body_copy = Geometry.apply_bezier_deformation_to_polygon(body_copy, turn_values[state], max_x)
    var bounds = Geometry.get_polygon_bounds(body_copy.polygon)
    var tail_copies = []
    for tail in _tail:
        var tail_copy = tail.duplicate()
        tail_copies.append(tail_copy)
        tail_copy.polygon = Geometry_Utils.apply_bezier_deformation(tail_copy.polygon, turn_values[state], max_x)
        bounds = bounds.merge(Geometry.get_polygon_bounds(tail_copy.polygon))
    var dorsal_copy = _dorsal_fin.duplicate()
    dorsal_copy.polygon = Geometry_Utils.apply_bezier_deformation(dorsal_copy.polygon, turn_values[state], max_x)
    bounds = bounds.merge(Geometry.get_polygon_bounds(dorsal_copy.polygon))
    var fin_copies = []
    for fin in _fins:
        var fin_copy = fin.duplicate()
        fin_copies.append(fin_copy)
        fin_copy.polygon = Geometry_Utils.apply_bezier_deformation(fin_copy.polygon, turn_values[state], max_x)
        bounds = bounds.merge(Geometry.get_polygon_bounds(fin_copy.polygon))
    var eye_copies = []
    for eye in _eyes:
        var eye_copy = eye.duplicate()
        eye_copies.append(eye_copy)
        eye_copy.polygon = Geometry_Utils.apply_bezier_deformation(eye_copy.polygon, turn_values[state], max_x)
        bounds = bounds.merge(Geometry.get_polygon_bounds(eye_copy.polygon))
    var whisker_copies = []
    for whisker in _whiskers:
        var whisker_copy = whisker.duplicate()
        whisker_copies.append(whisker_copy)
        whisker_copy.points = Geometry_Utils.apply_bezier_deformation(whisker_copy.points, turn_values[state], max_x)
        bounds = bounds.merge(Geometry.get_polygon_bounds(whisker_copy.points))
    bounds.grow(5)
    
    # Create a viewport for rendering
    var viewport = SubViewport.new()
    viewport.size = Vector2(ceil(bounds.size.x), ceil(bounds.size.y))
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    
    var offset = -bounds.get_center() + Vector2(viewport.size / 2)
    
    # Create duplicates of all components and add them to the viewport
    # Fins
    for fin_copy in fin_copies:
        fin_copy.position += offset
        viewport.add_child(fin_copy)
    
    # Tail parts
    for tail_copy in tail_copies:
        tail_copy.position += offset
        viewport.add_child(tail_copy)
    
    # Body
    body_copy.position += offset
    viewport.add_child(body_copy)
    
    #Debug Line
    if line:
        var line_copy = line.duplicate()
        line_copy.position = line.position + offset
        viewport.add_child(line_copy)
    
    # Whiskers
    for whisker_copy in whisker_copies:
        whisker_copy.position += offset
        viewport.add_child(whisker_copy)
    
    # Eyes
    for eye_copy in eye_copies:
        eye_copy.position += offset
        viewport.add_child(eye_copy)
    
    # Dorsal fin
    dorsal_copy.position += offset
    viewport.add_child(dorsal_copy)
    
    # Add viewport to scene tree temporarily
    get_tree().root.add_child.call_deferred(viewport)
    # Wait for the viewport to render
    await get_tree().process_frame
    await get_tree().process_frame

    # Get the texture
    var texture = viewport.get_texture().get_image()
    var img_texture = ImageTexture.create_from_image(texture)
    
    # Clean up
    viewport.queue_free()
    
    return img_texture

func calculate_bounds():
    var bounds = Rect2()
    var first = true
    
    # Check body
    if is_instance_valid(_body):
        var body_bounds = Geometry.get_polygon_bounds(_body.polygon)
        if first:
            bounds = body_bounds
            first = false
        else:
            bounds = bounds.merge(body_bounds)
    
    # Check fins
    for fin in _fins:
        if is_instance_valid(fin):
            var fin_bounds = Geometry.get_polygon_bounds(fin.polygon)
            if first:
                bounds = fin_bounds
                first = false
            else:
                bounds = bounds.merge(fin_bounds)
    
    # Check tail
    for tail in _tail:
        if is_instance_valid(tail):
            var tail_bounds = Geometry.get_polygon_bounds(tail.polygon)
            if first:
                bounds = tail_bounds
                first = false
            else:
                bounds = bounds.merge(tail_bounds)
    
    # Add padding
    return bounds.grow(5)

func setup_collision_shape():
    _collision_shape.shape.radius = length * width_ratio / 2
    _collision_shape.shape.height = length
    _collision_shape.rotation = PI/2  # Rotate to match fish orientation
    _collision_shape.position.x -= length/6 #TODO: Figure out this exact value

# Update koi to show appropriate turning frame
func set_turn_state(state):
    if current_turn_state != state:
        current_turn_state = state
        sprite.frame = state


# Method to make the koi swim to a target position
func swim_to(target_position: Vector2, speed: float):
    # Calculate direction to target
    var direction = (target_position - global_position).normalized()
    
    # Determine turn state based on direction
    var angle = direction.angle()
    var koi_angle = rotation - PI/2  # Adjust for koi's forward direction
    var angle_diff = wrapf(angle - koi_angle, -PI, PI)
    
    # Set appropriate turn state based on the angle difference
    if abs(angle_diff) < 0.2:
        set_turn_state(TurnState.NEUTRAL)
    elif angle_diff > 0.2 and angle_diff < 0.6:
        set_turn_state(TurnState.SLIGHT_RIGHT)
    elif angle_diff >= 0.6:
        set_turn_state(TurnState.RIGHT)
    elif angle_diff < -0.2 and angle_diff > -0.6:
        set_turn_state(TurnState.SLIGHT_LEFT)
    elif angle_diff <= -0.6:
        set_turn_state(TurnState.LEFT)
    
    # Set velocity
    velocity = direction * speed
    
    # Rotate koi to face the direction of movement
    rotation = direction.angle() + PI/2
    
    # Let CharacterBody2D handle the movement
    move_and_slide()

func construct_koi():
    # Create all components with deformation
    _create_tail()
    _create_fins()
    _create_body()
    _create_dorsal_fin()
    _create_patterns()
    _create_eyes()
    _create_whiskers()
    await %KoiSprite.generate_all_frames()
    sprite.frame = KoiSprite.TurnState.NEUTRAL

func _create_body():
    # Clear any existing body
    if is_instance_valid(_body):
        _body.queue_free()

    # Create the body polygon
    _body = Polygon2D.new()
    #add_child(_body)
    
    # Calculate dimensions
    var body_width = length * width_ratio
    var head_width = body_width * 1.2  # Head slightly wider than body
    var tail_width = body_width * 0.6  # Tail end narrower than head
    
    # Create polygon points in a clear clockwise order
    var points = []
    
    # Add points for the head (curved front)
    for i in range(vertex_resolution):
        var angle = lerp(-PI/2, PI/2, i / float(vertex_resolution - 1))
        var x = length * 0.3 * (1 - cos(angle))  # Keep x near 0
        var y = head_width/2 * sin(angle)
        points.append(Vector2(x, y))
    
    # Add points for the right side (head to tail)
    for i in range(1, vertex_resolution):
        var t = i / float(vertex_resolution)
        var width_at_point = lerp(head_width/2, tail_width/2, t)
        var x = lerp(length * 0.3, length * 0.9, t)
        points.append(Vector2(x, width_at_point))

    # Add points for the tail (curved back)
    for i in range(vertex_resolution):
        var angle = lerp(PI/2, 3*PI/2, i / float(vertex_resolution - 1))
        var x = length - (length * 0.1 * (1 - cos(angle - PI)))  # Keep x near length
        var y = tail_width/2 * sin(angle)
        points.append(Vector2(x, y))
    
    # Add points for the left side (tail to head)
    for i in range(vertex_resolution - 1, 0, -1):
        var t = i / float(vertex_resolution)
        var width_at_point = lerp(head_width/2, tail_width/2, t)
        var x = lerp(length * 0.3, length * 0.9, t)
        points.append(Vector2(x, -width_at_point))
    
    # Apply points to the polygon
    _body.polygon = points
    _body.color = primary_color

func _create_tail():
    # Clear any existing tail polygons
    for tail in _tail:
        if is_instance_valid(tail):
            tail.queue_free()
    _tail.clear()
    
    # Calculate tail dimensions
    var tail_length = length * tail_size_ratio
    var tail_base_width = length * width_ratio * 0.6  # Slightly narrower than body end
    
    # Create left tail fin
    var four_points : Array[Vector2] = []
    four_points.append(Vector2(0.9* length, 0))
    four_points.append(Vector2(length + tail_length * 0.9, -tail_length * 0.1))
    four_points.append(Vector2(length + tail_length, -tail_length * 0.6))
    four_points.append(Vector2(0.9* length, -tail_base_width /2))
    var left_tail : Polygon2D = _make_fin(four_points, vertex_resolution, 0.05, fin_color)
    #add_child(left_tail)
    _tail.append(left_tail)
    
    # Create right tail fin by flipping the left tail fin
    var right_tail = Polygon2D.new()
    var right_points = []
    for point in left_tail.polygon:
        right_points.append(Vector2(point.x, -point.y))
    right_tail.polygon = right_points
    right_tail.color = fin_color
    #add_child(right_tail)
    _tail.append(right_tail)

func _create_fins():
    # Clear any existing fins
    for fin in _fins:
        if is_instance_valid(fin):
            fin.queue_free()
    _fins.clear()
    
    # Calculate fin dimensions
    var fin_base_width = length * width_ratio * 0.8
    var fin_angle = PI/16.0
    # Define positions for the four fins
    # Two pectoral fins (near head) and two pelvic fins (mid-body)
    
    var fin_positions = [
        # Left pectoral fin (near head)
        {
            "position": Vector2(length * 0.2, -length/10),
            "size": 1.0, # Full size
            "flip": false,
        },
        # Right pectoral fin (near head)
        {
            "position": Vector2(length * 0.2, length/10),
            "size": 1.0,  # Full size
            "flip": true,
        },
        # Left pelvic/ventral fin (mid-body)
        {
            "position": Vector2(length * 0.7, -length/13),
            "size": 0.5,  # Slightly smaller
            "flip": false,
        },
        # Right pelvic/ventral fin (mid-body)
        {
            "position": Vector2(length * 0.7, length/13),
            "size": 0.5,  # Slightly smaller
            "flip": true,
        }
    ]
    
    # Create each fin
    for fin_data in fin_positions:
        var trapezoid : Array[Vector2] = [
            Vector2(0, 0),
            Vector2(3 * fin_base_width, -length / 3.0)  * fin_data["size"],
            Vector2(2.5 * fin_base_width, -length / 8.0)  * fin_data["size"],
            Vector2(fin_base_width, 1)  * fin_data["size"],
        ]
        
        var fin : Polygon2D = _make_fin(trapezoid, vertex_resolution, 0.1, fin_color)
        
        # Apply rotation and position directly to polygon points
        var angle = fin_angle * (-1 if fin_data['flip'] else 1)
        
        # First apply flip if needed
        if fin_data['flip']:
            for i in range(fin.polygon.size()):
                fin.polygon[i] = Vector2(fin.polygon[i].x, -fin.polygon[i].y)
        
        # Then apply rotation and position to each point
        for i in range(fin.polygon.size()):
            # Apply rotation
            var rotated_point = fin.polygon[i].rotated(angle)
            # Apply position offset
            fin.polygon[i] = rotated_point + fin_data["position"]
        
        _fins.append(fin)

func _make_fin(trapezoid : Array[Vector2], points : int, curve_factor : float, color : Color) -> Polygon2D:
    # First and last trapezoid points should be attachment points on fish
    var fin = Polygon2D.new()
    var fin_points = []
    
    # Add S-curve to end point
    for point in Geometry.get_sin_curve(
            trapezoid[0], 
            trapezoid[1], 
            points, 
            curve_factor, 
            2,
            false,
            true):
        fin_points.append(point)
    
    for point in Geometry.get_sin_curve(
            trapezoid[1], 
            trapezoid[2], 
            points, 
            curve_factor * 0.2, 
            2,
            false,
            false):
        fin_points.append(point)

    # Add S-curve to end point
    for point in Geometry.get_sin_curve(
            trapezoid[2], 
            trapezoid[3], 
            points, 
            curve_factor, 
            2,
            false,
            true):
        fin_points.append(point)
    
    # Apply points to the fin polygon
    fin.polygon = fin_points
    fin.color = color
    return fin

func _create_dorsal_fin():
    # Calculate dorsal fin dimensions
    var fin_base_width = length * 0.4  # Fin extends along a portion of the back
    var fin_height = length * width_ratio * 0.4  # Height proportional to body width
    
    # Define the base points for the dorsal fin (trapezoid shape)
    var trapezoid : Array[Vector2] = [
        Vector2(length * 0.45, 0),  # Start point on back
        Vector2(length * 0.55, -fin_height),  # Peak point (highest)
        Vector2(length * 0.75, -fin_height * 0.7),  # Secondary peak
        Vector2(length * 0.45 + fin_base_width, 0)  # End point on back
    ]
    
    # Use the same _make_fin function for consistent styling
    var fin_curve_factor = 0.08
    var fin = _make_fin(trapezoid, vertex_resolution, fin_curve_factor, fin_color.darkened(0.2))
    #add_child(fin)
    
    # The dorsal fin sits on top of the body
    _dorsal_fin = fin
    
func _create_patterns():
    seed(pattern_seed) if pattern_seed != 0 else randomize()
    # Get body dimensions for proper texture sizing
    var body_bounds = Geometry.get_polygon_bounds(_body.polygon)
    var texture_width = int(body_bounds.size.x * 1.2)  # Add some padding
    var texture_height = int(body_bounds.size.y * 1.2)
    
    # Create a new image for our texture
    var img = Image.create(texture_width, texture_height, false, Image.FORMAT_RGBA8)
    
    # Fill with primary color (white)
    img.fill(primary_color)
    
    # Generate noise for the pattern
    _generate_koi_pattern(img, texture_width, texture_height)
    
    # Create texture from image
    var texture = ImageTexture.create_from_image(img)
    
    # Apply texture to body
    _body.texture = texture
    
    # Set texture mode to fit within the polygon
    _body.texture_offset = Vector2(-body_bounds.position.x, -body_bounds.position.y)
    _body.texture_scale = Vector2(1, 1)

# Generate koi pattern using noise
func _generate_koi_pattern(img: Image, width: int, height: int):
    # Create a noise generator
    var noise = FastNoiseLite.new()
    noise.seed = pattern_seed if pattern_seed != 0 else randi()
    noise.frequency = 0.005  # Lower frequency for larger spots
    noise.fractal_octaves = 2
    noise.noise_type = FastNoiseLite.TYPE_PERLIN
    
    # Define spot parameters
    var threshold = 0.05  # Higher threshold = fewer spots
    var edge_softness = 0.01  # Softness of spot edges
    
    # Sample noise to create spots
    for x in range(width):
        for y in range(height):
            # Sample noise at this point
            var noise_value = noise.get_noise_2d(x * 3, y * 3)  # Scaled for larger patterns
            
            # Apply secondary color where noise exceeds threshold
            if noise_value > threshold:
                # Calculate alpha for smooth edges
                var alpha = clamp((noise_value - threshold) / edge_softness, 0.0, 1.0)
                
                # Add some variation to the spot color
                var spot_variation = (noise_value - threshold) * 0.3
                var current_spot_color : Color
                current_spot_color = secondary_color.lightened(spot_variation)
                
                # Blend colors based on alpha
                var blended_color = primary_color.lerp(current_spot_color, alpha)
                img.set_pixel(x, y, blended_color)

func _create_eyes():
    # Clear any existing fins
    for eye in _eyes:
        if is_instance_valid(eye):
            eye.queue_free()
    _eyes.clear()
    
    # Create both left and right eyes
    var eye_size = length * 0.02
    var eye_positions = [
        Vector2(length * 0.15, -length * width_ratio * 0.35),  # Left eye
        Vector2(length * 0.15, length * width_ratio * 0.35)    # Right eye
    ]
    
    for eye_position in eye_positions:
        var eye = Polygon2D.new()
        #add_child(eye)
        
        # Create circular points for the eye
        var eye_points = []
        for i in range(vertex_resolution):
            var angle = i * TAU / vertex_resolution
            var x = cos(angle) * eye_size + eye_position.x
            var y = sin(angle) * eye_size + eye_position.y
            eye_points.append(Vector2(x, y))
        
        eye.polygon = eye_points
        eye.color = Color(0, 0, 0, 1)  # Black with full opacity
        #eye.position = eye_position
        
        # Optional: Add a small white highlight to the eye
        var highlight = Polygon2D.new()
        var highlight_points = []
        var highlight_size = eye_size * 0.3
        for i in range(vertex_resolution / 2):
            var angle = i * TAU / vertex_resolution
            var x = cos(angle) * highlight_size + eye_size * 0.3 + eye_position.x
            var y = sin(angle) * highlight_size - eye_size * 0.3 + eye_position.y
            highlight_points.append(Vector2(x, y))
        highlight.polygon = highlight_points
        highlight.color = Color(1, 1, 1, 0.7)  # White with some transparency
        _eyes.append(eye)
        _eyes.append(highlight)

func _create_whiskers():
    # Clear any existing fins
    for whisker in _whiskers:
        if is_instance_valid(whisker):
            whisker.queue_free()
    _whiskers.clear()

    # Whisker parameters for top-down view
    var whisker_length = length * 0.1
    var whisker_curve = 0.15
    var whisker_base = Vector2(length * 0.05, 0)  # Front of head
    
    # Create whiskers in pairs (2 on each side)
    var whisker_configs = [
        # Left side whiskers
        {
            "start": whisker_base + Vector2(0, -length * width_ratio * 0.2),
            "angle": -PI/2,  # Angled slightly back and outward
            "flip": true
        },
        # Right side whiskers
        {
            "start": whisker_base + Vector2(0, length * width_ratio * 0.2),
            "angle": PI/2,  # Angled slightly back and outward
            "flip": false
        },
    ]
    
    for config in whisker_configs:
        var start_pos = config["start"]
        var end_pos = start_pos + Vector2(cos(config["angle"]) * whisker_length, 
                                         sin(config["angle"]) * whisker_length)
        
        # Create curved line for whisker
        var whisker_points = Geometry.get_sin_curve(
            start_pos,
            end_pos,
            vertex_resolution,
            whisker_curve,
            1,  # Just one curve
            config["flip"],
            true  # Include endpoints
        )
        
        # Create Line2D for the whisker
        var whisker = Line2D.new()
        whisker.points = whisker_points
        whisker.width = length * 0.01  # Thin line
        whisker.default_color = primary_color
        _whiskers.append(whisker)
        
# Optional: Add swimming animation
func animate_swimming(_delta: float):
    var state = (current_turn_state + 1) % 5
    set_turn_state(state)

func _process(_delta: float):
    pass

func set_target(target: Vector2):
    navigation_agent.set_target_position(target)
    is_moving = true

func _physics_process(delta):
    if is_moving:
        if NavigationServer2D.map_get_iteration_id(navigation_agent.get_navigation_map()) == 0:
            is_moving=false
            return
        if navigation_agent.is_navigation_finished():
            is_moving = false
            return

        var next_path_position: Vector2 = navigation_agent.get_next_path_position()
        var new_velocity: Vector2 = global_position.direction_to(next_path_position)
        if navigation_agent.avoidance_enabled:
            navigation_agent.set_velocity(new_velocity)
        else:
            var move_angle = wrapf(new_velocity.angle(), -PI, PI)
            #I made the fish facing the wrong direction so now we mess with global rotation
            move_angle = Geometry.smooth_angle_difference(wrapf(global_rotation+PI, -PI, PI), move_angle, turn_speed * delta)
            var angle_diff = wrapf(move_angle - wrapf(global_rotation+PI, -PI,PI), -PI, PI)
            # Determine turn state based on angle difference
            var turn_state
            if abs(angle_diff) < turn_speed / 4 *delta:
                turn_state = TurnState.NEUTRAL
            elif angle_diff > turn_speed /4 *delta and angle_diff < turn_speed / 2 *delta:
                turn_state = TurnState.SLIGHT_RIGHT
            elif angle_diff >= turn_speed / 2 *delta:
                turn_state = TurnState.RIGHT
            elif angle_diff < -turn_speed / 4 * delta and angle_diff > -turn_speed / 2 * delta:
                turn_state = TurnState.SLIGHT_LEFT
            elif angle_diff <= -turn_speed / 2 * delta:
                turn_state = TurnState.LEFT
            set_turn_state(turn_state)
            
            global_rotation = wrapf(move_angle+PI,-PI,PI)

            new_velocity  = Vector2.from_angle(move_angle) * move_speed * delta
            global_position +=+ new_velocity
