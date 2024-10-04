extends ColorRect

const VU_COUNT:int = 32
const FREQ_MAX:float = 3000.0
const MIN_DB:float = 80.0

var spectrum_shader:ShaderMaterial = null
var analyzer:AudioEffectSpectrumAnalyzerInstance = null

func _ready():
	self.analyzer = AudioServer.get_bus_effect_instance(0, 0)
	self.spectrum_shader = self.material

func _process(_delta:float):
	var prev_hz:float = 0.0

	for i in range(VU_COUNT):
		var hz:float = (i + 1) * FREQ_MAX / VU_COUNT
		var mag:float = self.analyzer.get_magnitude_for_frequency_range(prev_hz, hz).length()
		self.spectrum_shader.set_shader_parameter("hz%d" % i, clamp((linear_to_db(mag) + MIN_DB) / MIN_DB, 0.0, 1.0))
		prev_hz = hz
