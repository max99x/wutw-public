@tool
class_name MarkedUpLabel
extends RichTextLabel

enum LinkMode { NONE, HINT, EXPAND, LINK }

const MAX_EXPANDED_LENGTH := 1400

@export var tooltip_directions: Array[Tooltip.RelativeDirection] = [Tooltip.RelativeDirection.BELOW]
@export var tooltip_alignments: Array[Tooltip.Alignment] = [Tooltip.Alignment.CENTERED]

var _markedup_text: String
var _saved_mouse_filter: MouseFilter
var _tooltips: Dictionary[String, Tooltip]

func _ready() -> void:
	meta_hover_started.connect(_on_meta_hovered)
	meta_hover_ended.connect(_on_meta_unhovered)
	meta_clicked.connect(_on_meta_clicked)
	_saved_mouse_filter = mouse_filter  # Just for safety.

func _exit_tree() -> void:
	for tooltip: Tooltip in _tooltips.values():
		tooltip.destroy.call_deferred()
	_tooltips.clear()

func _on_meta_hovered(meta_string: String) -> void:
	if meta_string.begins_with('term:card.') or not meta_string.begins_with('term:'):
		# Prevent clicks on links from bubbling up.
		_saved_mouse_filter = mouse_filter
		mouse_filter = Control.MOUSE_FILTER_STOP
	if not meta_string.begins_with('term:'):
		return
	var term_id := meta_string.substr(5)
	var term := Term.get_all_terms()[term_id]
	if term_id not in _tooltips:
		var term_text: String
		if term is CardType:
			term_text = '<related_term:%s>' % term.get_term_id()
		else:
			term_text = ('<header_font_size>[b]%s[/b][/font_size]\n\n%s' %
				[term.get_term_name(true), term.get_markedup_description()])
		_tooltips[term_id] = Tooltip.create(self, term_text, tooltip_directions, tooltip_alignments)
		if term is CardType:
			_tooltips[term_id].preferred_extras_directions = [Tooltip.RelativeDirection.ABOVE, Tooltip.RelativeDirection.LEFT]
	_tooltips[term_id].show_tooltip()
	GlobalContextHighlight.request(ContextHighlight.terms(self, [term]))

func _on_meta_unhovered(meta_string: String) -> void:
	if meta_string.begins_with('term:card.') or not meta_string.begins_with('term:'):
		mouse_filter = _saved_mouse_filter
	if not meta_string.begins_with('term:'):
		return
	var term_id := meta_string.substr(5)
	if term_id in _tooltips:
		_tooltips[term_id].hide_tooltip()
	GlobalContextHighlight.retract_request(self)

func _on_meta_clicked(meta_string: String) -> void:
	if meta_string.begins_with('art'):
		ArtViewer.open_link(meta_string)
	elif meta_string.begins_with('museum'):
		MuseumBrowser.open_link(meta_string)
	elif meta_string.begins_with('shard_type'):
		ShardExplorer.open_link(meta_string)
	elif meta_string.begins_with('term:card.'):
		CardDetails.open_link(meta_string)
	elif meta_string.begins_with('http'):
		OS.shell_open(meta_string)
	elif not meta_string.begins_with('term'):
		push_error('Unrecognized meta string format: ', meta_string)

func set_markedup_text(markedup_text: String, link_mode: LinkMode = LinkMode.NONE) -> Term.ParseResult:
	_markedup_text = markedup_text
	var parsed := Term.parse(markedup_text, link_mode == LinkMode.LINK)
	if parsed.linked_terms:
		match link_mode:
			LinkMode.NONE:
				pass  # Nothing to add.
			LinkMode.HINT:
				parsed.bbcode_text += tr('\n\n[i]Hold %s for details.[/i]') % InputPrompts.get_input_markup(
					InputPrompts.InputType.CTRL)
			LinkMode.EXPAND:
				parsed.bbcode_text += '[hr width=100%]\n'
				var effective_max_length := roundi(MAX_EXPANDED_LENGTH / GameSettings.Interface.tooltip_font_scale.value())
				var expanded := expand_links(
					parsed.linked_terms.keys(), effective_max_length - parsed.bbcode_text.length())
				parsed.bbcode_text += expanded.bbcode_text
				for linked_term in expanded.linked_terms:
					parsed.linked_terms[linked_term] = true
			LinkMode.LINK:
				pass  # Already handled in parse()

	clear()
	append_text(parsed.bbcode_text)

	return parsed

func get_markedup_text() -> String:
	return _markedup_text

static func expand_links(links: Array[Term], max_length: int = MAX_EXPANDED_LENGTH) -> Term.ParseResult:
	var result := Term.ParseResult.new()

	var prioritized: Array[Term] = links.duplicate()
	prioritized.sort_custom(func(a: Term, b: Term) -> bool:
		if a.get_term_priority() == b.get_term_priority():
			return links.find(a) < links.find(b) # Ensure stable sort.
		else:
			return a.get_term_priority() > b.get_term_priority()
	)

	var pieces: Array[String] = []
	var first := true
	var remaining_length := max_length
	for term: Term in prioritized:
		var new_pieces: Array[String] = []
		var parsed_detail := Term.parse(term.get_markedup_description())
		if first:
			first = false
		else:
			new_pieces.append('\n\n')
		new_pieces.append('[b]')
		new_pieces.append(term.get_term_name(true))
		new_pieces.append('[/b]: ')
		new_pieces.append(parsed_detail.bbcode_text)
		for linked_term in parsed_detail.linked_terms:
			result.linked_terms[linked_term] = true
		var new_block := ''.join(new_pieces)
		if new_block.length() <= remaining_length:
			pieces.append(new_block)
			remaining_length -= new_block.length()
		else:
			break

	result.bbcode_text = ''.join(pieces)
	return result
