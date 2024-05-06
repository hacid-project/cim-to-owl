#!/bin/bash

INPUT_FILE='dist/esdoc-cim-schema.json'
OUTPUT_FILE='dist/output.json'

jq -f json_cim_to_rdfs.jq --slurpfile ctxt initial_context.json <$INPUT_FILE >$OUTPUT_FILE