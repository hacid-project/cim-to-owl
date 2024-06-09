import "jq/words_ending_in_s" as $words_ending_in_s_array;
import "config/namespaces" as $namespaces_array;
import "config/initial_context" as $context_array;

([ $words_ending_in_s_array | .[].[] | { key: ., value: true } ] | from_entries) as $words_ending_in_s |

#(if $ARGS.named | has("ns")
#    then ([$ARGS.named.["ns"] | map(to_entries) | .[]] | flatten | from_entries)
#    else {}
#end)
($namespaces_array | .[0]) as $namespaceMap |

#(if $ARGS.named | has("ctxt")
#    then ([$ARGS.named.["ctxt"] | map(to_entries) | .[]] | flatten | from_entries)
#    else {}
#end) as $context |
($context_array | .[0]) as $context |

"cim.2." as $class_prefix | 

def singularize:
    if test("ies$") then
        sub("ies$"; "y")
    elif test("ss$") then
        .
    elif test("s$") then
        if in($words_ending_in_s)
            then .
            else sub("s$"; "")
        end
    else
        .
    end;

def get_base_mapping:
    if ("@base" | in ($namespaceMap))
        then $namespaceMap["@base"]
        else {}
    end;

def get_ns_mapping:
    if (in ($namespaceMap))
        then $namespaceMap[.]
        else get_base_mapping as $baseMapping | {
            prefix: ($baseMapping.prefix + "-" + .),
            shapePrefix: ($baseMapping.shapePrefix + "-" + .),
            extension: ($baseMapping.extension + . + "/"),
            shapeExtension: ($baseMapping.shapeExtension + . + "/")
        }
    end;

{
    "str": "xsd:string",
    "bool": "xsd:float",
    "int": "xsd:integer"
} as $datatypeMap |
def convert_datatype: if in($datatypeMap) then $datatypeMap[.] else null end;

def prune_nulls:
    if (type == "object")
        then (
            [
                to_entries | .[] |
                select(.value | (. != null and (type=="boolean" or length > 0))) |
                {key: .key, value: .value | prune_nulls}
            ] | from_entries)
    elif (type == "array")
        then [.[] | prune_nulls]
    else .
    end;

def name_to_singular_camel_case(from_plural; first_upcase; rest_upcase; separator):
    [
        split("_") |
        length as $numParts |
        . as $parts |
        range($numParts) |
        . as $partIndex |
        $parts[$partIndex] |
        (if (from_plural and $partIndex == $numParts - 1)
            then singularize
            else .
        end) |
        (if (first_upcase or ($partIndex > 0 and rest_upcase))
            then (
                if (. == "id")
                    then "ID"
                    else ((.[0:1] | ascii_upcase) + .[1:])
                end
            )
            else .
        end)
    ] | join(separator);

def name_to_singular_camel_case(from_plural; first_upcase):
    name_to_singular_camel_case(from_plural; first_upcase; true; "");

def convert_class_name(from_plural):
    split(".") |
    (.[0] | get_ns_mapping | .prefix) + ":" +
    (.[1] | name_to_singular_camel_case(from_plural; true));

def convert_shape_name(from_plural):
    split(".") |
    (.[0] | get_ns_mapping | .shapePrefix) + ":" +
    (.[1] | name_to_singular_camel_case(from_plural; true));

def label_from_class_name(from_plural):
    split(".") |
    .[1] | name_to_singular_camel_case(from_plural; true; true; " ");

def convert_property_name(namespace; from_plural):
    (namespace | get_ns_mapping | .prefix) + ":" +
    name_to_singular_camel_case(from_plural; false);

def convert_individual_name(namespace; from_plural):
    (namespace | get_ns_mapping | .prefix) + ":" +
    name_to_singular_camel_case(from_plural; false);

def label_from_property_name(from_plural):
    name_to_singular_camel_case(from_plural; false; false; " ");

def label_from_individual_name(from_plural):
    name_to_singular_camel_case(from_plural; false; false; " ");

def py_class_to_json_class:
    $class_prefix + (
        split(".") |
        .[0] + "." +
        (.[1] | name_to_singular_camel_case(false; true))
    );

def py_property_to_json_property:
    name_to_singular_camel_case(false; false);

def py_individual_to_json_individual:
    name_to_singular_camel_case(false; false);

def from_context_or(key; alt):
    key as $key |
    alt as $alt |
    if ($key | in($context))
        then (
            $context[$key] |
            if (type == "object")
                then .["@id"]
                else .
            end
        )
        else $alt
    end;

def one_or_many:
    if length == 0
        then null
    elif length == 1
        then .[0]
    else
        .
    end;

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        select(.value | type == "object") |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        {
            key: $className,
            value: .value
        }
    ]
] | flatten | from_entries )
as $classObjs |

([
    $classObjs | to_entries | .[] | 
    {
        key: .key,
        value: (
            .value.type as $type |
            .key |
            from_context_or(
                py_class_to_json_class;
                convert_class_name($type != "class")
            )
        )
    }
]| from_entries )
as $classMap |

{"id": true, "type": true, "@type": true} as $reservedPropertyNames |

def safe_property_name(classname):
    if in($reservedPropertyNames)
        then (classname | split(".") | .[1]) + "_" + .
        else .
    end; 

([
    $classObjs | to_entries | .[] | 
    select(.value.type == "class") |
    .key as $classname |
    {
        key: $classname,
        value: [ .value.properties | .[] | .[0] | safe_property_name($classname) ]
    }
]| from_entries )
as $classPropertiesMap |

([
    $classObjs | to_entries | .[] | 
    select(.value.type == "enum") |
    .key as $classname |
    {
        key: $classname,
        value: [ .value.members | .[] | .[0] ]
    }
]| from_entries )
as $enumMembersMap |

([
    $classObjs | to_entries | .[] | 
    {
        key: .key,
        value: (
            .value.type as $type |
            .key |
            convert_shape_name($type != "class")
        )
    }
]| from_entries )
as $shapeMap |

(
    [
        $classObjs | to_entries | .[] | 
        select(.value.type == "class") |
        (.key | split(".") | .[0]) as $namespace |
        .key as $classname |
        [
            .value.properties | .[] |
            (.[2] | split(".") | .[1]) as $max_cardinality |
            {
                property: .[0] | safe_property_name($classname),
                namespace: $namespace,
                maxCardinality: $max_cardinality
            }
        ]
    ] |
    flatten |
    group_by(.property) |
    [
        .[] |
        {
            property: .[0].property,
            namespaces: ([.[] | .namespace] | unique),
            maxCardinalities : ([.[] | .maxCardinality] | unique)
        } |
        {
            property: .property,
            namespace: (.namespaces | if length > 1 then "shared" else .[0] end),
            maxCardinality : (.maxCardinalities | if length > 1 then "1" else .[0] end)
        } |
        (.maxCardinality == "N") as $isPlural |
        {
            key: .property,
            value: {
                extension: (
                    . as $propertyCtxt | .property |
                    from_context_or(
                        py_property_to_json_property;
                        convert_property_name($propertyCtxt.namespace; $isPlural)
                    )
                ),
                namespace: .namespace,
                label: .property | label_from_property_name($isPlural)
            }
        }
    ] |
    from_entries
)
as $propertiesMap |

(
    [
        $classObjs | to_entries | .[] | 
        select(.value.type == "enum") |
        (.key | split(".") | .[0]) as $namespace |
        .key as $classname |
        [
            .value.members | .[] |
            {
                individual: .[0],
                namespace: $namespace,
                type: $classname
            }
        ]
    ] |
    flatten |
    group_by(.individual) |
    [
        .[] |
        {
            individual: .[0].individual,
            namespace: [.[] | .namespace] | unique | (if length > 1 then "shared" else .[0] end),
            type: [.[] | .type] | unique | one_or_many
        } |
        {
            key: .individual,
            value: {
                extension: (
                    . as $individualCtxt | .individual |
                    from_context_or(
                        py_individual_to_json_individual;
                        convert_individual_name($individualCtxt.namespace; false)
                    )
                ),
                namespace: .namespace,
                type: .type,
                label: .individual | label_from_individual_name(false)
            }
        }
    ] |
    from_entries
)
as $individualsMap |

def get_class_name:
    if (. == null or . == "None")
        then null
    else
        if startswith("linked_to")
             then .[("linked_to" | length) + 1:-1]
             else .
        end |
        if in($classMap)
            then $classMap[.]
            else null
        end
    end;

def get_shape_name:
    if (. == null or . == "None")
        then null
    elif in($shapeMap)
        then $shapeMap[.]
    else null
    end;
    
def get_property_name:
    if (. == null or . == "None")
        then null
    elif in($propertiesMap)
        then $propertiesMap[.].extension
    else null
    end;

def get_individual_name:
    if (. == null or . == "None")
        then null
    elif in($individualsMap)
        then $individualsMap[.].extension
    else null
    end;

def get_property_label:
    if (. == null or . == "None")
        then null
    elif in($propertiesMap)
        then $propertiesMap[.].label
    else null
    end;

def get_individual_label:
    if (. == null or . == "None")
        then null
    elif in($individualsMap)
        then $individualsMap[.].label
    else null
    end;

def get_individual_type:
    if (. == null or . == "None")
        then null
    elif in($individualsMap)
        then $individualsMap[.].type
    else null
    end;

(
    [
        (
            $propertiesMap  | to_entries | .[] |
            select(.value.namespace == "shared") |
            .key |
            {
                key: py_property_to_json_property,
                value: get_property_name
            }
        ),
        (
            $classMap | to_entries | .[] |
            .key as $className |
            {
                key: ($className | py_class_to_json_class),
                value: .value
            },
            (
                $classPropertiesMap[$className] | select(. != null) | .[] |
                {
                    key: py_property_to_json_property,
                    value: get_property_name
                }
            ),
            (
                $enumMembersMap[$className] | select(. != null) | .[] |
                {
                    key: py_individual_to_json_individual,
                    value: get_individual_name
                }
            )
        )
    ] | from_entries
) as $classPropertyContext |

def aggregate_by(grouping_filter):
    group_by(grouping_filter) |
    [
        .[] |
        . as $sameKeyValueSet |
        [
            [ .[] | keys ] | flatten | unique | .[] |
            . as $key |
            {
                key: $key,
                value: ([$sameKeyValueSet | .[] | .[$key]] | unique | one_or_many)
            }
        ] | from_entries
    ];

(
    [
        (
            $classObjs | to_entries | .[] | 
            (.value.base | (if (. == "None") then null else . end) | get_class_name) as $parentClass |
            .key as $classname |
            (.value.type == "enum") as $isEnum |
            {
                "@id": ($classname | get_class_name),
                "@type": "rdfs:Class",
                "rdfs:label": ($classname | label_from_class_name($isEnum)),
                "rdfs:comment": .value.annotation,
                "rdfs:subclassOf": $parentClass
            }
        ),
        (
            $classObjs | to_entries | .[] | 
            select(.value.type == "class") |
            .key as $classname |
            .value.properties | .[] |
            (.[0] | safe_property_name($classname)) as $propertyName |
            {
                "@id": ($propertyName | get_property_name),
                "@type": "rdfs:Property",
                "rdfs:label": ($propertyName | get_property_label),
                "rdfs:comment": .[3]
            }
        ),
        (
            $classObjs | to_entries | .[] | 
            select(.value.type == "enum") |
            .key as $classname |
            .value.members | .[] |
            .[0] as $individualId |
            {
                "@id": ($individualId | get_individual_name),
                "@type": ($classname | get_class_name),
                "rdfs:label": ($individualId | get_individual_label),
                "rdfs:comment": .[1]
            }
        )
    ] |
    prune_nulls |
    aggregate_by(.["@id"])
) as $rdfTerms |

(
    [
        $classMap | to_entries | .[] |
        .key as $className |
        {
            "@id": .value,
            "@type": "rdfs:Class"
        },
        (
            $classPropertiesMap[$className] | select(. != null) | .[] |
            {
                "@id": get_property_name,
                "@type": "rdfs:Property"
            }
        )
    ]
) as $rdfs |

([ keys | .[] | get_ns_mapping | { key: .prefix, value: .extension} ] | from_entries) as $nsExtensions |
([ keys | .[] | get_ns_mapping | { key: .shapePrefix, value: .shapeExtension} ] | from_entries) as $nsShapeExtensions |

(
    [
        (
            {
                "@version": 1.1,
                "id": "@id",
                "type": "@type",
                "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
                "xsd": "http://www.w3.org/2001/XMLSchema#"
            }
            | to_entries | .[]
        ),
        ($nsExtensions | to_entries | .[]),
        ($classPropertyContext | to_entries | .[]),
        ($context | to_entries | .[])
    ] |
    from_entries
) as $mappingContext |

(
    [
        (
            {
                "@version": 1.1,
                "id": "@id",
                "type": "@type",
                "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
                "xsd": "http://www.w3.org/2001/XMLSchema#"
            }
            | to_entries | .[]
        ),
        ($nsExtensions | to_entries | .[]),
        ($context | to_entries | .[])
    ] |
    from_entries
) as $rdfsContext |


def expand_prefix($refCtxt):
    if in($refCtxt)
        then $refCtxt[.]
        else .
    end;

def expand($refCtxt):
    if . != null and contains(":")
        then (
            split(":") |
            (
                (.[0] | expand_prefix($refCtxt)) +
                (.[1:] | join(":"))
            )
        )
        else .
    end;


(
    [
        (
            {
                "@version": 1.1,
                "@context": "https://w3c.github.io/shacl/shacl-jsonld-context/shacl.context.ld.json"
#                "@context": "https://raw.githubusercontent.com/w3c/shacl/main/shacl-jsonld-context/shacl.context.ld.json"
            }
            | to_entries | .[]
        ),
        ($nsExtensions | to_entries | .[]),
        ($nsShapeExtensions | to_entries | .[])
    ] |
    from_entries
) as $shapesContext |

(
    [
        $classObjs | to_entries | .[] | 
        (.value.base | (if (. == "None") then null else . end)) as $parentClass |
        (.key | get_class_name) as $className |
        (.key | get_shape_name) as $shapeName |
        {
                "@id": $shapeName | expand($shapesContext),
                "@type": "sh:NodeShape",
                "targetClass": $className | expand($mappingContext),
                "closed": true,
                "class": $parentClass | get_class_name | expand($mappingContext),
                "node": $parentClass | get_shape_name | expand($shapesContext),
                "property": [
                    .value.properties | select(. != null) | .[] |
                    .[0] as $property |
                    .[1] as $propertyType |
                    (.[2] | split(".")) as $cardinalityRestrs |
                    $cardinalityRestrs[0] as $minCardinality |
                    $cardinalityRestrs[1] as $maxCardinality |
                    {
                        "path": $property | get_property_name | expand($mappingContext),
                        "datatype": $propertyType | convert_datatype,
                        "class": $propertyType | get_class_name | expand($mappingContext),
                        "minCount": (if $minCardinality == "0" then null else ($minCardinality | tonumber) end),
                        "maxCount": (if $maxCardinality == "N" then null else ($maxCardinality | tonumber) end)
                    }
                ],
                "in": [
                    .value.members | select(. != null) | .[] |
                    .[0] | get_individual_name
                ]
        }
    ] | prune_nulls
) as $shapes |

{
    "@context": $mappingContext,
    "@shapes": {
        "@context": $shapesContext,
        "@graph": $shapes
    },
    "@rdfs": {
        "@context": $rdfsContext,
        "@graph": $rdfTerms
    }
}