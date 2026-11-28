extends RefCounted

# Единый каталог полировки восьмого этапа: все длительности эффектов,
# размеры пула, параметры фоновых частиц и локальных звуков берутся из
# раздела presentation файла data/balance.json. Внешние аудиофайлы, сеть и
# онлайн-сервисы не используются: короткие сигналы создаются в памяти.

const DEFAULT_UI_REFRESH_SECONDS: float = 0.1
const DEFAULT_SAMPLE_SECONDS: float = 1.0
const DEFAULT_MIX_RATE: int = 22050
const DEFAULT_POOL_CAPACITY: int = 8
const WAV_SIGNED_LIMIT: int = 32767


static func section(balance: Dictionary) -> Dictionary:
	var value: Variant = balance.get("presentation", {})
	return value as Dictionary if value is Dictionary else {}


static func ui_refresh_seconds(balance: Dictionary) -> float:
	return clampf(float(section(balance).get("ui_refresh_seconds", DEFAULT_UI_REFRESH_SECONDS)), 0.02, 1.0)


static func _dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func interface_config(balance: Dictionary) -> Dictionary:
	var data: Dictionary = _dict(section(balance), "interface")
	return {
		"fonts": _dict(data, "fonts"),
		"minimum_sizes": _dict(data, "minimum_sizes"),
		"spacing": _dict(data, "spacing"),
		"layout": _dict(data, "layout"),
		"navigation": _dict(data, "navigation"),
		"hud": _dict(data, "hud"),
		"animations": _dict(data, "animations"),
	}


static func performance_config(balance: Dictionary) -> Dictionary:
	var data: Dictionary = section(balance)
	return {
		"sample_seconds": clampf(float(data.get("performance_sample_seconds", DEFAULT_SAMPLE_SECONDS)), 0.2, 10.0),
		"warning_fps": maxf(1.0, float(data.get("performance_warning_fps", 30.0))),
	}


static func away_config(balance: Dictionary) -> Dictionary:
	var data: Dictionary = _dict(section(balance), "away")
	return {
		"min_seconds": clampi(int(data.get("min_seconds", 60)), 0, 86400),
		"title": str(data.get("title", "С ВОЗВРАЩЕНИЕМ")),
		"claim_text": str(data.get("claim_text", "ЗАБРАТЬ")),
		"hint": str(data.get("hint", "Отряд продолжал бой, пока вас не было")),
	}


static func notice_config(balance: Dictionary) -> Dictionary:
	var data: Dictionary = _dict(section(balance), "notices")
	return {
		"capacity": clampi(int(data.get("capacity", 3)), 1, 6),
		"duration_seconds": clampf(float(data.get("duration_seconds", 3.6)), 0.5, 15.0),
		"fade_seconds": clampf(float(data.get("fade_seconds", 0.6)), 0.05, 5.0),
		"font_size": clampi(int(data.get("font_size", 20)), 18, 32),
	}


static func effect_pool_config(balance: Dictionary) -> Dictionary:
	var value: Variant = section(balance).get("effect_pool", {})
	var data: Dictionary = value as Dictionary if value is Dictionary else {}
	return {
		"capacity": clampi(int(data.get("capacity", DEFAULT_POOL_CAPACITY)), 1, 32),
		"label_duration_seconds": clampf(float(data.get("label_duration_seconds", 0.55)), 0.1, 2.0),
		"label_rise_pixels": maxf(1.0, float(data.get("label_rise_pixels", 52.0))),
		"label_font_size": clampi(int(data.get("label_font_size", 24)), 10, 48),
		"skill_font_size": clampi(int(data.get("skill_font_size", 15)), 10, 48),
		"flash_duration_seconds": clampf(float(data.get("flash_duration_seconds", 0.28)), 0.05, 2.0),
	}


static func particle_config(balance: Dictionary) -> Dictionary:
	var value: Variant = section(balance).get("ambient_particles", {})
	var data: Dictionary = value as Dictionary if value is Dictionary else {}
	var rgba_value: Variant = data.get("color_rgba", [])
	var rgba: Array = rgba_value as Array if rgba_value is Array else []
	var color: Color = Color(
		float(rgba[0]) if rgba.size() > 0 else 0.878,
		float(rgba[1]) if rgba.size() > 1 else 0.541,
		float(rgba[2]) if rgba.size() > 2 else 0.235,
		float(rgba[3]) if rgba.size() > 3 else 0.7,
	)
	return {
		"amount": clampi(int(data.get("amount", 12)), 1, 64),
		"lifetime_seconds": clampf(float(data.get("lifetime_seconds", 4.0)), 0.5, 20.0),
		"spread_degrees": clampf(float(data.get("spread_degrees", 28.0)), 0.0, 180.0),
		"gravity_y": float(data.get("gravity_y", -14.0)),
		"velocity_min": maxf(0.0, float(data.get("velocity_min", 18.0))),
		"velocity_max": maxf(0.0, float(data.get("velocity_max", 56.0))),
		"scale_min": clampf(float(data.get("scale_min", 0.3)), 0.05, 4.0),
		"scale_max": clampf(float(data.get("scale_max", 0.9)), 0.05, 4.0),
		"color": color,
	}


static func audio_config(balance: Dictionary) -> Dictionary:
	var value: Variant = section(balance).get("audio", {})
	var data: Dictionary = value as Dictionary if value is Dictionary else {}
	var mix_rate: int = clampi(int(data.get("mix_rate_hz", DEFAULT_MIX_RATE)), 8000, 48000)
	var source: Variant = data.get("sounds", {})
	var source_dict: Dictionary = source as Dictionary if source is Dictionary else {}
	var sounds: Dictionary = {}
	for key in source_dict.keys():
		var spec_value: Variant = source_dict[key]
		if spec_value is Dictionary:
			sounds[str(key)] = sound_spec(spec_value as Dictionary)
	return {
		"mix_rate": mix_rate,
		"voice_count": clampi(int(data.get("voice_count", 6)), 1, 16),
		"master_volume_db": clampf(float(data.get("master_volume_db", -8.0)), -60.0, 0.0),
		"sounds": sounds,
	}


static func sound_spec(source: Dictionary) -> Dictionary:
	var waveform: String = str(source.get("waveform", "sine")).to_lower()
	if waveform != "triangle":
		waveform = "sine"
	return {
		"waveform": waveform,
		"frequency_hz": clampf(float(source.get("frequency_hz", 220.0)), 20.0, 12000.0),
		"end_frequency_hz": clampf(float(source.get("end_frequency_hz", 220.0)), 20.0, 12000.0),
		"duration_seconds": clampf(float(source.get("duration_seconds", 0.12)), 0.02, 0.5),
		"amplitude": clampf(float(source.get("amplitude", 0.4)), 0.01, 1.0),
		"fade_seconds": clampf(float(source.get("fade_seconds", 0.01)), 0.001, 0.2),
		"volume_db": clampf(float(source.get("volume_db", -12.0)), -60.0, 0.0),
	}


static func build_stream(spec: Dictionary, mix_rate: int) -> AudioStreamWAV:
	var rate: int = clampi(mix_rate, 8000, 48000)
	var duration: float = float(spec.get("duration_seconds", 0.12))
	var frames: int = maxi(1, int(round(duration * float(rate))))
	var fade_frames: int = maxi(1, int(round(float(spec.get("fade_seconds", 0.01)) * float(rate))))
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	var phase: float = 0.0
	var amplitude: float = float(spec.get("amplitude", 0.4))
	var start_frequency: float = float(spec.get("frequency_hz", 220.0))
	var end_frequency: float = float(spec.get("end_frequency_hz", 220.0))
	var triangle: bool = str(spec.get("waveform", "sine")) == "triangle"
	for index in range(frames):
		var progress: float = float(index) / float(maxi(1, frames - 1))
		phase += lerpf(start_frequency, end_frequency, progress) / float(rate)
		var sine_value: float = sin(2.0 * PI * phase)
		var wave: float = asin(clampf(sine_value, -1.0, 1.0)) * 2.0 / PI if triangle else sine_value
		var attack: float = minf(1.0, float(index + 1) / float(fade_frames))
		var release: float = minf(1.0, float(frames - index) / float(fade_frames))
		var sample: int = int(round(clampf(wave * amplitude * attack * release, -1.0, 1.0) * float(WAV_SIGNED_LIMIT)))
		var unsigned: int = sample if sample >= 0 else sample + 65536
		data[index * 2] = unsigned & 255
		data[index * 2 + 1] = (unsigned >> 8) & 255
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
