import json
import jq
from pathlib import Path

def run():
    
    input_dirname = 'data/esdoc/cmip6/spreadsheet-models/'
    output_dirname = 'data/esdoc-clean/cmip6/'
    classname = 'cim-2-science-model'
    resource_id = '1e9d7c8d-d653-4cce-891d-e42ede92f11b'
    filename = 'cim-2-science-model_1e9d7c8d-d653-4cce-891d-e42ede92f11b_1_c40fc5b997628d79ce26dc770cf2c189'
#    filename = classname + '_' + resource_id
    with open(input_dirname + filename + '.json') as f:
        json_doc = json.load(f)

    with open("jq/json_clean.jq") as f:
        jq_data_clean = f.read()
        
    # output = jq.compile(json_cim_to_rdfs).input_value(json_obj)
    output = jq.compile(jq_data_clean).input_value(json_doc).first()

    Path(output_dirname).mkdir(parents=True, exist_ok=True)
    with open(output_dirname + filename + '.json', 'w') as f:
        json.dump(output, f, indent=4)
        
