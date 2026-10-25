# Off the Books: design (story bible, systems, milestones)

Source of truth for Game 3. Approved plan, kept up to date as milestones land.

## Context

A new third game, after Dodger (2D) and Walk Home (3D). Two brothers, immigrants without work permits, do cash-in-hand renovation work in a family home. Five people live there. One of them, Daniel, watches and helps. On day 2 an accident kills him. Telling the truth is never accepted, because the brothers would be blamed regardless. So the player, together with the brother, has to stage the death as an accident unrelated to them, while the other four residents look for Daniel. The game ends when the residents find the body. A police investigation cinematic follows and judges the scene, with success or fail reasons listed.

Decisions:
- **View:** isometric camera on full 3D rendering. Forward+ rendering is reused from Walk Home, and walls are cut away so everything stays readable.
- **Story:** grim drama with many branching endings.
- **Assets:** our own Blender scripts plus CC0 packs (Kenney, Quaternius, Poly Haven) as fill.
- **Brothers:** Nico (player) and Tomas. Their home country is never named, and the names are not Turkish.
- **Rating:** 18+. Content warning at start. Option to soften the accident close-ups (cut to black or blur).

Design guardrail: concealment, evidence and investigation are **game-defined rules** (tokens, timelines, witness memory, plausibility checks per scenario). They are not real forensic or police-evasion techniques.

## Structure: two days, then the investigation

### Day 1: Tutorial, the first job (about 15 to 20 min)
- Arrival cutscene: the van, Linda (the owner) gives the tour, and the job board for the living room and kitchen.
- Every later mechanic is taught through normal work:

| Mechanic | Taught by |
|---|---|
| Work tasks | The install view: the camera moves in on the job, the tool bag opens as a tray, you pick the right tool and work on glowing hotspots in the scene while the brother plays the matching clip with the tool in hand. Every piece appears in the house (studs stand up, drywall sheets are lifted, screwed, taped and mudded; socket, laminate, dishwasher, couch and table). Wrong tool or wrong order is a mistake; a hammer where none is needed or a wrong wire is loud |
| Switching control | Tab switches between Nico and Tomas. Each has his own task queue |
| Orders to the brother | "Go work on X", "Keep Linda busy", "Watch the hallway", "Follow me", "Help me carry" |
| Carrying heavy things | **Carrying the couch alone:** slow and loud (noise rings that residents hear). **Carrying with both brothers:** fast and quiet. This is exactly how the body moves on day 2 |
| Residents | Their schedules, vision cones, the noise meter and the Seen log (what they noticed) |
| Clock | Pay at the end of the day. The cash and the pressure set up the story |

- Daniel is introduced as friendly and helpful. He offers to hold things, which seeds day 2.

### Day 2: A normal working day that turns (main game)
1. **Morning routine.** It should feel like an ordinary job day: new tasks, small talk, Daniel helping.
2. **The accident.** It happens upstairs, in Daniel's room (the attic conversion that is day 2's job), so moving the body means the stairs: slower, louder alone, and past more of the house. It differs per playthrough (see Accident cases). A **zoom cinematic** cuts from the isometric view to a close camera on what happened (slow push-in, sound drops out, heartbeat), then pulls back to the iso view.
3. **The choice moment.**
   - **"Call for help / tell the truth"** is always available.
   - Truth ending: it always ends in an unjust outcome card, showing why it isn't accepted (blamed for negligence, no permits, no lawyer, deportation). It is printed as text and closes the run.
4. **The cover-up phase.** About 20 to 30 real minutes on a game clock. The other four residents notice Daniel is gone and search on their own schedules. The player and Tomas:
   - **Move the body.** One person is slow and loud. Two people are fast and quiet, but both are then busy and visible.
   - **Keep up the work facade.** Unfinished work, missing noise or idle brothers raise suspicion. Send Tomas to "go do some work" so the house sounds normal.
   - **Deflect residents.** Talk, send them to the wrong place, make an excuse.
   - **Stage the accident scenario.** Choose a location in the house and a cause that plausibly has nothing to do with the brothers. Arrange the scene with interactable props, and fix evidence tokens.
5. **Discovery.** The game's final trigger is that one of the four residents finds the body. This happens on its own when their search reaches it, or the player can lead someone there on purpose.
6. **Police investigation cinematic.** Detectives arrive and walk the scene in a cinematic camera sequence. Each check is shown as a beat with a PASS or FAIL reason, then the ending card.

### Accident cases (picked at the start of day 2, rotating or random per run)
| Case | Opening event | What it changes |
|---|---|---|
| Falling stud | A badly fixed stud falls from the frame | Evidence in Daniel's room, heavy-item tokens |
| Nail gun | The nail gun fires when Daniel picks it up | The tool is evidence; the noise was heard |
| Drywall sheet | A sheet tips over while Daniel holds it | Board damage, a dust trail |
| Ladder (later) | Ladder slips during ceiling work | Height and fall plausibility |

Each case is a data resource (`AccidentCase.tres`) with:
- its cinematic
- its starting evidence tokens
- which staged scenarios are plausible for it

New cases are added without code changes.

### Investigation checks (game rules, shown as success or fail reasons)
- **Scene plausibility:** does the staged cause fit the injury type from the accident case, the location and the props?
- **Timeline:** do the residents' Seen logs (who saw whom, where, when) contradict the scenario?
- **Trail:** are there unresolved evidence tokens between the real accident site and the staged site? Moving the body alone leaves more tokens.
- **Work alibi:** did the house sound and look like a normal workday (task progress, noise log)?
- **Brother's stress:** if Tomas was seen panicking or was left alone with residents too long, he may slip in his interview beat.

### Endings (many branches)
| Ending | Condition |
|---|---|
| **Clean** | All checks pass; it is ruled an accident unrelated to the brothers. Epilogue: paid, but haunted |
| **Shadow of doubt** | Minor fails; the case stays open and the brothers leave town |
| **Tomas breaks** | Brother's stress too high; he confesses in the interview |
| **Caught in the timeline** | A resident's memory contradicts the story |
| **The trail** | Evidence links the real site to the staged site |
| **Found too early** | A resident finds the body before any staging; the police see the original scene |
| **One brother takes the fall** | Late choice: one brother sacrifices himself so the other goes free |
| **Truth** | Always the unjust-outcome card |

## Characters
- **Nico:** the player, older brother, steady.
- **Tomas:** younger brother, playable through Tab and given orders. Has a stress meter and his own actions: work, distract, watch, help carry, clean a token.
- **Daniel:** the curious, helpful son, and the victim.
- **The four residents who search:**

| Resident | Who | In the search |
|---|---|---|
| Linda | Mother and owner | Checks the work; the most attentive searcher |
| Robert | Father | Comes home in the afternoon; searches the garage and outside |
| Sofia | Teen daughter | Mostly in her room; her phone and messages create Seen-log entries |
| Grandma Rose | Grandmother | Slow; remembers small details |

## Tech plan (reuses the pipeline)

- **Project:** `godot-house/`, Godot 4.7.2, Forward+.
  - Copy `godot-3d/scripts/graphics.gd` (presets, PBR library) and retune it for interiors: SSAO/SSIL, warm interior lamps, afternoon-to-night light.
  - Copy `godot-3d/shaders/post.gdshader`.
- **Isometric 3D camera** (`iso_camera.gd`):
  - Perspective camera with a narrow FOV (about 20°) at about 45° yaw and 40° pitch, so the scene keeps 3D depth with an isometric layout. Q/E rotate in 90° steps, mouse wheel zooms.
  - Walls and ceilings between the camera and the player fade out (`shaders/cutaway.gdshader`). Upper floors hide when you are downstairs.
- **Cinematic system** (`cinematic.gd`): Camera3D sequences built with Tweens and AnimationPlayer. Used for the accident zoom, discovery and the police walkthrough. Includes letterbox bars and depth of field from `Graphics.set_portrait`-style controls.
- **Movement:** click to move with NavigationAgent3D on a NavigationRegion3D, plus WASD. Interaction on E. Tab switches brothers.
- **Characters:** make `art-src/models/person.py` and `face.py` parametric (build, skin, hair, clothes) to produce 7 people with the same rig. New animation clips:
  - **Carrying the body:** `carry_heavy_solo`, `drag_solo`, `carry_pair_front`, `carry_pair_back`
  - **Work:** `hammer`, `nailgun`, `lift_panel`, `screwdriver`, `kneel_work`
  - **Other:** `talk`, `search`, `crouch`
  - **Accident:** `react_fall`

  A PhysicalBone3D ragdoll is used for the accident and the body. The body is moved as a carried prop, with noise and speed set by the number of carriers.
- **Data-driven content** (Resource `.tres` files):
  - `AccidentCase`, `HidingSpot`, `StageScenario`, `EvidenceToken`
  - `Schedule`, `DialogueLine`, `InvestigationCheck`, `Ending`
- **Systems** (scripts):
  - `npc.gd`: schedule, hearing, vision cone, search state machine, Seen log
  - `companion.gd`: Tomas's orders, stress and autonomous work
  - `evidence.gd`: tokens and the trail between sites
  - `staging.gd`: scenario plausibility
  - `investigation.gd`: runs the checks in order and produces reasons and the ending
  - `story.gd`: day flow and flags
  - `dialogue.gd`: a small runner with choices and flags
- **Art:**
  - **Interior:** `art-src/models/house_interior.py`, two floors: work room (living room and kitchen with an exposed stud wall), hallway, three bedrooms, bathroom, attic, garage, yard. Wall pieces are separate so the cutaway works.
  - **Props:** scripts for studs, drywall sheets, nail gun, ladder, tool bag, couch, table and dishwasher in its box.
  - **Textures:** new recipes in `art-src/textures/pbr.py` for drywall, tile, carpet, laminate, plywood, paint and concrete.
  - **CC0 fill:** licenses listed in `godot-house/assets/third_party/LICENSES.md`.
- **Audio:** room ambience, footsteps per floor type, tool sounds, a noise-ring sound for loud actions, and heartbeat and music stingers. All sounds are CC0.
- **Tests:**
  - **Self-test:** `--selftest` plays scripted runs (day 1 tutorial; day 2 with each accident case to the Clean, Trail and Truth endings) and prints `SELFTEST_OK`.
  - **Unit tests:** run headless for the rules: plausibility, timeline contradiction and the token trail.
- **Builds:** `delegate.sh build_linux godot-house` and `build_windows godot-house`. Releases through `scripts/release.sh`.

## Milestones (each one a branch and a PR you merge)
1. **Greybox:** the house blockout, iso 3D camera with cutaway, click and WASD movement, Tab between the brothers, one resident on a schedule.
2. **Day 1 tutorial:** the install view (tools, hotspots, visible results), job list, orders to the brother, solo vs pair carrying (couch) with noise rings, end-of-day pay.
3. **Characters:** parametric people (7), the new animations, ragdoll. Done: `people.py` profiles, `person_<id>.glb`, clips search/crouch/phone/sit/react_fall/limp, `Actor.go_limp` ragdoll, `tests/people_test.gd`.
4. **Day 2 and accidents:** normal-day flow, three accident cases with the zoom cinematic, the Truth branch with its card. Done: `Story2`, `Worksite2` (Daniel's room jobs), `resources/accidents/*.tres` (stud, nailgun, sheet: job, step, injury, noise, signs, lines), `Cinematic` (letterbox camera, fades, cards; softened with the option), the choice and the truth card.
5. **Cover-up loop:** body moving (solo or pair), evidence tokens, the work facade, the four residents' search AI and Seen logs, discovery trigger. Done: `Coverup`, `BodyLoad` (L lifts/drags), `Token`, residents' search plans with pauses that ring his phone, noise checks, sight lines (found / caught), talking to searchers (statements), Tomas's orders (keep busy, tidy) and stress, the work alibi.
6. **Staging and investigation:** scenarios, the police cinematic, checks with pass/fail reasons, all endings. Done: `resources/scenarios/*.tres` (stairs, ladder, two nail gun scenes, bathroom) with setup spots, `Investigation` (Scene, Timeline, Trail, Work, Tomas; PASS / DOUBT / FAIL), the police walk-through with Detective Hale and an officer, the late choice (one brother takes the fall) and the ending cards. Tests: `tests/rules_test.gd`, `--selftest --day=2 --case --plan`.
7. **Art and audio pass:** interior and props on the P4, textures, CC0 fill, lighting, sound. Done: day 2 props (ladder, laundry basket and spill, towel, compressor, offcuts, storage box), nail gun and lamp tools, the police cast, every sound synthesized by `art-src/audio/make_sounds.py` (footsteps, tools, noise ring, drag scrape, phone, impact, heartbeat, stinger, room tone, yard, day and tense music). No third-party assets were needed.
8. **Polish and release:** menus, content warning and the softening option, quality presets, save per day, Linux and Windows 0.1.0. Done: title screen, warning, options, pause menu, day 2 unlock saved, play-tests; release built with `scripts/release.sh godot-house 0.1.0`.

## Critical files
- New: `godot-house/` (`project.godot`, `scripts/*.gd` as above, `resources/**/*.tres`, `shaders/cutaway.gdshader`)
- Reuse:
  - `godot-3d/scripts/graphics.gd` and `godot-3d/shaders/post.gdshader`
  - from `godot-3d/scripts/player.gd`, its animation and speed-matching logic
  - `art-src/models/common.py`, `person.py` and `face.py` (made parametric)
  - `art-src/textures/pbr.py`, `scripts/models.sh` and `scripts/textures.sh`
- Docs: a "Game 3" section in `CLAUDE.md`; `docs/game3-design.md` holds the story bible, accident cases, rules and endings.

## Verification
- Each milestone:
  - The headless self-test prints `SELFTEST_OK`.
  - Unit tests pass.
  - `DISPLAY=:0` `--write-movie` captures of new content are reviewed by eye. These include the iso view, the cutaway and the cinematics.
- **Milestones 4 to 6:** scripted runs reach given endings deterministically for each accident case.
- **Release:** the Linux export passes the self-test; the Windows export gets a PE header check.

## Out of scope for now
Voice acting, more than two days, other renovation rooms, and multiplayer.
