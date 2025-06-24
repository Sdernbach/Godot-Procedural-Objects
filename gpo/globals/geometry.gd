@tool
class_name Geometry_Utils
extends Node

# Constrain the vector to be at a certain range of the anchor
static func constrain_distance(pos: Vector2, anchor: Vector2, constraint: float) -> Vector2:
    return anchor + (pos - anchor).normalized() * constraint

# Constrain the angle to be within a certain range of the anchor
static func constrain_angle(angle: float, anchor: float, constraint: float) -> float:
    if abs(relative_angle_diff(angle, anchor)) <= constraint:
        return simplify_angle(angle)
    
    if relative_angle_diff(angle, anchor) > constraint:
        return simplify_angle(anchor - constraint)
    
    return simplify_angle(anchor + constraint)

# Calculate the relative angle difference between two angles
static func relative_angle_diff(angle: float, anchor: float) -> float:
    # Rotate coordinate space to avoid issues with the 0-2PI "seam"
    angle = simplify_angle(angle + PI - anchor)
    anchor = PI
    
    return anchor - angle

# Simplify the angle to be in the range [0, 2PI)
static func simplify_angle(angle: float) -> float:
    while angle >= TAU:
        angle -= TAU
    
    while angle < 0:
        angle += TAU
    
    return angle

## Generate points forming an S-curve between two points
##
## start: The starting point of the curve
## end: The ending point of the curve
## points: The number of points to generate along the curve
## curve_factor: The magnitude of the curve offset
## curves: The number of S-curves to apply
## flip: Whether to flip the curve direction, by default rises before falling
## include_end_pts: Whether to include the start and end points in the curve, does not count towards the points parameter
func get_sin_curve(start: Vector2, end: Vector2, points: int, curve_factor: float, curves : int = 2, flip = false, include_end_pts := false) -> Array[Vector2]:
    var curve_points: Array[Vector2] = []
    
    # Add the starting point
    if include_end_pts:
        curve_points.append(start)
    
    # Generate intermediate points along the curve
    for i in range(1, points - 1):
        var t = float(i) / (points - 1)
        
        # Base linear interpolation between start and end
        var x = lerp(start.x, end.x, t)
        var y = lerp(start.y, end.y, t)
        
        # Apply S-curve modifier
        # sin(t * PI) creates the S shape, peaking at t=0.5
        var s_factor = sin(t * curves * PI + (PI if flip else 0.0))
        
        # Calculate perpendicular vector to the line from start to end
        var line_dir = (end - start).normalized()
        var perp_dir = Vector2(-line_dir.y, line_dir.x)
        
        # Apply curve offset perpendicular to the line direction
        var offset = perp_dir * s_factor * curve_factor * start.distance_to(end)
        
        # Add the point with S-curve modification
        curve_points.append(Vector2(x, y) + offset)
    
    # Add the ending point
    if include_end_pts:
        curve_points.append(end)
    return curve_points

## Deforms the y-coordinates of a set of points using a bezier curve
##
## points: The set of points to deform
## control_factor: The factor to control the amount of deformation
## max_x: The maximum x value (length of the fish), if 0, it will be calculated from the points
static func apply_bezier_deformation(points: Array[Vector2], control_factor: float, max_x : int = 0) -> Array:
    var deformed_points = []
    
    # Find maximum x value (length of fish)
    if max_x == 0:
        for point in points:
            max_x = max(max_x, point.x)
    
    for point in points:
        # Calculate normalized position along fish length
        var t = point.x / max_x
        
        # Create bezier control point
        #var control_point = Vector2(max_x * 0.5, max_x * control_factor * direction)
        
        # Apply quadratic bezier deformation (mainly to y coordinate)
        var deformed_y = point.y + 4 * control_factor * max_x * t * (1 - t)
        
        # Keep x coordinate mostly the same, with slight adjustment for realism
        var deformed_x = point.x - abs(deformed_y - point.y) * 0.1
        
        deformed_points.append(Vector2(deformed_x, deformed_y))
    
    return deformed_points

# Deforms a Polygon2D with both points and texture transformation
func apply_bezier_deformation_to_polygon(polygon_node: Polygon2D, control_factor: float, max_x: float = 0.0) -> Polygon2D:
    # If max_x is not provided, calculate it from the polygon
    if max_x <= 0:
        for point in polygon_node.polygon:
            max_x = max(max_x, point.x)
    
    # Deform the polygon points
    var original_points = polygon_node.polygon.duplicate()
    polygon_node.polygon = apply_bezier_deformation(original_points, control_factor, max_x)
    
    # If there's a texture, we need to deform it as well
    if polygon_node.texture:
        var texture_img = polygon_node.texture.get_image()
        var width = texture_img.get_width()
        var height = texture_img.get_height()
        
        # Create a new image for the deformed texture
        var deformed_img = Image.create(width, height, false, Image.FORMAT_RGBA8)
        deformed_img.fill(Color(0, 0, 0, 0))  # Transparent background
        
        # For each pixel in the output image, find where it would be in the original
        for y in range(height):
            for x in range(width):
                # Convert to polygon space
                var point_in_polygon = Vector2(x, y) + polygon_node.texture_offset
                
                # Apply inverse deformation to find source point
                var normalized_x = point_in_polygon.x / max_x if max_x > 0 else 0
                var bezier_offset = control_factor * 4 * normalized_x * (1 - normalized_x)
                var source_y = point_in_polygon.y - bezier_offset * max_x
                var source_x = point_in_polygon.x
                
                # Convert back to texture space
                var source_texture_point = Vector2(source_x, source_y) - polygon_node.texture_offset
                
                # If the source point is within bounds, copy the pixel
                if source_texture_point.x >= 0 and source_texture_point.x < width and \
                   source_texture_point.y >= 0 and source_texture_point.y < height:
                    var color = texture_img.get_pixelv(source_texture_point)
                    deformed_img.set_pixel(x, y, color)
        
        # Create and apply the new texture
        var new_texture = ImageTexture.create_from_image(deformed_img)
        polygon_node.texture = new_texture
    
    return polygon_node

# Helper function to get the bounding rectangle of a polygon
func get_polygon_bounds(polygon: Array) -> Rect2:
    if polygon.size() == 0:
        return Rect2()
        
    var min_x = polygon[0].x
    var min_y = polygon[0].y
    var max_x = min_x
    var max_y = min_y
    
    for point in polygon:
        min_x = min(min_x, point.x)
        min_y = min(min_y, point.y)
        max_x = max(max_x, point.x)
        max_y = max(max_y, point.y)
    
    return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func smooth_angle_difference(current: float, target: float, max_delta: float) -> float:
    var angle_diff = wrapf(target - current, -PI, PI)
    if abs(angle_diff) > max_delta:
        angle_diff = sign(angle_diff) * max_delta
    return current + angle_diff

# Returns a random point along a curve, using the baked length for uniform distribution
# If t is -1, it will generate a random t value between 0 and 1
# t: A value between 0 and 1 representing the position along the curve
static func uniform_point_along_curve(curve: Curve2D, t: float = -1) -> Transform2D:
    if t == -1:
        t = randf()
    return curve.sample_baked_with_rotation(curve.get_baked_length() * t, true)

# Generates a random float from a beta distribution using the inverse transform sampling method
# alpha: The shape parameter for the beta distribution
# beta: The shape parameter for the beta distribution
# Returns a float in the range [0, 1] following the beta distribution
static func random_beta_distribution(alpha: float, beta: float) -> float:
    # Generate two uniform random numbers
    var u1 = randf()
    var u2 = randf()
    
    # Apply the inverse transform sampling method for the beta distribution
    var x = pow(u1, 1.0 / alpha)
    var y = pow(u2, 1.0 / beta)
    
    return x / (x + y)