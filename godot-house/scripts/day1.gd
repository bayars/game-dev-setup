class_name Day1
extends RefCounted
## Day 1 content: the first job (tutorial). The jobs teach every mechanic day 2 relies on: choosing the
## right tool and working on the spot in the install view, holding a sheet together, sending the other
## brother off to work, carrying heavy loads alone (slow, loud) or together (fast, quiet), and the stairs
## up to Daniel's room, where tomorrow's work is.
##
## Steps: {tool, text, kind = "spots" (click each hotspot) | "hold" (keep the button down) | "order"
## (hotspots in a set order), seconds (hold)}. The hotspots and what appears are in Worksite.

const COUCH_TARGET := Vector3(2.0, 0, 2.7)
const DISHWASHER_TARGET := Vector3(5.1, 0, 0.75)

static func jobs(couch: Carryable, dishwasher: Carryable) -> Dictionary:
	var list: Array[Job] = []

	var j := Job.new("couch_in", "Carry in the couch", Vector3.ZERO)
	j.carry = couch
	j.carry_target = COUCH_TARGET
	j.pay = 40
	list.append(j)

	j = Job.new("dishwasher_in", "Bring in the dishwasher", Vector3.ZERO)
	j.carry = dishwasher
	j.carry_target = DISHWASHER_TARGET
	j.pay = 30
	list.append(j)

	j = Job.new("studs", "Frame the new wall", Vector3(7.0, 0, 3.0))
	j.steps = [
		{"tool": "tape", "kind": "hold", "seconds": 1.5, "text": "Measure and mark the stud positions on the plate"},
		{"tool": "drill", "kind": "spots", "text": "Stand each stud on its mark and screw it down"},
		{"tool": "drill", "kind": "hold", "seconds": 1.5, "text": "Screw the top plate across the studs"},
	]
	j.pay = 70
	list.append(j)

	j = Job.new("drywall", "Hang the drywall", Vector3(7.0, 0, 4.2))
	j.needs_two = true
	j.requires = ["studs"]
	j.steps = [
		{"tool": "knife", "kind": "hold", "seconds": 1.2, "text": "Score and snap the last sheet to size"},
		{"tool": "sheet", "kind": "spots", "text": "Lift each sheet onto the studs (Tomas holds it while you fix it)"},
		{"tool": "drill", "kind": "spots", "text": "Screw the sheets to every stud"},
		{"tool": "taping", "kind": "spots", "text": "Tape the two seams"},
		{"tool": "mud", "kind": "hold", "seconds": 2.5, "text": "Mud over the tape and the screw heads"},
	]
	j.pay = 90
	list.append(j)

	j = Job.new("wiring", "Wire the new socket", Vector3(7.6, 0, 1.0))
	j.steps = [
		{"tool": "stripper", "kind": "hold", "seconds": 1.2, "text": "Strip the wire ends"},
		{"tool": "screwdriver", "kind": "order", "text": "Connect earth first, then live, then neutral"},
		{"tool": "plate", "kind": "spots", "text": "Fit the socket cover"},
	]
	j.pay = 80
	list.append(j)

	j = Job.new("flooring", "Lay the laminate", Vector3(7.7, 0, 4.9))
	j.steps = [
		{"tool": "underlay", "kind": "hold", "seconds": 1.5, "text": "Roll out the underlay"},
		{"tool": "planks", "kind": "spots", "text": "Lay the planks, row by row"},
		{"tool": "mallet", "kind": "hold", "seconds": 1.2, "text": "Tap the joints tight"},
	]
	j.pay = 70
	list.append(j)

	j = Job.new("dishwasher", "Install the dishwasher", DISHWASHER_TARGET + Vector3(0, 0, 0.75))
	j.requires = ["dishwasher_in"]
	j.steps = [
		{"tool": "knife", "kind": "hold", "seconds": 1.2, "text": "Cut the box open"},
		{"tool": "wrench", "kind": "spots", "text": "Connect the water and the drain hose"},
		{"tool": "level", "kind": "hold", "seconds": 1.5, "text": "Slide it in and level it"},
	]
	j.pay = 60
	list.append(j)

	j = Job.new("assemble", "Assemble couch and table", COUCH_TARGET + Vector3(1.5, 0, 0.9))
	j.requires = ["couch_in"]
	j.steps = [
		{"tool": "knife", "kind": "hold", "seconds": 1.2, "text": "Cut the box open"},
		{"tool": "allen", "kind": "spots", "text": "Bolt the legs onto the couch"},
		{"tool": "allen", "kind": "spots", "text": "Bolt the legs onto the table"},
	]
	j.pay = 50
	list.append(j)

	j = Job.new("measure", "Measure Daniel's room (upstairs)", Vector3(4.5, House.UP, 3.0))
	j.steps = [
		{"tool": "tape", "kind": "spots", "text": "Measure wall to wall for tomorrow's job"},
	]
	j.pay = 20
	list.append(j)

	var out := {}
	for job in list:
		out[job.id] = job
	return out

const INTRO := [
	["Linda", "You must be the brothers. Come in, come in. Mind the boxes."],
	["Linda", "Today it's the living room and the kitchen. The new wall, the socket, the floor by the window."],
	["Linda", "The couch and the dishwasher are in your van? Good. Cash at the end of the day, like we said."],
	["Linda", "And tomorrow, Daniel's room upstairs. Have a look at it before you go."],
	["Tomas", "(quietly) Cash, no questions. We do this one right, Nico."],
	["Daniel", "Hi! I'm Daniel. Mind if I watch? I've always wanted to learn how walls are made."],
	["Nico", "Sure. Just stay clear of the tools."],
]

const HINTS := {
	"start": "Today's jobs are on the left. Walk to a job and press E to start working on it.",
	"install": "Pick the right tool from the bag (click or 1-9), then click the glowing spots. Wheel zooms, Esc steps back.",
	"solo_carry": "Alone it's slow and loud: the rings show who can hear you. Press H to call Tomas and lift together.",
	"pair_carry": "Together it's fast and quiet. Press E at the marked spot to put it down.",
	"needs_two": "This one needs two. Send Tomas from the job list, or press H to call him, then start.",
	"stairs": "The stairs are in the east room, past the hallway.",
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
	"measure": "That's my room! Tomorrow you make it bigger, right? I'll help.",
}

const PAY_LINES := [
	["Linda", "Look at that. You really are fast. Here, as agreed."],
	["Daniel", "Can I help again tomorrow? Please?"],
	["Tomas", "(in the van) We can send money home this week. If it stays like this..."],
	["Nico", "It will. Tomorrow, same as today. Nobody notices us, nobody asks."],
]
