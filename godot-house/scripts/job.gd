class_name Job
extends RefCounted
## One task on the job board. Done by a brother through a minigame (steps), by the other brother on his
## own (auto work, slower), or, for carry jobs, by bringing an object to a spot.

var id := ""
var title := ""
var station := Vector3.ZERO        # where you stand to do it
var steps: Array = []              # minigame steps, see Minigame
var needs_two := false             # the other brother must stand at the station (holding)
var requires: Array = []           # ids of jobs that must be done first
var pay := 60
var carry: Carryable = null        # carry jobs: bring `carry` to `carry_target`
var carry_target := Vector3.ZERO
var progress := 0.0                # auto work by the other brother, 0..1
var done := false

func _init(job_id: String, job_title: String, at: Vector3) -> void:
	id = job_id
	title = job_title
	station = at

func available(jobs: Dictionary) -> bool:
	if done:
		return false
	for r in requires:
		if not (jobs[r] as Job).done:
			return false
	return true

## The other brother can do it alone (no minigame needed, takes longer).
func solo_ok() -> bool:
	return not needs_two and carry == null
