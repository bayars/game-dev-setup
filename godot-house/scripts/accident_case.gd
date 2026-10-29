class_name AccidentCase
extends Resource
## One way the accident on day 2 happens (resources/accidents/*.tres). Story2 takes one per run, in turn;
## a new case needs no code: the job and step it interrupts, what falls or fires, where Daniel stands,
## the injury the police will see, how loud it was, the signs it leaves and the lines around it.

@export var id := ""
@export var title := ""
@export var job_id := ""                  # the day 2 job it happens in
@export var step := 0                     # .. during this install step
@export var after_spots := 1              # .. once this many of its hotspots are done
@export var what := ""                    # "stud" | "sheet" | "nailgun": what moves in the cut-scene
@export var injury := ""                  # "blunt" | "crush" | "puncture"
@export var noise_radius := 10.0
@export var noise_what := "a heavy crash"
@export var tomas_away := false           # Tomas has gone down to the van: Daniel holds instead
@export var daniel_at := Vector3.ZERO     # where Daniel stands helping
@export var fall := Vector3.ZERO          # the push the body gets (direction and strength)
@export var tokens: Array = []            # [{id, label, offset (from the body), seconds, item, main}]
@export var before: Array = []            # [[who, text]] just before
@export var after: Array = []             # [[who, text]] once it has happened
