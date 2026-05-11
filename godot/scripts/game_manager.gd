extends Node

signal phase_changed(previous_phase: String, new_phase: String)
signal player_added(player_id: String, player_name: String)
signal player_removed(player_id: String)
signal scores_updated(scores: Dictionary)
signal decoy_round_started(target_name: String, emoji: String, index: int, total: int)
signal reveal_ready(emoji: String, author_name: String, phrases: Array)
signal score_ready(player_scores: Array, is_last: bool)
signal submission_progress(submitted: int, expected: int)

# --- Constants ---
const MIN_PLAYERS := 1
const MAX_PLAYERS := 6
const TOTAL_ROUNDS := 3
const SCORE_CORRECT_GUESS := 2
const SCORE_DECOY_FOOL := 1
const SCORE_CLARITY_BONUS := 1
const CLARITY_THRESHOLD := 0.5
const EMOJI_MAX_LENGTH := 100
const DECOY_MIN_LENGTH := 3
const DECOY_MAX_LENGTH := 50

# LCG constants for deterministic shuffle
const LCG_A := 9301
const LCG_C := 49297
const LCG_M := 233280

# --- State ---
var network: Node
var phrase_manager: Node

var players := {}
var creator_id := ""

var phase := "lobby"
var current_round := 1
var total_rounds := TOTAL_ROUNDS

var assignments := {}
var decoys := {}
var guesses := {}
var cumulative_scores := {}

# Sequential emoji processing
var emoji_processing_order: Array[String] = []
var current_emoji_index := -1
var current_sub_phase := ""

var current_emoji_decoys := {}
var current_emoji_guesses := {}

var started_at := 0
var ended_at := 0

const REVEAL_DURATION := 15.0
var _reveal_timer: Timer = null


func initialize(net: Node, phrases: Node) -> void:
	network = net
	phrase_manager = phrases
	network.player_joined.connect(_on_player_joined)
	network.player_rejoined.connect(_handle_player_rejoin)
	network.player_disconnected.connect(_on_player_disconnected)
	network.message_received.connect(_on_message_received)
	network.connected.connect(_on_network_connected)

	_reveal_timer = Timer.new()
	_reveal_timer.one_shot = true
	_reveal_timer.timeout.connect(_on_reveal_timer_timeout)
	add_child(_reveal_timer)


func _on_network_connected() -> void:
	network.create_session()


# --- Player Management ---

func _on_player_joined(player_id: String, player_name: String) -> void:
	if players.size() >= MAX_PLAYERS:
		network.send_to_player(player_id, "error", {"message": "Session is full"})
		return
	if phase != "lobby":
		network.send_to_player(player_id, "error", {"message": "Game already in progress"})
		return

	var is_first := players.is_empty()
	var color_index: int = players.size() % UI.PLAYER_COLORS.size()
	var player := {
		"id": player_id,
		"name": player_name,
		"is_connected": true,
		"is_creator": is_first,
		"joined_at": Time.get_ticks_msec(),
		"color_index": color_index,
	}
	if is_first:
		creator_id = player_id
	players[player_id] = player
	cumulative_scores[player_id] = 0

	player_added.emit(player_id, player_name)

	network.send_to_player(player_id, "join_confirmed", {
		"playerId": player_id,
		"colorIndex": color_index,
		"color": UI.PLAYER_COLOR_HEX[color_index],
		"sessionState": _get_lobby_state(),
	})

	network.send_to_all("player_joined", {
		"playerId": player_id,
		"playerName": player_name,
		"colorIndex": color_index,
		"color": UI.PLAYER_COLOR_HEX[color_index],
	})


func _on_player_disconnected(player_id: String) -> void:
	if not players.has(player_id):
		return
	players[player_id]["is_connected"] = false
	player_removed.emit(player_id)
	network.send_to_all("player_disconnected", {"playerId": player_id})


# --- Reconnection ---

func _handle_player_rejoin(new_player_id: String, player_name: String) -> void:
	# Find existing player by name
	var old_id := ""
	for pid in players:
		if players[pid]["name"] == player_name:
			old_id = pid
			break

	if old_id == "":
		# No match — treat as a new join if still in lobby
		if phase == "lobby":
			_on_player_joined(new_player_id, player_name)
		else:
			network.send_to_player(new_player_id, "error", {"message": "Player not found in this game"})
		return

	# Swap player ID if the relay assigned a new one
	if new_player_id != old_id:
		var player_data: Dictionary = players[old_id]
		players.erase(old_id)
		player_data["id"] = new_player_id
		players[new_player_id] = player_data

		if cumulative_scores.has(old_id):
			cumulative_scores[new_player_id] = cumulative_scores[old_id]
			cumulative_scores.erase(old_id)

		if assignments.has(old_id):
			assignments[new_player_id] = assignments[old_id]
			assignments.erase(old_id)

		# Update emoji processing order
		var idx := emoji_processing_order.find(old_id)
		if idx >= 0:
			emoji_processing_order[idx] = new_player_id

		if creator_id == old_id:
			creator_id = new_player_id

	players[new_player_id]["is_connected"] = true
	print("Player \"%s\" reconnected as %s" % [player_name, new_player_id])

	# Send them their current state
	_send_state_sync(new_player_id)


func _send_state_sync(player_id: String) -> void:
	var state := {
		"phase": phase,
		"currentSubPhase": current_sub_phase,
		"players": _get_lobby_state()["players"],
		"sessionCode": network.get_session_code(),
	}

	if assignments.has(player_id):
		state["myPhrase"] = assignments[player_id]["phrase"]
		state["myEmojiSubmitted"] = assignments[player_id]["emoji_string"] != ""

	if current_emoji_index >= 0 and current_emoji_index < emoji_processing_order.size():
		var target_id: String = emoji_processing_order[current_emoji_index]
		state["currentEmojiIndex"] = current_emoji_index
		state["totalEmojis"] = emoji_processing_order.size()
		if players.has(target_id):
			state["targetPlayerId"] = target_id
			state["targetPlayerName"] = players[target_id]["name"]
		if assignments.has(target_id):
			state["targetEmoji"] = assignments[target_id]["emoji_string"]

	network.send_to_player(player_id, "state_sync", state)


# --- Message Handling ---

func _on_message_received(type: String, payload: Dictionary, from: String) -> void:
	match type:
		"submit_emoji":
			_handle_submit_emoji(from, payload)
		"submit_decoy":
			_handle_submit_decoy(from, payload)
		"submit_guess":
			_handle_submit_guess(from, payload)


# --- Game Flow (called by host input) ---

func start_game() -> void:
	if players.size() < MIN_PLAYERS:
		push_warning("Not enough players")
		return
	if phase != "lobby":
		push_warning("Game already started")
		return

	started_at = Time.get_ticks_msec()
	current_round = 1
	_set_phase("dealing")
	_deal_phrases()

	network.send_to_all("game_started", {"phase": "dealing"})

	for pid in assignments:
		var a: Dictionary = assignments[pid]
		network.send_to_player(pid, "phrase_assigned", {
			"phrase": a["phrase"],
		})

	_set_phase("describing")


func advance_phase() -> void:
	match phase:
		"describing":
			_start_decoy_rounds()
		"decoy_rounds":
			if current_sub_phase == "final_scores":
				_end_game()
			else:
				_advance_sub_phase()


func _start_decoy_rounds() -> void:
	_set_phase("decoy_rounds")
	_initialize_emoji_processing()
	_broadcast_decoy_round()


func _advance_sub_phase() -> void:
	match current_sub_phase:
		"collecting_decoys":
			_start_guessing()
		"collecting_guesses":
			_do_reveal()
		"revealing":
			_advance_after_reveal()


func force_advance_sub_phase() -> void:
	_advance_sub_phase()


# --- Deal Phrases ---

func _deal_phrases() -> void:
	var player_ids := players.keys()
	var exclude_ids: Array[String] = []
	var phrases_needed := player_ids.size()
	var selected = phrase_manager.get_random_phrases(phrases_needed, exclude_ids)

	assignments.clear()
	for i in range(player_ids.size()):
		var pid: String = player_ids[i]
		var phrase: Dictionary
		if i < selected.size():
			phrase = selected[i]
		else:
			phrase = {"id": "", "text": "???", "category": "unknown", "difficulty": "easy"}
		assignments[pid] = {
			"phrase": phrase,
			"emoji_string": "",
		}


# --- Emoji Submission ---

func _handle_submit_emoji(player_id: String, payload: Dictionary) -> void:
	if phase != "describing":
		return
	if not assignments.has(player_id):
		return

	var emoji_string: String = payload.get("emojiString", "").strip_edges()
	if emoji_string.is_empty() or emoji_string.length() > EMOJI_MAX_LENGTH:
		network.send_to_player(player_id, "error", {"message": "Invalid emoji string"})
		return

	assignments[player_id]["emoji_string"] = emoji_string

	var submitted := _count_emoji_submissions()
	network.send_to_all("player_action", {
		"action": "emoji_submitted",
		"playerId": player_id,
		"submittedCount": submitted,
		"expectedCount": players.size(),
	})
	submission_progress.emit(submitted, players.size())

	if submitted >= players.size():
		_start_decoy_rounds()


# --- Sequential Emoji Processing ---

func _initialize_emoji_processing() -> void:
	emoji_processing_order.clear()
	for pid in players:
		if assignments.has(pid) and assignments[pid]["emoji_string"] != "":
			emoji_processing_order.append(pid)
	emoji_processing_order.shuffle()
	current_emoji_index = 0
	current_sub_phase = "collecting_decoys"
	current_emoji_decoys.clear()
	current_emoji_guesses.clear()


func _broadcast_decoy_round() -> void:
	if current_emoji_index >= emoji_processing_order.size():
		_end_game()
		return

	var target_id: String = emoji_processing_order[current_emoji_index]
	var assignment: Dictionary = assignments[target_id]
	var target_name: String = players[target_id]["name"]

	current_sub_phase = "collecting_decoys"
	current_emoji_decoys.clear()
	current_emoji_guesses.clear()

	var phrase_data: Dictionary = assignment["phrase"]
	network.send_to_all("decoy_round_started", {
		"targetPlayerId": target_id,
		"targetPlayerName": target_name,
		"emojiSelection": assignment["emoji_string"],
		"category": phrase_data["category"],
		"currentEmojiIndex": current_emoji_index,
		"totalEmojis": emoji_processing_order.size(),
	})

	decoy_round_started.emit(target_name, assignment["emoji_string"], current_emoji_index, emoji_processing_order.size())


# --- Decoy Submission ---

func _handle_submit_decoy(player_id: String, payload: Dictionary) -> void:
	if phase != "decoy_rounds" or current_sub_phase != "collecting_decoys":
		return

	var target_id: String = emoji_processing_order[current_emoji_index]
	if player_id == target_id:
		return

	var decoy_text: String = payload.get("decoyText", "").strip_edges()
	if decoy_text.length() < DECOY_MIN_LENGTH or decoy_text.length() > DECOY_MAX_LENGTH:
		network.send_to_player(player_id, "error", {"message": "Decoy must be %d-%d characters" % [DECOY_MIN_LENGTH, DECOY_MAX_LENGTH]})
		return

	current_emoji_decoys[player_id] = {
		"text": decoy_text,
		"author_id": player_id,
		"author_name": players[player_id]["name"],
		"submitted_at": Time.get_ticks_msec(),
	}

	var expected := players.size() - 1
	var submitted := current_emoji_decoys.size()

	network.send_to_all("player_action", {
		"action": "decoy_submitted",
		"playerId": player_id,
		"submittedCount": submitted,
		"expectedCount": expected,
	})
	submission_progress.emit(submitted, expected)

	if submitted >= expected:
		_start_guessing()


# --- Guessing ---

func _start_guessing() -> void:
	current_sub_phase = "collecting_guesses"
	current_emoji_guesses.clear()

	var target_id: String = emoji_processing_order[current_emoji_index]
	var all_phrases := _build_guessing_options(target_id)

	for pid in players:
		if pid == target_id:
			continue
		var personalized := _filter_own_decoy(all_phrases, pid)
		network.send_to_player(pid, "guessing_options", {
			"targetPlayerId": target_id,
			"targetPlayerName": players[target_id]["name"],
			"emojiSelection": assignments[target_id]["emoji_string"],
			"phrases": personalized,
			"currentEmojiIndex": current_emoji_index,
			"totalEmojis": emoji_processing_order.size(),
		})

	network.send_to_all("phase_changed", {
		"previousPhase": "collecting_decoys",
		"newPhase": "collecting_guesses",
	})


func _build_guessing_options(target_id: String) -> Array:
	var options: Array = []

	var target_assignment: Dictionary = assignments[target_id]
	var target_phrase: Dictionary = target_assignment["phrase"]
	options.append({
		"text": target_phrase["text"],
		"is_real": true,
		"author_id": target_id,
	})

	for pid in current_emoji_decoys:
		var decoy: Dictionary = current_emoji_decoys[pid]
		options.append({
			"text": decoy["text"],
			"is_real": false,
			"author_id": decoy["author_id"],
		})

	options = _shuffle_with_seed(options, current_emoji_index)
	return options


func _filter_own_decoy(all_phrases: Array, player_id: String) -> Array:
	var filtered: Array = []
	var removed_own := false
	for i in range(all_phrases.size()):
		var p: Dictionary = all_phrases[i]
		if not removed_own and not p["is_real"] and p["author_id"] == player_id:
			removed_own = true
			continue
		filtered.append({"text": p["text"], "optionId": i})
	return filtered


func _handle_submit_guess(player_id: String, payload: Dictionary) -> void:
	if phase != "decoy_rounds" or current_sub_phase != "collecting_guesses":
		return

	var target_id: String = emoji_processing_order[current_emoji_index]
	if player_id == target_id:
		return

	var selected_option_id: int = payload.get("selectedOptionId", -1)
	if selected_option_id < 0:
		return

	current_emoji_guesses[player_id] = {
		"selected_option_id": selected_option_id,
		"submitted_at": Time.get_ticks_msec(),
	}

	var expected := players.size() - 1
	var submitted := current_emoji_guesses.size()

	network.send_to_all("player_action", {
		"action": "guess_submitted",
		"playerId": player_id,
		"submittedCount": submitted,
		"expectedCount": expected,
	})
	submission_progress.emit(submitted, expected)

	if submitted >= expected:
		_do_reveal()


# --- Reveal & Scoring ---

func _do_reveal() -> void:
	var target_id: String = emoji_processing_order[current_emoji_index]
	var all_options := _build_guessing_options(target_id)
	var reveal_phrases := _build_reveal_data(target_id, all_options)

	var target_emoji: String = assignments[target_id]["emoji_string"]
	var target_name: String = players[target_id]["name"]

	current_sub_phase = "revealing"

	network.send_to_all("round_reveal", {
		"emojiSelection": target_emoji,
		"user": target_id,
		"userName": target_name,
		"phrases": reveal_phrases,
		"currentEmojiIndex": current_emoji_index,
		"totalEmojis": emoji_processing_order.size(),
	})
	reveal_ready.emit(target_emoji, target_name, reveal_phrases)
	_reveal_timer.start(REVEAL_DURATION)

	# Calculate scores silently — don't show until the end
	var score_deltas := _calculate_emoji_scores(target_id, all_options)
	_apply_score_deltas(score_deltas)
	_archive_current_emoji_data(target_id)


func _on_reveal_timer_timeout() -> void:
	if current_sub_phase == "revealing":
		_advance_after_reveal()


func _advance_after_reveal() -> void:
	_reveal_timer.stop()
	var is_last := current_emoji_index >= emoji_processing_order.size() - 1

	if is_last:
		_show_final_scores()
	else:
		current_emoji_index += 1
		current_emoji_decoys.clear()
		current_emoji_guesses.clear()
		_broadcast_decoy_round()


func _show_final_scores() -> void:
	current_sub_phase = "final_scores"
	var score_payload := _build_score_update_all()
	network.send_to_all("score_update", score_payload)
	scores_updated.emit(cumulative_scores.duplicate())
	score_ready.emit(score_payload["playerScores"], true)


func _build_score_update_all() -> Dictionary:
	var player_scores: Array = []
	for pid in players:
		var total_score: int = cumulative_scores.get(pid, 0)
		player_scores.append({
			"playerId": pid,
			"playerName": players[pid]["name"],
			"preRoundScore": 0,
			"postRoundScore": total_score,
			"pointsEarned": total_score,
			"breakdown": {
				"correctGuesses": 0,
				"fooledPlayers": 0,
				"clarityBonus": 0,
			},
		})
	player_scores.sort_custom(func(a, b): return a["postRoundScore"] > b["postRoundScore"])
	return {
		"roundNumber": current_round,
		"totalEmojis": emoji_processing_order.size(),
		"isLastEmoji": true,
		"playerScores": player_scores,
	}


func _build_reveal_data(_target_id: String, all_options: Array) -> Array:
	var reveal: Array = []
	for i in range(all_options.size()):
		var opt: Dictionary = all_options[i]
		var selected_by: Array = []
		for guesser_id in current_emoji_guesses:
			var guess: Dictionary = current_emoji_guesses[guesser_id]
			if guess["selected_option_id"] == i:
				selected_by.append(guesser_id)
		var author_id: String = opt["author_id"]
		var author_name := "Unknown"
		if players.has(author_id):
			author_name = players[author_id]["name"]
		reveal.append({
			"phrase": opt["text"],
			"user": author_id,
			"userName": author_name,
			"selectedBy": selected_by,
			"isReal": opt["is_real"],
			"selectionCount": selected_by.size(),
		})
	return reveal


func _calculate_emoji_scores(target_id: String, all_options: Array) -> Dictionary:
	var deltas := {}
	for pid in players:
		deltas[pid] = {"correct_guesses": 0, "fooled_players": 0, "clarity_bonus": 0, "total": 0}

	var correct_count := 0

	for guesser_id in current_emoji_guesses:
		var guess: Dictionary = current_emoji_guesses[guesser_id]
		var option_id: int = guess["selected_option_id"]

		if option_id < 0 or option_id >= all_options.size():
			continue

		var selected_opt: Dictionary = all_options[option_id]

		if selected_opt["is_real"]:
			deltas[guesser_id]["correct_guesses"] += SCORE_CORRECT_GUESS
			deltas[guesser_id]["total"] += SCORE_CORRECT_GUESS
			correct_count += 1
		else:
			var decoy_author: String = selected_opt["author_id"]
			if deltas.has(decoy_author):
				deltas[decoy_author]["fooled_players"] += SCORE_DECOY_FOOL
				deltas[decoy_author]["total"] += SCORE_DECOY_FOOL

	var num_guessers := current_emoji_guesses.size()
	if num_guessers > 0 and float(correct_count) / float(num_guessers) >= CLARITY_THRESHOLD:
		deltas[target_id]["clarity_bonus"] += SCORE_CLARITY_BONUS
		deltas[target_id]["total"] += SCORE_CLARITY_BONUS

	return deltas


func _apply_score_deltas(deltas: Dictionary) -> void:
	for pid in deltas:
		var delta: Dictionary = deltas[pid]
		if cumulative_scores.has(pid):
			cumulative_scores[pid] += delta["total"]
		else:
			cumulative_scores[pid] = delta["total"]


func _build_score_update(deltas: Dictionary, is_last: bool) -> Dictionary:
	var player_scores: Array = []
	for pid in players:
		var delta: Dictionary = deltas.get(pid, {"correct_guesses": 0, "fooled_players": 0, "clarity_bonus": 0, "total": 0})
		var post_score: int = cumulative_scores.get(pid, 0)
		var pre_score: int = post_score - delta["total"]
		player_scores.append({
			"playerId": pid,
			"playerName": players[pid]["name"],
			"preRoundScore": pre_score,
			"postRoundScore": post_score,
			"pointsEarned": delta["total"],
			"breakdown": {
				"correctGuesses": delta["correct_guesses"],
				"fooledPlayers": delta["fooled_players"],
				"clarityBonus": delta["clarity_bonus"],
			},
		})
	return {
		"roundNumber": current_round,
		"totalEmojis": emoji_processing_order.size(),
		"isLastEmoji": is_last,
		"playerScores": player_scores,
	}


func _archive_current_emoji_data(target_id: String) -> void:
	if not decoys.has(target_id):
		decoys[target_id] = []
	for pid in current_emoji_decoys:
		decoys[target_id].append(current_emoji_decoys[pid])

	for guesser_id in current_emoji_guesses:
		if not guesses.has(guesser_id):
			guesses[guesser_id] = {}
		guesses[guesser_id][target_id] = current_emoji_guesses[guesser_id]


func _end_game() -> void:
	ended_at = Time.get_ticks_msec()
	_set_phase("ended")

	var final_rankings := _build_final_rankings()
	network.send_to_all("game_ended", {
		"finalRankings": final_rankings,
		"gameStats": _build_game_stats(),
	})


func restart_game() -> void:
	assignments.clear()
	decoys.clear()
	guesses.clear()
	current_emoji_decoys.clear()
	current_emoji_guesses.clear()
	emoji_processing_order.clear()
	current_emoji_index = -1
	current_sub_phase = ""
	current_round = 1
	started_at = 0
	ended_at = 0
	_reveal_timer.stop()

	for pid in cumulative_scores:
		cumulative_scores[pid] = 0

	_set_phase("lobby")
	network.send_to_all("game_restarted", {
		"sessionState": _get_lobby_state(),
	})


func _build_final_rankings() -> Array:
	var ranking: Array = []
	for pid in players:
		ranking.append({
			"playerId": pid,
			"playerName": players[pid]["name"],
			"totalScore": cumulative_scores.get(pid, 0),
		})
	ranking.sort_custom(func(a, b): return a["totalScore"] > b["totalScore"])
	for i in range(ranking.size()):
		ranking[i]["position"] = i + 1
	return ranking


func _build_game_stats() -> Dictionary:
	var total_guesses := 0
	for guesser_id in guesses:
		for target_id in guesses[guesser_id]:
			total_guesses += 1
	return {
		"totalRounds": current_round,
		"totalGuesses": total_guesses,
		"playerCount": players.size(),
	}


# --- Phase Management ---

func _set_phase(new_phase: String) -> void:
	var old := phase
	phase = new_phase
	phase_changed.emit(old, new_phase)

	if old != new_phase:
		network.send_to_all("phase_changed", {
			"previousPhase": old,
			"newPhase": new_phase,
		})


# --- Deterministic Shuffle ---

func _shuffle_with_seed(arr: Array, seed_val: int) -> Array:
	var result := arr.duplicate()
	var rng := seed_val
	for i in range(result.size() - 1, 0, -1):
		rng = (rng * LCG_A + LCG_C) % LCG_M
		var j := int(float(rng) / float(LCG_M) * float(i + 1))
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


# --- Utilities ---

func _count_emoji_submissions() -> int:
	var count := 0
	for pid in assignments:
		if assignments[pid]["emoji_string"] != "":
			count += 1
	return count


func _get_lobby_state() -> Dictionary:
	var player_list: Array = []
	for pid in players:
		var p: Dictionary = players[pid]
		player_list.append({
			"id": p["id"],
			"name": p["name"],
			"isCreator": p["is_creator"],
			"isConnected": p["is_connected"],
			"colorIndex": p["color_index"],
			"color": UI.PLAYER_COLOR_HEX[p["color_index"]],
		})
	return {
		"phase": phase,
		"players": player_list,
		"sessionCode": network.get_session_code(),
	}


func get_player_count() -> int:
	return players.size()


func get_phase() -> String:
	return phase
