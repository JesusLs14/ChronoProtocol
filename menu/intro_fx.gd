class_name IntroFx
extends RefCounted

## Partículas para la intro: estrellas, brasas, humo, chispas, polvo y fuego.
## Son CPUParticles2D de píxeles cuadrados, a tono con el estilo pixel art.


static func _gradient(colors: Array[Color]) -> Gradient:
	var offsets := PackedFloat32Array()
	for index in colors.size():
		offsets.append(float(index) / float(colors.size() - 1))
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colors)
	return gradient


static func _base(amount: int, lifetime: float, area: Vector2) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = area * 0.5
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return particles


## Brasas que suben y se apagan (colonia, final, aterrizaje).
static func embers(area: Vector2, amount: int = 90) -> CPUParticles2D:
	var particles := _base(amount, 4.0, area)
	particles.direction = Vector2(0.2, -1)
	particles.spread = 25.0
	particles.gravity = Vector2(30, -20)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color_ramp = _gradient([
		Color(1, 0.9, 0.5, 1), Color(1, 0.5, 0.1, 0.9), Color(0.6, 0.1, 0.05, 0),
	])
	return particles


## Humo lento y grande.
static func smoke(area: Vector2, amount: int = 30) -> CPUParticles2D:
	var particles := _base(amount, 6.0, area)
	particles.direction = Vector2(0.3, -1)
	particles.spread = 20.0
	particles.gravity = Vector2(10, -15)
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 45.0
	particles.scale_amount_min = 40.0
	particles.scale_amount_max = 90.0
	particles.color_ramp = _gradient([
		Color(0.15, 0.12, 0.12, 0), Color(0.12, 0.1, 0.1, 0.35), Color(0.1, 0.08, 0.08, 0),
	])
	return particles


## Estrellas que titilan en el espacio.
static func stars(area: Vector2, amount: int = 120) -> CPUParticles2D:
	var particles := _base(amount, 3.0, area)
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 0.0
	particles.initial_velocity_max = 4.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color_ramp = _gradient([
		Color(0.7, 0.9, 1, 0), Color(0.8, 0.95, 1, 0.9), Color(0.7, 0.9, 1, 0),
	])
	return particles


## Polvo dorado flotando en la luz (propaganda).
static func dust(area: Vector2, amount: int = 70) -> CPUParticles2D:
	var particles := _base(amount, 5.0, area)
	particles.direction = Vector2(0.4, 1)
	particles.spread = 60.0
	particles.gravity = Vector2(4, 8)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 25.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color_ramp = _gradient([
		Color(1, 0.85, 0.5, 0), Color(1, 0.85, 0.5, 0.7), Color(1, 0.8, 0.4, 0),
	])
	return particles


## Estela de fuego de la cápsula (se emite hacia atrás de su movimiento).
static func fire_trail(direction: Vector2) -> CPUParticles2D:
	var particles := _base(160, 0.9, Vector2(120, 120))
	particles.local_coords = false
	particles.preprocess = 0.0
	particles.direction = direction
	particles.spread = 18.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 250.0
	particles.initial_velocity_max = 520.0
	particles.scale_amount_min = 8.0
	particles.scale_amount_max = 20.0
	particles.color_ramp = _gradient([
		Color(1, 0.95, 0.7, 1), Color(1, 0.55, 0.1, 0.9), Color(0.5, 0.1, 0.05, 0.5), Color(0.1, 0.08, 0.08, 0),
	])
	return particles


## Estallido de chispas y tierra (impacto de la cápsula).
static func burst(amount: int = 140) -> CPUParticles2D:
	var particles := _base(amount, 1.4, Vector2(200, 30))
	particles.preprocess = 0.0
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector2(0, -1)
	particles.spread = 75.0
	particles.gravity = Vector2(0, 600)
	particles.initial_velocity_min = 300.0
	particles.initial_velocity_max = 900.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 12.0
	particles.color_ramp = _gradient([
		Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.1, 1), Color(0.35, 0.25, 0.2, 0),
	])
	return particles
