@tool
class_name JapanProvinceArea
extends Area2D

enum Province {
	UNSPECIFIED,

	KII,
	SATSUMA,
	HYUUGA,
	HIGO,
	OOSUMI,
	CHIKUGO,
	KOUZUKE,
	HIZEN,
	CHIKUZEN,
	BUZEN,
	BUNGO,
	IKI,
	TSUSHIMA,
	TOSA,
	AWA_TOKUSHIMA,
	SANUKI,
	IYO,
	AWAJI,
	NAGATO,
	SUOU,
	AKI,
	BINGO,
	BITCHUU,
	BIZEN,
	MIMASAKA,
	HARIMA,
	IWAMI,
	IZUMO,
	HOUKI,
	OKI,
	INABA,
	TAJIMA,
	TANBA,
	TANGO,
	SETTSU,
	IZUMI,
	YAMATO,
	YAMASHIRO,
	KAWACHI,
	WAKASA,
	ECHIZEN,
	NOTO,
	ETCHUU,
	ECHIGO,
	SADO,
	HITACHI,
	KAGA,
	IGA,
	ISE,
	SHIMA,
	OWARI,
	MIKAWA,
	TOUTOUMI,
	OUMI,
	SURUGA,
	IZU,
	SAGAMI,
	KAI,
	MUSASHI,
	AWA_CHIBA,
	KAZUSA,
	SHIMOUSA,
	MINO,
	HIDA,
	SHINANO,
	SHIMOTSUKE,
	MUTSU,
	DEWA,
	EZO,

	SPECIAL_KYOTO,  # Yamashiro
	SPECIAL_EDO,    # Musashi
	SPECIAL_YAMANASHI,  # Equivalent to Kai
	SPECIAL_NARA,  # Equivalent to Yamato
	SPECIAL_TOKYO,    # Musashi
	SPECIAL_HOKKAIDOU,    # Ezo
	SPECIAL_OSAKA,    # Settsu
}

signal hovered
signal unhovered

@export var province: Province = Province.UNSPECIFIED
@export var poly_material: Material:
	set(value):
		poly_material = value
		if is_node_ready():
			_update()
@export var line_color: Color = Color(0.016, 0.243, 0.478):
	set(value):
		line_color = value
		if is_node_ready():
			_update()
@export var line_width: float = 0.5:
	set(value):
		line_width = value
		if is_node_ready():
			_update()

var _is_hovered := false
var _tooltip: Tooltip

func get_province_label(p: JapanProvinceArea.Province) -> String:
	if p == JapanProvinceArea.Province.UNSPECIFIED:
		return ''

	var label: String
	match p:
		JapanProvinceArea.Province.KII:
			label = tr('Kii')
		JapanProvinceArea.Province.SATSUMA:
			label = tr('Satsuma')
		JapanProvinceArea.Province.HYUUGA:
			label = tr('Hyūga')
		JapanProvinceArea.Province.HIGO:
			label = tr('Higo')
		JapanProvinceArea.Province.OOSUMI:
			label = tr('Ōsumi')
		JapanProvinceArea.Province.CHIKUGO:
			label = tr('Chukugo')
		JapanProvinceArea.Province.KOUZUKE:
			label = tr('Kōzuke')
		JapanProvinceArea.Province.HIZEN:
			label = tr('Hizen')
		JapanProvinceArea.Province.CHIKUZEN:
			label = tr('Chikuzen')
		JapanProvinceArea.Province.BUZEN:
			label = tr('Buzen')
		JapanProvinceArea.Province.BUNGO:
			label = tr('Bungo')
		JapanProvinceArea.Province.IKI:
			label = tr('Iki')
		JapanProvinceArea.Province.TSUSHIMA:
			label = tr('Tsushima')
		JapanProvinceArea.Province.TOSA:
			label = tr('Tosa')
		JapanProvinceArea.Province.SANUKI:
			label = tr('Sanuki')
		JapanProvinceArea.Province.IYO:
			label = tr('Iyo')
		JapanProvinceArea.Province.AWAJI:
			label = tr('Awaji')
		JapanProvinceArea.Province.NAGATO:
			label = tr('Nagato')
		JapanProvinceArea.Province.SUOU:
			label = tr('Suō')
		JapanProvinceArea.Province.AKI:
			label = tr('Aki')
		JapanProvinceArea.Province.BINGO:
			label = tr('Bingo')
		JapanProvinceArea.Province.BITCHUU:
			label = tr('Bitchū')
		JapanProvinceArea.Province.BIZEN:
			label = tr('Bizen')
		JapanProvinceArea.Province.MIMASAKA:
			label = tr('Mimasaka')
		JapanProvinceArea.Province.HARIMA:
			label = tr('Harima')
		JapanProvinceArea.Province.IWAMI:
			label = tr('Iwami')
		JapanProvinceArea.Province.IZUMO:
			label = tr('Izumo')
		JapanProvinceArea.Province.HOUKI:
			label = tr('Hōki')
		JapanProvinceArea.Province.OKI:
			label = tr('Oki')
		JapanProvinceArea.Province.INABA:
			label = tr('Inaba')
		JapanProvinceArea.Province.TAJIMA:
			label = tr('Tajima')
		JapanProvinceArea.Province.TANBA:
			label = tr('Tanba')
		JapanProvinceArea.Province.TANGO:
			label = tr('Tango')
		JapanProvinceArea.Province.SETTSU:
			label = tr('Settsu')
		JapanProvinceArea.Province.IZUMI:
			label = tr('Izumi')
		JapanProvinceArea.Province.YAMATO:
			label = tr('Yamato')
		JapanProvinceArea.Province.YAMASHIRO:
			label = tr('Yamashiro')
		JapanProvinceArea.Province.KAWACHI:
			label = tr('Kawachi')
		JapanProvinceArea.Province.WAKASA:
			label = tr('Wakasa')
		JapanProvinceArea.Province.ECHIZEN:
			label = tr('Echizen')
		JapanProvinceArea.Province.NOTO:
			label = tr('Noto')
		JapanProvinceArea.Province.ETCHUU:
			label = tr('Etchū')
		JapanProvinceArea.Province.ECHIGO:
			label = tr('Echigo')
		JapanProvinceArea.Province.SADO:
			label = tr('Sado')
		JapanProvinceArea.Province.HITACHI:
			label = tr('Hitachi')
		JapanProvinceArea.Province.KAGA:
			label = tr('Kaga')
		JapanProvinceArea.Province.IGA:
			label = tr('Iga')
		JapanProvinceArea.Province.ISE:
			label = tr('Ise')
		JapanProvinceArea.Province.SHIMA:
			label = tr('Shima')
		JapanProvinceArea.Province.OWARI:
			label = tr('Owari')
		JapanProvinceArea.Province.MIKAWA:
			label = tr('Mikawa')
		JapanProvinceArea.Province.TOUTOUMI:
			label = tr('Tōtōmi')
		JapanProvinceArea.Province.OUMI:
			label = tr('Ōmi')
		JapanProvinceArea.Province.SURUGA:
			label = tr('Suruga')
		JapanProvinceArea.Province.IZU:
			label = tr('Izu')
		JapanProvinceArea.Province.SAGAMI:
			label = tr('Sagami')
		JapanProvinceArea.Province.KAI:
			label = tr('Kai')
		JapanProvinceArea.Province.MUSASHI:
			label = tr('Musashi')
		JapanProvinceArea.Province.KAZUSA:
			label = tr('Kazusa')
		JapanProvinceArea.Province.SHIMOUSA:
			label = tr('Shimousa')
		JapanProvinceArea.Province.MINO:
			label = tr('Mino')
		JapanProvinceArea.Province.HIDA:
			label = tr('Hida')
		JapanProvinceArea.Province.SHINANO:
			label = tr('Shinano')
		JapanProvinceArea.Province.SHIMOTSUKE:
			label = tr('Shimotsuke')
		JapanProvinceArea.Province.MUTSU:
			label = tr('Mutsu')
		JapanProvinceArea.Province.DEWA:
			label = tr('Dewa')
		JapanProvinceArea.Province.EZO:
			label = tr('Ezo')
		JapanProvinceArea.Province.AWA_TOKUSHIMA, JapanProvinceArea.Province.AWA_CHIBA:
			label = tr('Awa')
		JapanProvinceArea.Province.SPECIAL_KYOTO:
			label = tr('Kyōto\nYamashiro')
		JapanProvinceArea.Province.SPECIAL_EDO:
			label = tr('Edo (present-day Tōkyō)\nMusashi')
		JapanProvinceArea.Province.SPECIAL_YAMANASHI:
			label = tr('Yamanashi Prefecture\nFormer Kai')
		JapanProvinceArea.Province.SPECIAL_TOKYO:
			return tr('Tōkyō')
		JapanProvinceArea.Province.SPECIAL_HOKKAIDOU:
			label = tr('Hokkaidō Prefecture\nFormer Ezo')
		JapanProvinceArea.Province.SPECIAL_OSAKA:
			label = tr('Ōsaka\nSettsu')
		JapanProvinceArea.Province.SPECIAL_NARA:
			label = tr('Nara\nYamato')
		_:
			label = tr(JapanProvinceArea.Province.find_key(p) as String).capitalize()
	return tr('{province_name} Province').format({province_name=label})

func _ready() -> void:
	assert(province != Province.UNSPECIFIED)
	for child in get_children():
		var poly := child as Polygon2D
		if Utils.ensure(poly != null):
			var line := Line2D.new()
			line.points = poly.polygon
			line.closed = true
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.antialiased = true
			line.z_index = 1
			poly.add_child(line)
	_update()

	set_process(Utils.is_in_editor())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_hovered := false

		if is_visible_in_tree():
			for child in get_children():
				var poly := child as Polygon2D
				if poly != null:
					var local_mouse := poly.get_local_mouse_position()
					if Geometry2D.is_point_in_polygon(local_mouse, poly.polygon):
						new_hovered = true
						break
		else:
			new_hovered = false

		if new_hovered and not _is_hovered:
			_is_hovered = true
			hovered.emit()
			if not _tooltip:
				_tooltip = _setup_tooltip()
			_tooltip.show_tooltip()
		elif not new_hovered and _is_hovered:
			_is_hovered = false
			unhovered.emit()
			_tooltip.hide_tooltip()

func _update() -> void:
	for child in get_children():
		var poly := child as Polygon2D
		if poly:
			poly.material = poly_material
			(poly.get_child(0) as Line2D).default_color = line_color
			(poly.get_child(0) as Line2D).width = line_width

func _process(_delta: float) -> void:
	# Editor-only.
	for child in get_children():
		var poly := child as Polygon2D
		if poly:
			(poly.get_child(0) as Line2D).points = poly.polygon

func _setup_tooltip() -> Tooltip:
	var rect := Rect2()
	var initialized := false
	for child in get_children():
		var poly := child as Polygon2D
		if poly:
			if not initialized:
				rect.position = poly.position + poly.polygon[0]
				initialized = true
			for point in poly.polygon:
				rect = rect.expand(poly.position + point)

	var tooltip_anchor := Control.new()
	tooltip_anchor.position = rect.position
	tooltip_anchor.size = rect.size
	tooltip_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tooltip_anchor)

	return Tooltip.create(
		tooltip_anchor, get_province_label(province),
		[Tooltip.RelativeDirection.ABOVE],
		[Tooltip.Alignment.CENTERED])
