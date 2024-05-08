import json
import jq
import esdoc
from .py_cim_to_json import cim_obj_to_jsonable_obj

def run():
    json_obj = cim_obj_to_jsonable_obj(esdoc)

    with open('dist/esdoc-cim-schema.json', 'w') as f:
        json.dump(json_obj, f, indent=4)
        
    with open("jq/json_cim_to_rdfs.jq") as f:
        json_cim_to_rdfs = f.read()
        
    # output = jq.compile(json_cim_to_rdfs).input_value(json_obj)
    output = jq.compile(json_cim_to_rdfs).input_value(json_obj).first()

    with open('dist/context.jsonld', 'w') as f:
        json.dump(output["@context"], f, indent=4)
        
    with open('dist/shacl.jsonld', 'w') as f:
        json.dump(output["@shapes"], f, indent=4)