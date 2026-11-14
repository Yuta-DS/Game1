extends RefCounted
## Three sources about one event, not three competing 'correct feelings'.
const TITLES := ["ARI'S ACCOUNT", "MECHANISM RECORD", "OFFER OF HELP"]
const ACCOUNTS := [
	"Ari: I felt frightened and ashamed when the light stopped.",
	"Test record: reducing flow closed the shutter; restoring flow released it.",
	"Helper: I can hold the reference plate while you align the light."]
const CONTRIBUTIONS := [
	"A real feeling, not proof of personal failure",
	"Measured behaviour of this mechanism",
	"An available way to collaborate"]
static func angle(view: int) -> float: return -clampi(view,0,2)*TAU/3
