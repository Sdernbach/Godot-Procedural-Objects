@tool
class_name KoiSprite
extends AnimatedSprite2D

# Animation State properties
enum TurnState {NEUTRAL, SLIGHT_LEFT, LEFT, SLIGHT_RIGHT, RIGHT}
const TurnStateNames = ["NEUTRAL", "SLIGHT_LEFT", "LEFT", "SLIGHT_RIGHT", "RIGHT"]
static var turn_values = {
    TurnState.NEUTRAL: 0.0,
    TurnState.SLIGHT_LEFT: -0.075,
    TurnState.LEFT: -0.15,
    TurnState.SLIGHT_RIGHT: 0.075,
    TurnState.RIGHT: 0.15
}

func _ready() -> void:
    pass

func generate_all_frames() -> void:
    sprite_frames.clear_all()
    for state in TurnState.values():
        sprite_frames.add_frame("default", await generate_frame_for_state(state))

func generate_frame_for_state(state):
    var _tail = get_parent()._tail
    var _body = get_parent()._body
    var _dorsal_fin = get_parent()._dorsal_fin
    var _fins = get_parent()._fins
    var _eyes = get_parent()._eyes
    var _whiskers = get_parent()._whiskers

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
    
    var local_offset = -bounds.get_center() + Vector2(viewport.size / 2)
    
    # Create duplicates of all components and add them to the viewport
    # Fins
    for fin_copy in fin_copies:
        fin_copy.position += local_offset
        viewport.add_child(fin_copy)
    
    # Tail parts
    for tail_copy in tail_copies:
        tail_copy.position += local_offset
        viewport.add_child(tail_copy)
    
    # Body
    body_copy.position += local_offset
    viewport.add_child(body_copy)
    
    # Whiskers
    for whisker_copy in whisker_copies:
        whisker_copy.position += local_offset
        viewport.add_child(whisker_copy)
    
    # Eyes
    for eye_copy in eye_copies:
        eye_copy.position += local_offset
        viewport.add_child(eye_copy)
    
    # Dorsal fin
    dorsal_copy.position += local_offset
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
