@tool
extends Sprite2D

# Tree generation parameters
@export var trunk_height: float = 80.0:
    set(value):
        trunk_height = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var trunk_width: float = 8.0:
    set(value):
        trunk_width = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var branch_count: int = 6:
    set(value):
        branch_count = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var branch_angle_spread: float = 60.0:
    set(value):
        branch_angle_spread = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var branch_length_min: float = 20.0:
    set(value):
        branch_length_min = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")
            
@export var branch_length_max: float = 40.0:
    set(value):
        branch_length_max = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var foliage_radius_min: float = 15.0:
    set(value):
        foliage_radius_min = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var foliage_radius_max: float = 25.0:
    set(value):
        foliage_radius_max = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var tree_seed: int = 0:
    set(value):
        tree_seed = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

# New parameters for enhanced generation
@export var foliage_density: float = 0.8:
    set(value):
        foliage_density = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var foliage_clusters_per_branch: int = 3:
    set(value):
        foliage_clusters_per_branch = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var trunk_taper: float = 0.7:
    set(value):
        trunk_taper = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

@export var branch_recursion_depth: int = 2:
    set(value):
        branch_recursion_depth = value
        if Engine.is_editor_hint():
            call_deferred("_regenerate_if_ready")

# Colors
var trunk_color: Color = Color(0.4, 0.2, 0.1)  # Brown
var foliage_alpha : float = 1.0  # Alpha for foliage colors
var foliage_colors: Array[Color] = [
    Color(1.0, 0.6, 0.8, foliage_alpha),   # Bright pink
    Color(1.0, 0.7, 0.85, foliage_alpha),  # Light pink
    Color(0.95, 0.5, 0.75, foliage_alpha), # Medium pink
    Color(1.0, 0.8, 0.9, foliage_alpha),   # Very light pink
    Color(0.9, 0.4, 0.6, foliage_alpha),   # Darker pink
    Color(1.0, 0.75, 0.82, foliage_alpha), # Soft pink
]

# Generated tree data
var branches: Array = []
var foliage_clusters: Array = []
var generated_image: Image

func _ready():
    generate_tree()
    queue_redraw()
    
    # Connect to parameter changes in editor
    if Engine.is_editor_hint():
        # Regenerate when properties change
        property_list_changed.connect(_on_property_changed)

func _on_property_changed():
    if Engine.is_editor_hint():
        generate_tree()
        queue_redraw()

func generate_tree():
    if tree_seed != 0:
        seed(tree_seed)
    
    branches.clear()
    foliage_clusters.clear()
    
    # Generate trunk with taper
    var trunk_start = Vector2(0, 0)
    var trunk_end = Vector2(0, -trunk_height)
    branches.append({
        "start": trunk_start,
        "end": trunk_end,
        "width": trunk_width,
        "end_width": trunk_width * trunk_taper,
        "angle": -90.0
    })
    
    # Generate branches recursively
    _generate_branches_recursive(trunk_end, -90.0, trunk_width * trunk_taper, 0)
    
    # Generate dense foliage clusters
    _generate_dense_foliage()
    
    # Generate the image
    create_tree_image()

func _generate_branches_recursive(start_pos: Vector2, parent_angle: float, parent_width: float, depth: int):
    if depth >= branch_recursion_depth:
        return
    
    var branch_count_at_depth = branch_count if depth == 0 else max(2, branch_count / 2)
    
    for i in range(branch_count_at_depth):
        # More varied branch angles
        var angle_variation = branch_angle_spread * (1.0 - depth * 0.3)
        var branch_angle = parent_angle + randf_range(-angle_variation/2, angle_variation/2)
        
        # Branch length decreases with depth
        var length_multiplier = 1.0 - depth * 0.4
        var branch_length = randf_range(branch_length_min, branch_length_max) * length_multiplier
        
        var branch_direction = Vector2.from_angle(deg_to_rad(branch_angle))
        var branch_end = start_pos + branch_direction * branch_length
        
        var branch_width = parent_width * (0.6 - depth * 0.1)
        var end_width = branch_width * 0.7
        
        branches.append({
            "start": start_pos,
            "end": branch_end,
            "width": branch_width,
            "end_width": end_width,
            "angle": branch_angle
        })
        
        # Recursively generate sub-branches
        if randf() > (0.3 + depth * 0.2):
            _generate_branches_recursive(branch_end, branch_angle, end_width, depth + 1)

func _generate_dense_foliage():
    # Generate multiple foliage clusters per branch tip
    for branch in branches:
        if randf() < foliage_density:
            for cluster_i in range(foliage_clusters_per_branch):
                # Place clusters along the branch, not just at the end
                var t = randf_range(0.6, 1.0)
                var cluster_pos = branch.start.lerp(branch.end, t)
                
                # Add some random offset
                var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
                cluster_pos += offset
                
                var base_radius = randf_range(foliage_radius_min, foliage_radius_max)
                # Vary radius based on position on branch
                var radius_multiplier = 0.8 + t * 0.4
                var foliage_radius = base_radius * radius_multiplier
                
                var foliage_color = foliage_colors[randi() % foliage_colors.size()]
                
                foliage_clusters.append({
                    "position": cluster_pos,
                    "radius": foliage_radius,
                    "color": foliage_color
                })

func create_tree_image():
    var image_size = Vector2i(400, 250)
    generated_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
    generated_image.fill(Color.TRANSPARENT)
    
    var center_offset = Vector2(image_size.x / 2, image_size.y - 20)
    
    # Draw branches with tapering
    for branch in branches:
        var end_width = branch.get("end_width", branch.width)
        draw_line_on_image(
            generated_image,
            branch.start + center_offset,
            branch.end + center_offset,
            trunk_color,
            branch.width,
            end_width
        )
    
    # Draw foliage clusters
    for cluster in foliage_clusters:
        draw_circle_on_image(
            generated_image,
            cluster.position + center_offset,
            cluster.radius,
            cluster.color
        )

    #set alpha of generated image to 1.0
    # for x in range(generated_image.get_width()):
    #     for y in range(generated_image.get_height()):
    #         var pixel_color = generated_image.get_pixel(x, y)
    #         if pixel_color == Color.TRANSPARENT:
    #             continue  # Skip transparent pixels
    #         pixel_color.a = 1.0  # Set alpha to fully opaque
    #         generated_image.set_pixel(x, y, pixel_color)
    self.texture.set_image(generated_image)

func draw_line_on_image(image: Image, start: Vector2, end: Vector2, color: Color, width: float, end_width: float = -1):
    if end_width < 0:
        end_width = width
    
    var distance = start.distance_to(end)
    var direction = (end - start).normalized()
    var perpendicular = Vector2(-direction.y, direction.x)
    
    var steps = max(int(distance), 1)
    for step in range(steps + 1):
        var t = float(step) / float(steps)
        var current_width = lerp(width, end_width, t)
        var point = start.lerp(end, t)
        
        # Draw thick line with tapering
        for i in range(int(current_width)):
            var offset = (i - current_width/2) * perpendicular
            var pixel_pos = Vector2i(int(point.x + offset.x), int(point.y + offset.y))
            
            if pixel_pos.x >= 0 and pixel_pos.x < image.get_width() and \
               pixel_pos.y >= 0 and pixel_pos.y < image.get_height():
                image.set_pixelv(pixel_pos, color)

func draw_circle_on_image(image: Image, center: Vector2, radius: float, color: Color):
    var center_int = Vector2i(int(center.x), int(center.y))
    var radius_int = int(radius)
    
    # Create more organic, varied foliage
    for y in range(-radius_int, radius_int + 1):
        for x in range(-radius_int, radius_int + 1):
            var distance_sq = x * x + y * y
            var radius_sq = radius_int * radius_int
            
            # Add some organic variation to the circle edge
            var noise_factor = 1.0 + randf_range(-0.3, 0.3)
            if distance_sq <= radius_sq * noise_factor:
                var pixel_pos = center_int + Vector2i(x, y)
                if pixel_pos.x >= 0 and pixel_pos.x < image.get_width() and \
                   pixel_pos.y >= 0 and pixel_pos.y < image.get_height():
                    
                    # Add color variation and alpha blending for softer edges
                    var edge_factor = 1.0 - (sqrt(distance_sq) / radius_int)
                    var variation = randf_range(0.7, 1.0)
                    var alpha = color.a * edge_factor
                    
                    var varied_color = Color(
                        color.r * variation,
                        color.g * variation,
                        color.b * variation,
                        alpha
                    )
                    
                    # Blend with existing pixel for overlapping effect
                    var existing_color = image.get_pixelv(pixel_pos)
                    var blended_color = existing_color.lerp(varied_color, alpha)
                    image.set_pixelv(pixel_pos, blended_color)

func save_tree_image(file_path: String):
    if generated_image:
        generated_image.save_png(file_path)
        print("Tree image saved to: ", file_path)

func regenerate_tree():
    tree_seed = randi()
    generate_tree()
    queue_redraw()

# Call this to get the generated image
func get_tree_image() -> Image:
    return generated_image

func _regenerate_if_ready():
    if is_inside_tree():
        generate_tree()
        queue_redraw()
