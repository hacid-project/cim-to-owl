#.["@namespaces"] as $namespaceMap |
[] as $ns |
([$ns | map(to_entries) | .[]] | flatten | from_entries) as $namespaceMap |

"cim.2." as $class_prefix |

{} as $context |

def get_base_mapping:
    if ("@base" | in ($namespaceMap))
        then $namespaceMap["@base"]
        else {
            prefix: "terms",
            shapePrefix: "shapes",
            extension: "https://example.org/terms/"
        }
    end;

def get_ns_mapping:
    if (in ($namespaceMap))
        then $namespaceMap[.]
        else get_base_mapping as $baseMapping | {
            prefix: ($baseMapping.prefix + "-" + .),
            shapePrefix: ($baseMapping.shapePrefix + "-" + .),
            extension: ($baseMapping.extension + . + "/")
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

def convert_class_name:
    split(".") |
    (.[0] | get_ns_mapping | .prefix) + ":" +
    ([.[1] | split("_") | .[] |
        ((.[0:1] | ascii_upcase) + .[1:])
    ] | join(""));

def convert_class_name_expanded:
    split(".") |
    (.[0] | get_ns_mapping | .extension) +
    ([.[1] | split("_") | .[] |
        ((.[0:1] | ascii_upcase) + .[1:])
    ] | join(""));

def convert_shape_name:
    split(".") |
    (.[0] | get_ns_mapping | .shapePrefix) + ":" +
    ([.[1] | split("_") | .[] |
        ((.[0:1] | ascii_upcase) + .[1:])
    ] | join(""));

def convert_property_name:
    split(".") |
    .[0] as $namespace |
    .[1] as $className |
    .[2] | split("_") |
    .[0] as $firstPart |
    ($namespace | get_base_mapping | .prefix) + ":" +
    $firstPart + ([
        .[1:] | .[] |
        ((.[0:1] | ascii_upcase) + .[1:])
    ] | join(""));

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        {
            key: $className,
            value: ($className | convert_class_name)
        }
    ]
] | flatten | from_entries )
as $classMap |

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        {
            key: $className,
            value: ($className | convert_shape_name)
        }
    ]
] | flatten | from_entries )
as $shapeMap |

([
    to_entries | .[] |
    [
        .key as $namespace |
        .value | to_entries | .[] |
        select(.value.type == "class") |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        [
            .value.properties | .[] |
            ($className + "." + .[0]) as $completePropertyName |
            {
                key: $completePropertyName,
                value: $completePropertyName | convert_property_name
            }
        ]
    ]
] | flatten | from_entries )
as $propertiesMap |

def py_class_to_json_class:
    $class_prefix + (
        split(".") |
        .[0] + "." +
        ([.[1] | split("_") | .[] |
            ((.[0:1] | ascii_upcase) + .[1:])
        ] | join(""))
    );

def py_property_to_json_property:
    split("_") |
        .[0] + (
            [
                .[1:] | .[] |
                ((.[0:1] | ascii_upcase) + .[1:])
            ] | join(""));

([
    to_entries | .[] | [
        .key as $namespace |
        .value | to_entries | .[] |
        .key as $localname |
        ($namespace + "." + $localname) as $className |
        .value | {
            key: ($className | py_class_to_json_class),
            value: {
                "@id": ($className | convert_class_name),
                "@type": "rdfs:Class",
                "@context" :
                    ([
                        (.properties | select(. != null) | .[] |
                            ($className + "." + .[0]) as $completePropertyName |
                            {
                                key: (.[0] | py_property_to_json_property),
                                value: $completePropertyName | convert_property_name
                            }),
                        (.base | select(. != null and . != "None") | {
                            key: "@context",
                            value: convert_class_name_expanded
                        })
                    ] | from_entries)
            }
        }
    ]
] | flatten | from_entries )
as $classPropertyMap |

def get_class_name:
    if (. == null or . == "None")
        then null
    elif in($classMap)
        then $classMap[.]
    else null
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
        then $propertiesMap[.]
    else null
    end;

([ keys | .[] | get_ns_mapping | { key: .prefix, value: .extension} ] | from_entries) as $nsExtensions |

([
        (
            {
                "@version": 1.1,
                "@base": "http://example.org/resources/",
                "terms": "https://example.org/terms/",
                "id": "@id",
                "type": "@type",
                "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
                "rdfs": "http://www.w3.org/2000/01/rdf-schema#"
            }
            | to_entries | .[]
        ),
        ($nsExtensions | to_entries | .[]),
#        ($namespaceMap | to_entries | .[] | {key:.value.prefix, value:.value.extension}),
#        ($classMap | to_entries | .[]),
#        ($propertiesMap | to_entries | .[]),
        ($classPropertyMap | to_entries | .[]),
       ($context | to_entries | .[])
    ] | from_entries) as $context |

[
    to_entries |
    .[] |
    [
        .key as $namespace |
        .value | to_entries | .[] |
        .key as $localname |
        .value.base as $parentClass |
        ($namespace + "." + $localname) as $extendedName |
        ($extendedName | get_class_name) as $className |
        ($extendedName | get_shape_name) as $shapeName |
        {
            "namespace": $namespace,
            "@id": $shapeName,
            "@type": "sh:NodeShape",
            "sh:targetClass": $className,
            "sh:closed": true,
            "sh:class": $parentClass | get_class_name,
            "sh:node": $parentClass | get_shape_name,
            "parent": $parentClass,
            "sh:property": [
                .value.properties | select(. != null) | .[] |
                ($extendedName + "." + .[0]) as $property |
                .[1] as $propertyType |
                (.[2] | split(".")) as $cardinalityRestrs |
                $cardinalityRestrs[0] as $minCardinality |
                $cardinalityRestrs[1] as $maxCardinality |
                {
                    "sh:path": $property | get_property_name,
                    "sh:datatype": $propertyType | convert_datatype,
                    "sh:class": $propertyType | get_class_name,
                    "sh:minCount": (if $minCardinality == "0" then null else ($minCardinality | tonumber) end),
                    "sh:maxCount": (if $maxCardinality == "N" then null else ($maxCardinality | tonumber) end)
                }]
        }
    ]
] | flatten | prune_nulls as $shapes |

{
    "@context": $context,
    "@shapes": $shapes
}


