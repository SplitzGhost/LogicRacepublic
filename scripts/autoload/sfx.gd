extends Node
## Every sound in the game is synthesised at boot -- no audio files ship with
## the project. They are short, soft sine blips in the spirit of a system UI:
## nothing percussive, nothing loud.

const RATE := 32000
const VOICES := 8

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_build_bank()


func play(name: String, pitch := 1.0, gain := 1.0) -> void:
	if not bool(SaveData.get_setting("sfx", true)):
		return
	var stream: AudioStream = _bank.get(name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = pitch
	var vol: float = clampf(float(SaveData.get_setting("volume", 0.85)), 0.0, 1.0) * gain
	p.volume_db = -80.0 if vol <= 0.001 else linear_to_db(vol)
	p.play()


func haptic(ms := 12) -> void:
	if bool(SaveData.get_setting("haptics", true)):
		Input.vibrate_handheld(ms)


# --------------------------------------------------------------- synthesis ---
func _build_bank() -> void:
	# name -> [notes], each note: {f, t0, dur, amp, decay, detune, tri}
	_bank["tap"] = _render([
		{"f": 1180.0, "t0": 0.0, "dur": 0.055, "amp": 0.30, "decay": 70.0},
		{"f": 2360.0, "t0": 0.0, "dur": 0.035, "amp": 0.08, "decay": 110.0},
	], 0.09)
	_bank["select"] = _render([
		{"f": 760.0, "t0": 0.0, "dur": 0.07, "amp": 0.26, "decay": 55.0},
	], 0.10)
	_bank["toggle"] = _render([
		{"f": 520.0, "t0": 0.0, "dur": 0.05, "amp": 0.22, "decay": 70.0},
		{"f": 900.0, "t0": 0.035, "dur": 0.07, "amp": 0.22, "decay": 55.0},
	], 0.13)
	_bank["correct"] = _render([
		{"f": 784.0, "t0": 0.00, "dur": 0.14, "amp": 0.26, "decay": 22.0},
		{"f": 1046.5, "t0": 0.055, "dur": 0.16, "amp": 0.24, "decay": 20.0},
		{"f": 1568.0, "t0": 0.105, "dur": 0.22, "amp": 0.17, "decay": 16.0},
	], 0.36)
	_bank["wrong"] = _render([
		{"f": 233.0, "t0": 0.0, "dur": 0.20, "amp": 0.30, "decay": 14.0, "tri": true},
		{"f": 174.6, "t0": 0.09, "dur": 0.24, "amp": 0.26, "decay": 12.0, "tri": true},
	], 0.36)
	_bank["level"] = _render([
		{"f": 659.3, "t0": 0.0, "dur": 0.10, "amp": 0.20, "decay": 26.0},
		{"f": 987.8, "t0": 0.05, "dur": 0.18, "amp": 0.20, "decay": 18.0},
	], 0.24)
	_bank["over"] = _render([
		{"f": 392.0, "t0": 0.00, "dur": 0.26, "amp": 0.26, "decay": 9.0},
		{"f": 311.1, "t0": 0.16, "dur": 0.30, "amp": 0.24, "decay": 8.0},
		{"f": 233.1, "t0": 0.34, "dur": 0.55, "amp": 0.24, "decay": 6.0, "tri": true},
	], 0.95)
	_bank["rank_up"] = _render([
		{"f": 523.3, "t0": 0.00, "dur": 0.14, "amp": 0.20, "decay": 18.0},
		{"f": 659.3, "t0": 0.08, "dur": 0.14, "amp": 0.20, "decay": 18.0},
		{"f": 784.0, "t0": 0.16, "dur": 0.16, "amp": 0.20, "decay": 16.0},
		{"f": 1046.5, "t0": 0.24, "dur": 0.50, "amp": 0.22, "decay": 7.0},
	], 0.85)
	_bank["tick"] = _render([
		{"f": 1600.0, "t0": 0.0, "dur": 0.03, "amp": 0.16, "decay": 150.0},
	], 0.05)
	_bank["whoosh"] = _render([
		{"f": 300.0, "t0": 0.0, "dur": 0.18, "amp": 0.10, "decay": 20.0, "sweep": 2.6},
	], 0.22)


func _render(notes: Array, total: float) -> AudioStreamWAV:
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for note: Dictionary in notes:
		var f0: float = note["f"]
		var t0: float = note["t0"]
		var dur: float = note["dur"]
		var amp: float = note["amp"]
		var decay: float = note.get("decay", 20.0)
		var tri: bool = note.get("tri", false)
		var sweep: float = note.get("sweep", 1.0)
		var start := int(t0 * RATE)
		var count := int(dur * RATE)
		for i in count:
			var idx := start + i
			if idx >= n:
				break
			var t := float(i) / float(RATE)
			var f: float = lerpf(f0, f0 * sweep, t / maxf(dur, 0.0001))
			var phase := TAU * f * t
			var s := sin(phase)
			if tri:
				# Soft odd-harmonic body for the "failure" cues.
				s = 0.78 * s + 0.22 * sin(phase * 3.0)
			# Exponential decay with a 4 ms attack so nothing clicks.
			var env: float = exp(-decay * t) * minf(1.0, t / 0.004)
			# Fade the tail to zero to avoid a discontinuity at note end.
			env *= clampf((dur - t) / 0.012, 0.0, 1.0)
			buf[idx] += s * env * amp
	return _to_wav(buf)


func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
