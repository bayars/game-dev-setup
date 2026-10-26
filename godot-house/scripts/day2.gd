class_name Day2
extends RefCounted
## Day 2 content: an ordinary morning of work in Daniel's room (upstairs), the lines around it, and the
## accident cases (resources/accidents) and stage scenarios (resources/scenarios) loaded from data.

const UP := House.UP

static func jobs() -> Dictionary:
	var list: Array[Job] = []
	var j := Job.new("closet_studs", "Frame the closet wall", Vector3(6.3, UP, 1.8))
	j.steps = [
		{"tool": "tape", "kind": "hold", "seconds": 1.5, "text": "Mark the stud positions on the plate"},
		{"tool": "drill", "kind": "spots", "text": "Stand each stud on its mark and screw it down"},
		{"tool": "drill", "kind": "hold", "seconds": 1.5, "text": "Screw the top plate across the studs"},
	]
	j.pay = 70
	list.append(j)

	j = Job.new("closet_drywall", "Board the closet wall", Vector3(6.1, UP, 1.8))
	j.needs_two = true
	j.requires = ["closet_studs"]
	j.steps = [
		{"tool": "sheet", "kind": "spots", "text": "Lift each sheet onto the studs (someone holds it while you fix it)"},
		{"tool": "drill", "kind": "spots", "text": "Screw the sheets to every stud"},
		{"tool": "taping", "kind": "spots", "text": "Tape the seam"},
		{"tool": "mud", "kind": "hold", "seconds": 2.5, "text": "Mud over the tape and the screw heads"},
	]
	j.pay = 90
	list.append(j)

	j = Job.new("skirting", "Nail on the skirting boards", Vector3(0.9, UP, 4.0))
	j.steps = [
		{"tool": "tape", "kind": "hold", "seconds": 1.2, "text": "Measure the wall for the boards"},
		{"tool": "nailgun", "kind": "spots", "text": "Nail each board along the wall"},
	]
	j.pay = 60
	list.append(j)

	j = Job.new("light", "Fit the ceiling light", Vector3(4.5, UP, 3.7))
	j.steps = [
		{"tool": "stripper", "kind": "hold", "seconds": 1.2, "text": "Strip the cable ends at the ceiling"},
		{"tool": "screwdriver", "kind": "order", "text": "Connect earth first, then live, then neutral"},
		{"tool": "fitting", "kind": "spots", "text": "Fit the lamp"},
	]
	j.pay = 50
	list.append(j)

	var out := {}
	for job in list:
		out[job.id] = job
	return out

## Every accident case in resources/accidents, sorted by id (they rotate run by run).
## After the accident: work that never runs out, so Tomas can keep the house sounding normal.
static func keep_working() -> Job:
	var j := Job.new("keep_working", "Keep the work going (sanding, drilling)", Vector3(3.2, UP, 4.4))
	j.auto_only = true
	j.pay = 0
	j.steps = [{"tool": "drill", "kind": "spots", "text": "Make it sound like an ordinary day"}]
	return j

static func cases() -> Array[AccidentCase]:
	var out: Array[AccidentCase] = []
	out.assign(_load_all("res://resources/accidents/"))
	return out

static func scenarios() -> Array[StageScenario]:
	var out: Array[StageScenario] = []
	out.assign(_load_all("res://resources/scenarios/"))
	return out

static func _load_all(dir: String) -> Array:
	var out := []
	var files := ResourceLoader.list_directory(dir)
	var names := Array(files)
	names.sort()
	for f in names:
		if f.ends_with(".tres") or f.ends_with(".res"):
			out.append(load(dir + f))
	return out

static func pick_case(id: String, run: int) -> AccidentCase:
	var all := cases()
	for c in all:
		if c.id == id:
			return c
	return all[run % all.size()]

const INTRO := [
	["Linda", "Morning! Daniel's been up since six. Old clothes on and everything, ready to work."],
	["Robert", "So you're the brothers. Linda says you're quick. I'm off to the office, back around lunch."],
	["Daniel", "Today it's my room, right? Can I help? I'll hold stuff. I'll be careful, I promise."],
	["Tomas", "(quietly) Let him hand us things. Nothing heavy, nothing sharp."],
	["Nico", "Upstairs, then. Daniel, you stay where I can see you."],
]

const HINTS := {
	"start": "Today's work is upstairs in Daniel's room. The stairs are in the east room, past the hallway.",
	"daniel": "Daniel wants to help with this job. He'll stand by and hand you things.",
}

const DANIEL_LINES := {
	"closet_studs": "A closet! I'm putting my drum kit in there.",
	"closet_drywall": "Now it looks like a real wall.",
	"skirting": "Mom always said this room looked unfinished.",
	"light": "Finally I can read in bed.",
}

## Daniel's lines while he watches (one at a time, now and then).
const CHATTER := [
	"Do you guys do this every day? Like, every single day?",
	"Where did you learn all this? Back home?",
	"Mom says you're the best she's had. Don't tell her I told you.",
	"I want to do this when I'm older. Or be a drummer.",
	"Can I keep the offcuts? For a shelf, maybe.",
]

const CHOICE_LINES := [
	["Tomas", "Nico, listen to me. No papers. No insurance. Cash in an envelope."],
	["Tomas", "It's our site, our tools. They will say we did this. They will put us on a plane, or in a cell."],
	["Tomas", "Nobody saw. Nobody knows yet. Please."],
]

const COVER_LINES := [
	["Nico", "...Not up here. If they find him, it can't be up here."],
	["Tomas", "Then we move him. Together, quietly. Somewhere it could have happened to him on his own."],
]

const TRUTH := [
	"You call an ambulance and kneel next to him until it comes.",
	"The police arrive before the paramedics leave.",
	"No permits, no contract, no insurance. Cash in an envelope, two men nobody hired.",
	"It was your site and your tools, so it was your negligence. Then it was manslaughter.",
	"There is no lawyer who will take the case for what you have.",
	"Tomas is put on a plane eleven days later. You are still waiting for a trial date.",
	"Telling the truth was the right thing. It was never going to be enough.",
]
