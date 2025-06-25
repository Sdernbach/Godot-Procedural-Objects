@tool
class_name Drawing_Utils
extends Node

static func draw_line_on_image(image: Image, start: Vector2, end: Vector2, color: Color, width: float, end_width: float = -1):
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

static func get_most_common_colors(texture: Texture, num_colors: int = 3, bin_size : int = 16, topleft : Vector2 = Vector2.ZERO, bottomright : Vector2 = Vector2.ZERO) -> Array:
    # Get the image data from the texture
    var image: Image = texture.get_image()
    
    # Dictionary to store color frequencies
    var color_bins = {}

    var x_start = int(topleft.x)
    var y_start = int(topleft.y)
    var x_end = image.get_width() if bottomright.x == 0 else int(bottomright.x)
    var y_end = image.get_height() if bottomright.y == 0 else int(bottomright.y)

    # Scan through all pixels
    for x in range(x_start, x_end):
        for y in range(y_start, y_end):
            var pixel_color = image.get_pixel(x, y)
            
            # Skip fully transparent pixels
            if pixel_color.a < 0.1:
                continue
            
            # Bin the color by rounding RGB values to reduce precision
            var binned_r = round(pixel_color.r * 255 / bin_size) * bin_size / 255
            var binned_g = round(pixel_color.g * 255 / bin_size) * bin_size / 255
            var binned_b = round(pixel_color.b * 255 / bin_size) * bin_size / 255
            
            # Create a new Color with binned values
            var binned_color = Color(binned_r, binned_g, binned_b, 1.0)
            
            # Update frequency count
            if color_bins.has(binned_color):
                color_bins[binned_color] += 1
            else:
                color_bins[binned_color] = 1
    
    # Sort colors by frequency
    var sorted_colors = []
    for color in color_bins.keys():
        sorted_colors.append({"color": color, "count": color_bins[color]})
    
    # Sort in descending order
    var lambda = func(a,b):
        return a["count"] > b["count"]
    sorted_colors.sort_custom(lambda)

    # Return the top N colors
    var result = []
    for i in range(min(num_colors, sorted_colors.size())):
        result.append(sorted_colors[i]["color"])
    
    return result
