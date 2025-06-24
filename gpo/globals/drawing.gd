@tool
class_name Drawing_Utils
extends Node

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