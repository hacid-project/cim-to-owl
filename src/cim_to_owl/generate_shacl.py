import json
import jq
import esdoc
from .py_cim_to_json import cim_obj_to_jsonable_obj
from rdflib import Graph

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
    shacl_graph = Graph()
    shacl_graph.parse(
        data=json.dumps(output["@shapes"]),
        format='json-ld'
    )
    shacl_graph.serialize(
        destination='meta/shacl.ttl',
        format='turtle'
    )

    with open('meta/rdfs.jsonld', 'w') as f:
        json.dump(output["@rdfs"], f, indent=4)
    rdfs_graph = Graph()
    rdfs_graph.parse(
        data=json.dumps(output["@rdfs"]),
        format='json-ld'
    )
    rdfs_graph.serialize(
        destination='meta/rdfs.ttl',
        format='turtle'
    )

