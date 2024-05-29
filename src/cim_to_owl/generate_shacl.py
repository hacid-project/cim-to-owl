import json
import jq
import esdoc
from .py_cim_to_json import cim_obj_to_jsonable_obj

def run():
    json_obj = cim_obj_to_jsonable_obj(esdoc)

    with open('meta/esdoc-cim-schema.json', 'w') as f:
        json.dump(json_obj, f, indent=4)
        
    with open("jq/cim_to_shacl.jq") as f:
        json_cim_to_rdfs = f.read()
        
    # output = jq.compile(json_cim_to_rdfs).input_value(json_obj)
    output = jq.compile(json_cim_to_rdfs).input_value(json_obj).first()

    with open('meta/context.jsonld', 'w') as f:
        json.dump(output["@context"], f, indent=4)
        
    with open('meta/shacl.jsonld', 'w') as f:
        json.dump(output["@shapes"], f, indent=4)
        
    with open('meta/rdfs.jsonld', 'w') as f:
        json.dump(output["@rdfs"], f, indent=4)