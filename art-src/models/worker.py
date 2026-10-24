"""The brothers and the household of Off the Books: person.py built as the "worker" variant (tool belt,
no scarf or backpack), with the work and carry clips previewed instead of the walk/face sheets."""
import os
import runpy

os.environ["PERSON_VARIANT"] = "worker"
runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "person.py"), run_name="__main__")
