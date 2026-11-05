class_name KanjiDrawingChallenge
extends Node2D

signal reset
signal succeeded(shape: KanjiShape)
signal closed

var card_type: CardType

var _closing := false
var _succeeded := true

func _ready() -> void:
	assert(card_type)
	(%PreviewCanvas as KanjiDrawingCanvas).show_preview(card_type.kanji_shape)
	(%DrawingCanvas as KanjiDrawingCanvas).restart_drawing(card_type.kanji_shape)
	(%TitleLabel as Label).text = tr('Inscribe Glyph: ') + tr(card_type.card_name)

	# Without this, we get the stroke_started text.
	(%PromptLabel as Label).text = tr('Draw the glyph on the right canvas, stroke by stroke.')

	(%ScrollPanel as ScrollPanel).animate_unroll()

func _enter_tree() -> void:
	UI.register_zoomable(%ScrollPanel as Control, 0.5, 0.5)

func _handle_esc() -> bool:
	close()
	return true

func close() -> void:
	if not _closing:
		_closing = true
		Utils.set_input_enabled(%ScrollPanel as Control, false)
		(%BG as FadedBackground).fade_out()
		await (%ScrollPanel as ScrollPanel).animate_roll()
		get_parent().remove_child(self)
		queue_free()
		closed.emit()

func _on_drawing_canvas_succeeded(shape: KanjiShape) -> void:
	succeeded.emit(shape)
	(%PromptLabel as Label).text = tr('Glyph inscribed successfully!')
	(%EndButton as Button).text = tr('Proceed')

func _on_drawing_canvas_error_start() -> void:
	(%PromptLabel as Label).text = tr('Start your stroke at the marked point!')

func _on_drawing_canvas_error_end() -> void:
	(%PromptLabel as Label).text = tr('Follow the stroke as closely as possible!')

func _on_drawing_canvas_stroke_started() -> void:
	(%PromptLabel as Label).text = tr('Continue on to the next stroke!')

func _on_restart_button_pressed() -> void:
	_succeeded = false
	(%DrawingCanvas as KanjiDrawingCanvas).restart_drawing(card_type.kanji_shape)
	(%PromptLabel as Label).text = tr('Draw the glyph on the right canvas, stroke by stroke.')
	(%EndButton as Button).text = tr('Give Up')
	reset.emit()

func _on_end_button_pressed() -> void:
	close()
