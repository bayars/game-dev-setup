class_name Day1
extends RefCounted
## Day 1 content: the first job (tutorial). The jobs teach every mechanic day 2 relies on:
## minigames, holding a sheet together, sending the other brother off to work, and carrying heavy loads
## alone (slow, loud) or together (fast, quiet).

const COUCH_TARGET := Vector3(2.0, 0, 2.7)
const DISHWASHER_TARGET := Vector3(5.1, 0, 0.75)

static func jobs(couch: Carryable, dishwasher: Carryable) -> Dictionary:
	var list: Array[Job] = []

	var j := Job.new("couch_in", "Carry the couch in from the van", Vector3.ZERO)
	j.carry = couch
	j.carry_target = COUCH_TARGET
	j.pay = 40
	list.append(j)

	j = Job.new("dishwasher_in", "Bring the dishwasher to the kitchen", Vector3.ZERO)
	j.carry = dishwasher
	j.carry_target = DISHWASHER_TARGET
	j.pay = 30
	list.append(j)

	j = Job.new("studs", "Fix the studs to the plates", Vector3(5.75, 0, 3.4))
	j.steps = [
		{"type": "timing", "hits": 4, "label": "Drive the screws into the bottom plate"},
		{"type": "timing", "hits": 3, "label": "Toe-screw the top of each stud"},
	]
	j.pay = 70
	list.append(j)

	j = Job.new("drywall", "Hang the drywall sheets", Vector3(5.75, 0, 4.6))
	j.needs_two = true
	j.requires = ["studs"]
	j.steps = [
		{"type": "hold", "seconds": 2.5, "label": "Lift the sheet onto the studs (the other brother holds it)"},
		{"type": "timing", "hits": 5, "label": "Screw the sheet off"},
		{"type": "hold", "seconds": 3.0, "label": "Tape and mud the seams"},
	]
	j.pay = 90
	list.append(j)

	j = Job.new("wiring", "Wire the new outlet to the junction box", Vector3(7.6, 0, 1.0))
	j.steps = [
		{"type": "sequence", "keys": ["2", "1", "3"], "names": {"1": "Black (live)", "2": "Copper (earth)", "3": "White (neutral)"},
			"label": "Connect earth first, then live, then neutral"},
		{"type": "hold", "seconds": 1.5, "label": "Fold the wires in and close the box"},
	]
	j.pay = 80
	list.append(j)

	j = Job.new("flooring", "Lay the laminate by the window", Vector3(7.7, 0, 4.9))
	j.steps = [
		{"type": "hold", "seconds": 2.0, "label": "Roll out the underlay"},
		{"type": "timing", "hits": 4, "label": "Tap the planks together"},
	]
	j.pay = 70
	list.append(j)

	j = Job.new("dishwasher", "Install the dishwasher", DISHWASHER_TARGET + Vector3(0, 0, 0.75))
	j.requires = ["dishwasher_in"]
	j.steps = [
		{"type": "sequence", "keys": ["1", "2", "3"], "names": {"1": "Water in", "2": "Drain hose", "3": "Power"},
			"label": "Connect water, then the drain, then power"},
		{"type": "hold", "seconds": 2.0, "label": "Level it and slide it under the counter"},
	]
	j.pay = 60
	list.append(j)

	j = Job.new("assemble", "Assemble the couch and the table", COUCH_TARGET + Vector3(0, 0, 1.0))
	j.requires = ["couch_in"]
	j.steps = [
		{"type": "hold", "seconds": 2.5, "label": "Unpack and bolt on the couch legs"},
		{"type": "timing", "hits": 3, "label": "Fix the table legs"},
	]
	j.pay = 50
	list.append(j)

	var out := {}
	for job in list:
		out[job.id] = job
	return out

const INTRO := [
	["Linda", "You must be the brothers. Come in, come in. Mind the boxes."],
	["Linda", "Today it's just the living room and the kitchen. The wall, the outlet, the floor by the window."],
	["Linda", "The couch and the dishwasher are in your van? Good. Cash at the end of the day, like we said."],
	["Tomas", "(quietly) Cash, no questions. We do this one right, Nico."],
	["Daniel", "Hi! I'm Daniel. Mind if I watch? I've always wanted to learn how walls are made."],
	["Nico", "Sure. Just stay clear of the tools."],
]

const HINTS := {
	"start": "The job board (left) lists today's work. Walk to a job and press E. Heavy boxes: lift with Tomas nearby (F: follow) to carry together.",
	"solo_carry": "Carrying alone is slow and loud: the rings show who can hear you. Press H to call Tomas, then lift together.",
	"pair_carry": "Carrying together: fast and quiet. Press E to put it down at the marked spot.",
	"needs_two": "This one needs two people. Send Tomas (button on the job board or right click), then start it.",
}

const DANIEL_LINES := {
	"studs": "So the studs carry everything? Can I hold the next one?",
	"drywall": "Let me hold the sheet next time, I'm stronger than I look.",
	"wiring": "Earth first. I'll remember that.",
	"flooring": "It clicks together like a puzzle!",
	"dishwasher": "Mom's going to love this. She hates washing up.",
	"assemble": "First one to sit on it! ...Okay, after you guys.",
	"couch_in": "That box looked heavy. You two make it look easy.",
	"dishwasher_in": "Do you always carry things in together?",
}

const PAY_LINES := [
	["Linda", "Look at that. You really are fast. Here, as agreed."],
	["Daniel", "Can I help again tomorrow? Please?"],
	["Tomas", "(in the van) We can send money home this week. If it stays like this..."],
	["Nico", "It will. Tomorrow, same as today. Nobody notices us, nobody asks."],
]
