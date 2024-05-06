import "words_ending_in_s" as $words_ending_in_s_array;

([ $words_ending_in_s_array | .[].[] | { key: ., value: true } ] | from_entries) as $words_ending_in_s |

#.["@namespaces"] as $namespaceMap |
[] as $ns |
([$ns | map(to_entries) | .[]] | flatten | from_entries) as $namespaceMap |

([$ctxt | map(to_entries) | .[]] | flatten | from_entries) as $context |

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
            value: (
                . as $propertyCtxt | .property |
                from_context_or(
                    py_property_to_json_property;
                    convert_property_name($propertyCtxt.namespace; $propertyCtxt.maxCardinality == "N")
                )
            )
        }
    ] |
    from_entries
)
as $propertiesMap |

(
    [
        $classMap | to_entries | .[] |
        .key as $className |
        {
            key: ($className | py_class_to_json_class),
            value: {
                "@id": .value,
                "@type": "rdfs:Class"
            }
        },
        (
            $classPropertiesMap[$className] | select(. != null) | .[] |
            {
                key: py_property_to_json_property,
                value: {
                    "@id": $propertiesMap[.],
                    "@type": "rdfs:Property"
                }
            }
        )
    ] | from_entries
) as $classPropertyContext |

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
        then $propertiesMap[.]
    else null
    end;

([ keys | .[] | get_ns_mapping | { key: .prefix, value: .extension} ] | from_entries) as $nsExtensions |

(
    [
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
        ($classPropertyContext | to_entries | .[]),
        ($context | to_entries | .[])
    ] |
    from_entries
) as $context |

([
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
                .[0] as $property |
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
] | flatten | prune_nulls) as $shapes |

{
    "@context": $context,
    "@shapes": $shapes
}


