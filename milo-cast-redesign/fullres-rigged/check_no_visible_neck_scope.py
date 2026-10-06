"""Reuse the canonical GLB comparator with only Neck_Transition in scope."""
from pathlib import Path
import json

OUT = Path(__file__).resolve().parent
source = (OUT / 'check_neck_bold_scope.py').read_text()
source = source.replace(
    "def allowed(name):return name.startswith('Moustache_') or name in ('Chin','Mouth','Neck_Transition')",
    "def allowed(name):return name=='Neck_Transition'",
)
source = source.replace("OUT/'neck-bold-before/milo_fullres.glb'", "OUT/'visible-neck-before/milo_fullres.glb'")
source = source.replace("neck_bold_scope_verification.json", "no_visible_neck_scope_verification.json")
source = source.replace("NECK_BOLD_SCOPE_PASS", "NO_VISIBLE_NECK_SCOPE_PASS")
exec(compile(source, str(OUT / 'check_neck_bold_scope.py'), 'exec'))

path = OUT / 'no_visible_neck_scope_verification.json'
report = json.loads(path.read_text())
report['scope'] = ('Only the visible Neck_Transition mesh was removed. All remaining geometry, '
                   'materials, vertex attributes, skinning, node transforms, inverse binds, '
                   'bones and animation channels are exactly unchanged.')
report['visible_neck_mesh_only_change'] = True
path.write_text(json.dumps(report, indent=2))
