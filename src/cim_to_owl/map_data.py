import json
import jq
from pathlib import Path
import os
from rdflib import Graph

def run():
    
    input_dirnames = [
        'data/esdoc/cmip6/spreadsheet-models',
        'data/esdoc/cmip6/spreadsheet-experiments',
    ]
    all_json_filename = 'data/esdoc-clean/cmip6/all.json'
    all_nq_filename = 'data/esdoc-rdf/cmip6/all.nq'
    all_turtle_filename = 'data/esdoc-rdf/cmip6/all.ttl'
    
    all_quads = ''
    all_json = []
    
    for input_dirname in input_dirnames:
        filenames = [f[:-5] for f in os.listdir(input_dirname) if not f.startswith('.')]
        for filename in filenames:
            print(f"Mapping {filename}...")

            with open(input_dirname + '/' + filename + '.json') as f:
                json_doc = json.load(f)

            with open("jq/json_clean.jq") as f:
                jq_data_clean = f.read()
                
            json_cleaned = jq.compile(jq_data_clean).input_value(json_doc).first()
            all_json.append(json_cleaned)
            
            
    with open('meta/context.jsonld') as f:
        context = json.load(f)

    with open(all_json_filename, 'w') as f:
        json.dump(all_json, f, indent=4)

    all_graph = Graph()
    all_graph.parse(
        data=json.dumps({
            '@context': context,
            '@graph': all_json
        }),
        format='json-ld'
    )

    all_graph.serialize(
        destination=all_turtle_filename,
        format='turtle'
    )
    
    # Path(jsonld_dirname).mkdir(parents=True, exist_ok=True)
    # with open(jsonld_dirname + '/' + filename + '.jsonld', 'w') as f:
    #     json.dump(jsonld_expanded, f, indent=4)

    # all_jsonld.extend(jsonld_expanded)

    # Path(rdf_dirname).mkdir(parents=True, exist_ok=True)
    # with open(rdf_dirname + filename + '.nq', 'w') as f:
    #     f.write(quads)

    # all_quads = jsonld.to_rdf(
    #     all_jsonld,
    #     options={'format': 'application/n-quads'})
            
    with open(all_nq_filename, 'w') as f:
        f.write(all_quads)
                

                            
