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

def name_to_singular_camel_case(from_plural; first_upcase):
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
        (if (first_upcase or $partIndex > 0)
            then ((.[0:1] | ascii_upcase) + .[1:])
            else .
        end)
    ] | join("");

def convert_class_name(from_plural):
    split(".") |
    (.[0] | get_ns_mapping | .prefix) + ":" +
    (.[1] | name_to_singular_camel_case(from_plural; true));

def convert_shape_name(from_plural):
    split(".") |
    (.[0] | get_ns_mapping | .shapePrefix) + ":" +
    (.[1] | name_to_singular_camel_case(from_plural; true));

def convert_property_name(namespace; from_plural):
    (namespace | get_ns_mapping | .prefix) + ":" +
    name_to_singular_camel_case(from_plural; false);

def py_class_to_json_class:
    $class_prefix + (
        split(".") |
        .[0] + "." +
        (.[1] | name_to_singular_camel_case(false; true))
    );

def py_property_to_json_property:
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

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        {
            key: $className,
            value: (
                .type as $type |
                $className |
                from_context_or(
                    py_class_to_json_class;
                    if ($type == "class")
                        then convert_class_name(false)
                        else convert_class_name(true)
                    end
                )
            )
        }
    ]
] | flatten | from_entries )
as $classMap |

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        select(.value.type == "class") |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        {
            key: $className, 
            value: [ .value.properties | .[] | .[0] ]
        }
    ]
] | flatten | from_entries )
as $classPropertiesMap |

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        {
            key: $className,
            value: (
                .type as $type |
                $className |
                if ($type == "class")
                    then convert_shape_name(false)
                    else convert_shape_name(true)
                end
            )
        }
    ]
] | flatten | from_entries )
as $shapeMap |

(
    [
        to_entries | .[] |
        [
            .key as $namespace |
            .value | to_entries | .[] |
            select(.value.type == "class") |
            [
                .value.properties | .[] |
                (.[2] | split(".") | .[1]) as $max_cardinality |
                {
                    property: .[0],
                    namespace: $namespace,
                    maxCardinality: $max_cardinality
                }
            ]
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
        {
            key: .property,
            value: {
                extension: (
                    . as $propertyCtxt | .property |
                    from_context_or(
                        py_property_to_json_property;
                        convert_property_name($propertyCtxt.namespace; $propertyCtxt.maxCardinality == "N")
                    )
                ),
                namespace: .namespace
            }
        }
    ] |
    from_entries
)
as $propertiesMap |

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
            )
        )
    ] | from_entries
) as $classPropertyContext |

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
) as $context |

def expand_prefix:
    if in($context)
        then $context[.]
        else .
    end;

def expand:
    if . != null and contains(":")
        then (
            split(":") |
            (
                (.[0] | expand_prefix) +
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
                "@context": "https://raw.githubusercontent.com/w3c/shacl/main/shacl-jsonld-context/shacl.context.ld.json"
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
        to_entries |
        .[] |
        [
            .key as $namespace |
            .value | to_entries | .[] |
            .key as $localname |
            (.value.base | (if (. == "None") then null else . end)) as $parentClass |
            ($namespace + "." + $localname) as $extendedName |
            ($extendedName | get_class_name) as $className |
            ($extendedName | get_shape_name) as $shapeName |
            {
                "@id": $shapeName,
                "@type": "sh:NodeShape",
                "targetClass": $className | expand,
                "closed": true,
                "class": $parentClass | get_class_name | expand,
                "node": $parentClass | get_shape_name | expand,
                "parent": $parentClass,
                "property": [
                    .value.properties | select(. != null) | .[] |
                    .[0] as $property |
                    .[1] as $propertyType |
                    (.[2] | split(".")) as $cardinalityRestrs |
                    $cardinalityRestrs[0] as $minCardinality |
                    $cardinalityRestrs[1] as $maxCardinality |
                    {
                        "path": $property | get_property_name | expand,
                        "datatype": $propertyType | convert_datatype,
                        "class": $propertyType | get_class_name | expand,
                        "minCount": (if $minCardinality == "0" then null else ($minCardinality | tonumber) end),
                        "maxCount": (if $maxCardinality == "N" then null else ($maxCardinality | tonumber) end)
                    }]
            }
        ]
    ] | flatten | prune_nulls
) as $shapes |

{
    "@context": $context,
    "@shapes": {
        "@context": $shapesContext,
        "@graph": $shapes
    },
    "@rdfs": $rdfs
}