extends RefCounted
## Supplemental, deterministic instrument feedback. No puzzle evidence is audio-only.
const RATE := 22050
const DURATIONS := {&"detent":.09,&"record":.22,&"replay":.38,&"flow":.42,&"align":.16,&"revise":.28,&"complete":.55}
static func select(action: StringName, accepted: bool, complete: bool) -> StringName:
	if not accepted: return &"revise"
	if complete: return &"complete"
	if action==&"replay": return &"replay"
	if action in [&"trial",&"cooling"]: return &"flow"
	if action in [&"capture",&"interpret"]: return &"record"
	if action==&"tune": return &"align"
	return &"detent"
static func make(cue: StringName) -> AudioStreamWAV:
	var duration: float=DURATIONS.get(cue,.09)
	var count := int(RATE*duration)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var random := RandomNumberGenerator.new()
	random.seed=1776
	var noise := 0.0
	for i in count:
		var t := float(i)/RATE
		var progress := t/duration
		var envelope := sin(PI*progress)
		var sample := 0.0
		match cue:
			&"flow":
				noise=lerpf(noise,random.randf_range(-1,1),.16)
				sample=(noise*.8+sin(TAU*110*t)*.15)*envelope
			&"replay":
				var phase := fmod(t,.12)
				sample=sin(TAU*420*phase)*exp(-phase*85)*smoothstep(0,.003,phase)*envelope
			&"complete":
				for note in 3:
					var age := t-note*.11
					if age>0: sample+=sin(TAU*[440,550,660][note]*age)*exp(-age*8)*smoothstep(0,.006,age)*.4
				sample*=smoothstep(0,.04,duration-t)
			&"revise": sample=sin(TAU*220*t)*envelope*.4
			&"record": sample=(sin(TAU*520*t)+sin(TAU*650*t))*.35*envelope
			&"align": sample=sin(TAU*360*t)*envelope*.55
			_: sample=sin(TAU*760*t)*exp(-t*38)*envelope
		bytes.encode_s16(i*2,int(clampf(sample*.22,-.22,.22)*32767))
	var wav := AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=RATE
	wav.data=bytes
	return wav
