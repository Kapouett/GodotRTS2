extends Spatial

const MOVE_MARGIN = 20
const MOVE_SPEED = 30

const ZOOM_MIN:float = 15.0
const ZOOM_MAX:float = 85.0
const ANGLE_FAR:float = -70.0
const ANGLE_NEAR:float = -50.0
var zoom_speed:float = 14.0
var scroll_strength:float = 7.0
var zoom_input_strength:float = 23.0
var scroll_input:float = 0.0
var zoom_target:float = 55.0

const ray_length = 1000
onready var cam = $Camera

var team = 0
var selected_units:Array = []
onready var selection_box = $SelectionBox
var start_sel_pos = Vector2()

func _process(delta):
	var m_pos = get_viewport().get_mouse_position()
	calc_move(m_pos, delta)
	calc_zoom(delta)
	
	if Input.is_action_just_pressed("main_command"):
		move_selected_units(m_pos)
	if Input.is_action_just_pressed("alt_command"):
		selection_box.start_sel_pos = m_pos
		start_sel_pos = m_pos
	if Input.is_action_pressed("alt_command"):
		selection_box.m_pos = m_pos
		selection_box.is_visible = true
	else:
		selection_box.is_visible = false
	if Input.is_action_just_released("alt_command"):
		select_units(m_pos)

func calc_move(m_pos, delta):
	var v_size = get_viewport().size
	var move_vec = Vector3()
	if m_pos.x < MOVE_MARGIN:
		move_vec.x -= 1
	if m_pos.y < MOVE_MARGIN:
		move_vec.z -= 1
	if m_pos.x > v_size.x - MOVE_MARGIN:
		move_vec.x += 1
	if m_pos.y > v_size.y - MOVE_MARGIN:
		move_vec.z += 1
	
	if Input.is_action_pressed("ui_left"):
		move_vec.x -= 1
	if Input.is_action_pressed("ui_right"):
		move_vec.x += 1
	if Input.is_action_pressed("ui_up"):
		move_vec.z -= 1
	if Input.is_action_pressed("ui_down"):
		move_vec.z += 1
	
	move_vec = move_vec.rotated(Vector3(0, 1, 0), rotation_degrees.y)
	global_translate(move_vec * delta * MOVE_SPEED)

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("zoom_in_mouse"):
		scroll_input = -event.get_action_strength("zoom_in_mouse") * scroll_strength
	elif event.is_action_pressed("zoom_out_mouse"):
		scroll_input = event.get_action_strength("zoom_out_mouse") * scroll_strength

func calc_zoom(delta) -> void:
	# Zoom
	if Input.is_action_pressed("zoom_in"):
		scroll_input -= 1.0
	if Input.is_action_pressed("zoom_out"):
		scroll_input += 1.0
	zoom_target += scroll_input * zoom_input_strength * delta
	zoom_target = clamp(zoom_target, ZOOM_MIN, ZOOM_MAX)
	
	cam.translation.z = lerp(cam.translation.z, zoom_target, min(1.0, zoom_speed * delta))
	
	scroll_input = lerp(scroll_input, 0, min(1.0, 15.0 * delta))
	
	rotation_degrees.x = lerp(ANGLE_NEAR, ANGLE_FAR, (cam.translation.z-ZOOM_MIN)/(ZOOM_MAX-ZOOM_MIN))

func move_selected_units(m_pos):
	var result = raycast_from_mouse(m_pos, 1)
	if result:
		for unit in selected_units:
			unit.move_to(result.position)

func select_units(m_pos):
	var new_selected_units = []
	if m_pos.distance_squared_to(start_sel_pos) < 16:
		var u = get_unit_under_mouse(m_pos)
		if u != null:
			new_selected_units.append(u)
	else:
		new_selected_units = get_units_in_box(start_sel_pos, m_pos)
	if new_selected_units.size() != 0:
		if Input.is_action_pressed("selection_shift"):
			for unit in new_selected_units:
				if not selected_units.has(unit):
					unit.select()
					selected_units.append(unit)
		else:
			for unit in selected_units:
				unit.deselect()
			for unit in new_selected_units:
				unit.select()
			selected_units = new_selected_units

func get_unit_under_mouse(m_pos):
	var result = raycast_from_mouse(m_pos, 3)
	if result and "team" in result.collider and result.collider.team == team:
		return result.collider

func get_units_in_box(top_left, bot_right):
	if top_left.x > bot_right.x:
		var tmp = top_left.x
		top_left.x = bot_right.x
		bot_right.x = tmp
	if top_left.y > bot_right.y:
		var tmp = top_left.y
		top_left.y = bot_right.y
		bot_right.y = tmp
	var box = Rect2(top_left, bot_right - top_left)
	var box_selected_units = []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.team == team and box.has_point(cam.unproject_position(unit.global_transform.origin)):
			box_selected_units.append(unit)
	return box_selected_units

func raycast_from_mouse(m_pos, collision_mask):
	var ray_start = cam.project_ray_origin(m_pos)
	var ray_end = ray_start + cam.project_ray_normal(m_pos) * ray_length
	var space_state = get_world().direct_space_state
	return space_state.intersect_ray(ray_start, ray_end, [], collision_mask)
