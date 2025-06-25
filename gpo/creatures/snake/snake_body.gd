@tool
extends Line2D

func construct_body(num_points: int, segment_length: float, colors: Array[Color]) -> void:
    clear_points()
    for i in range(num_points):
        var segment_position = Vector2(i * segment_length, 0)
        add_point(segment_position)
    gradient = Gradient.new()
    gradient.set_color(0, colors[0])
    for i in range(1, num_points):
        var color_index = i % colors.size()
        gradient.add_point(float(i)/num_points, colors[color_index])
    gradient.set_color(gradient.colors.size()-1, colors[num_points % colors.size()])
    gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
