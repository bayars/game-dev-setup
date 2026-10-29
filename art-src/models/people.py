"""The cast of Off the Books as person.py profiles. One rig and one set of clips for everyone; each profile
changes the body, the face, the hair and the clothes. Height is not modelled here: every person is built at
1.78 m and the game scales the whole model (`height` below, mirrored in godot-house/scripts/people.gd), so
the clips stay valid for all of them.

Build one: `scripts/delegate.sh models person_<id>` (person.py with PERSON_PROFILE=<id>).
"walker" is Walk Home's original look and stays the default when no profile is set.
"""

# body: shoulders / hips (width factors), girth (torso), belly (m added at the waist), bust (0..1),
#       limbs (thickness factor), stoop (radians of permanent forward bend, added to every clip)
# face: skin, eyes (iris inner, outer), brows, lips, freckles, stubble (0..1), wrinkles (0..1),
#       jaw / brow / nose / lips (feature amplitude factors), lashes (length factor)
# hair: style short | cropped | messy | long | ponytail | bun | receding, colour, grey (0..1)
# clothes: top jacket | hoodie | tshirt | sweater | shirt | cardigan, top/top_dark/inner colours,
#          pants colour, shoes boots | sneakers | slippers (+ colour), extras: toolbelt, glasses, scarf, backpack
BASE = {
    "height": 1.78,
    "body": {"shoulders": 1.0, "hips": 1.0, "girth": 1.0, "belly": 0.0, "bust": 0.0, "limbs": 1.0, "stoop": 0.0},
    "face": {"skin": "#E2AE8B", "eyes": ("#996633", "#4D2B14"), "brows": "#29170D", "lips": "#A84C4A",
             "freckles": 22, "stubble": 0.0, "wrinkles": 0.0, "jaw": 1.0, "brow": 1.0, "nose": 1.0,
             "lip": 1.0, "lashes": 1.0},
    "hair": {"style": "short", "colour": "#2A160B", "grey": 0.0},
    "clothes": {"top": "jacket", "top_colour": "#1C8D95", "top_dark": "#14666C", "inner": "#E9E4D8",
                "pants": "#2D3652", "shoes": "sneakers", "shoe_colour": "#3B2A22", "extras": []},
}


def _p(**over):
    out = {k: (dict(v) if isinstance(v, dict) else v) for k, v in BASE.items()}
    for k, v in over.items():
        if isinstance(v, dict):
            out[k].update(v)
        else:
            out[k] = v
    return out


PROFILES = {
    # Walk Home's walker: scarf and backpack, unchanged
    "walker": _p(clothes={"extras": ["scarf", "backpack"]}),
    # the brothers: work clothes, tool belts, boots
    "nico": _p(height=1.80,
               body={"shoulders": 1.06, "girth": 1.04, "limbs": 1.05},
               face={"skin": "#C99773", "eyes": ("#7A4E26", "#3A220E"), "brows": "#1E120A", "freckles": 0,
                     "stubble": 0.75, "jaw": 1.25, "brow": 1.15, "nose": 1.1, "lips": "#94504A"},
               hair={"style": "cropped", "colour": "#1E130B"},
               clothes={"top": "jacket", "top_colour": "#1C8D95", "top_dark": "#14666C", "pants": "#2D3652",
                        "shoes": "boots", "shoe_colour": "#5A3B22", "extras": ["toolbelt"]}),
    "tomas": _p(height=1.76,
                body={"shoulders": 0.98, "girth": 0.95, "limbs": 0.97},
                face={"skin": "#CFA07A", "eyes": ("#6B4424", "#33200F"), "brows": "#160D07", "freckles": 0,
                      "stubble": 0.35, "jaw": 1.1, "nose": 1.05, "lips": "#9A524B"},
                hair={"style": "messy", "colour": "#120B07"},
                clothes={"top": "hoodie", "top_colour": "#A8432F", "top_dark": "#7E2F20", "pants": "#3B3A36",
                         "shoes": "boots", "shoe_colour": "#4A3020", "extras": ["toolbelt"]}),
    # the family
    "daniel": _p(height=1.70,
                 body={"shoulders": 0.92, "hips": 0.95, "girth": 0.88, "limbs": 0.88},
                 face={"skin": "#EDC3A3", "eyes": ("#7FA0B8", "#3C5A70"), "brows": "#6A4428", "freckles": 70,
                       "jaw": 0.8, "brow": 0.8, "nose": 0.9},
                 hair={"style": "messy", "colour": "#7A5232"},
                 clothes={"top": "tshirt", "top_colour": "#E0A92E", "top_dark": "#B8861F", "pants": "#3E5C86",
                          "shoes": "sneakers", "shoe_colour": "#ECE9E2"}),
    "linda": _p(height=1.67,
                body={"shoulders": 0.88, "hips": 1.1, "girth": 0.93, "bust": 0.8, "limbs": 0.86},
                face={"skin": "#E8B898", "eyes": ("#6E8A5A", "#34452A"), "brows": "#5A2E1A", "freckles": 10,
                      "wrinkles": 0.25, "jaw": 0.7, "brow": 0.6, "nose": 0.85, "lip": 1.15, "lips": "#B0485A",
                      "lashes": 1.4},
                hair={"style": "long", "colour": "#7B3A1E"},
                clothes={"top": "sweater", "top_colour": "#7B4F8C", "top_dark": "#5B3868", "pants": "#2B2B33",
                         "shoes": "sneakers", "shoe_colour": "#2B2B33"}),
    "robert": _p(height=1.84,
                 body={"shoulders": 1.05, "hips": 1.04, "girth": 1.12, "belly": 0.05, "limbs": 1.04},
                 face={"skin": "#E0A988", "eyes": ("#7A8F9E", "#3D4D5A"), "brows": "#5C5450", "freckles": 0,
                       "stubble": 0.2, "wrinkles": 0.45, "jaw": 1.2, "brow": 1.1, "nose": 1.2,
                       "lips": "#A05048"},
                 hair={"style": "receding", "colour": "#4A3A2E", "grey": 0.45},
                 clothes={"top": "shirt", "top_colour": "#9DB8D6", "top_dark": "#7B97B6", "pants": "#B8A27E",
                          "shoes": "sneakers", "shoe_colour": "#3A2A20", "extras": ["glasses"]}),
    "sofia": _p(height=1.62,
                body={"shoulders": 0.85, "hips": 1.0, "girth": 0.86, "bust": 0.45, "limbs": 0.82},
                face={"skin": "#EFC6A8", "eyes": ("#7A5636", "#3A2412"), "brows": "#4A2E1A", "freckles": 30,
                      "jaw": 0.65, "brow": 0.55, "nose": 0.8, "lip": 1.1, "lips": "#B55A62", "lashes": 1.5},
                hair={"style": "ponytail", "colour": "#9C7A4A"},
                clothes={"top": "hoodie", "top_colour": "#6C9A7E", "top_dark": "#4E7860", "pants": "#22222A",
                         "shoes": "sneakers", "shoe_colour": "#F2EEE6"}),
    "rose": _p(height=1.56,
               body={"shoulders": 0.86, "hips": 1.06, "girth": 0.96, "belly": 0.02, "bust": 0.5, "limbs": 0.84,
                     "stoop": 0.16},
               face={"skin": "#EBC4AE", "eyes": ("#7E8C96", "#47525A"), "brows": "#B9B2AA", "freckles": 0,
                     "wrinkles": 1.0, "jaw": 0.7, "brow": 0.7, "nose": 1.05, "lip": 0.8, "lips": "#A86A6E"},
               hair={"style": "bun", "colour": "#D9D5CF", "grey": 1.0},
               clothes={"top": "cardigan", "top_colour": "#C9B48E", "top_dark": "#A8936E", "inner": "#E8E2EE",
                        "pants": "#5A5560", "shoes": "slippers", "shoe_colour": "#7A4A4E", "extras": ["glasses"]}),
}


def get(name):
    return PROFILES.get(name or "walker", PROFILES["walker"])
