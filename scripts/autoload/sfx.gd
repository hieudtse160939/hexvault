extends Node
## Pooled sound effects + looping music.

const POOL_SIZE: int = 16
const MIN_GAP_MS: int = 35 # same sound cannot retrigger faster than this

var _streams: Dictionary = {}
var _music_paths: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_played: Dictionary = {}
var _music: AudioStreamPlayer
var _current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var text: String = FileAccess.get_file_as_string("res://assets/audio/audio_manifest.json")
	var parsed: Variant = JSON.parse_string(text)
	var meta: Dictionary = parsed if parsed is Dictionary else {}
	var sfx: Dictionary = meta.get("sfx", {})
	for k: String in sfx:
		_streams[k] = str(sfx[k])
	_music_paths = meta.get("music", {})
	for i: int in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)


func _stream(name: String) -> AudioStream:
	var v: Variant = _streams.get(name, null)
	if v is String:
		var s: AudioStream = load(v) as AudioStream
		_streams[name] = s
		return s
	return v as AudioStream


func play(name: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if name.is_empty() or not _streams.has(name):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < MIN_GAP_MS:
		return
	_last_played[name] = now
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _stream(name)
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(name: String) -> void:
	if name == _current_music and _music.playing:
		return
	_current_music = name
	var path: String = str(_music_paths.get(name, ""))
	if path.is_empty():
		_music.stop()
		return
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_current_music = ""
	_music.stop()


func has_sound(name: String) -> bool:
	return _streams.has(name)
