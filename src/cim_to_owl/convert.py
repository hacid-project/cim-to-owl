import json
import jq
import esdoc
from .py_cim_to_json import cim_obj_to_jsonable_obj

def run():
    json_obj = cim_obj_to_jsonable_obj(esdoc)

    with open('dist/esdoc-cim-schema.json', 'w') as f:
        json.dump(json_obj, f, indent=4)
        
    with open("json_cim_to_rdfs.jq") as f:
        json_cim_to_rdfs = f.read()
        
    output = jq.compile(json_cim_to_rdfs).input_value(json_obj).all()

    with open('dist/output.json', 'w') as f:
        json.dump(output, f, indent=4)