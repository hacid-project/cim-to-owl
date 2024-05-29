def one_or_many:
    if length == 0
        then null
    elif length == 1
        then .[0]
    else
        .
    end;

walk(
#    [.|objects| .type  | select(. != null)] as $simple_types |
#    [.|objects| .id  | select(. != null)] as $simple_ids |
    [. |objects|.meta.type | select(. != null and . != "cim.2.shared.DocReference")] as $meta_types |
    [. |objects|.meta.id | select(. != null)] as $meta_ids |
    [. |objects|.meta.institute | select(. != null)] as $meta_institutes |
    [. |objects|.meta.project | select(. != null)] as $meta_projects |
#    if ($meta_types | length > 0)
#        then setpath(["@type"]; $meta_types | one_or_many)
#        else .
#    end |
#    if ($meta_ids | length > 0)
#        then setpath(["@id"]; $meta_ids | one_or_many)
#        else .
#    end |
#    if (($meta_types | length > 0) and (.type != null))
#        then setpath([$meta_types[0] + "_type"]; .type)
#        else .
#    end |
#    if (($meta_types | length > 0) and (.id != null))
#        then setpath([$meta_types[0] + "_id"]; .id)
#        else .
#    end |
    if ($meta_types | length > 0)
        then setpath(["type"]; [.type | select(. != null), $meta_types.[] ] | one_or_many)
        else .
    end |
    if $meta_ids | length > 0
        then setpath(["id"]; [.id | select(. != null), $meta_ids.[] ] | one_or_many)
        else .
    end |
    if $meta_institutes | length > 0
        then setpath(["institute"]; [.institute | select(. != null), $meta_institutes.[] ] | one_or_many)
        else .
    end |
    if $meta_projects | length > 0
        then setpath(["project"]; [.project | select(. != null), $meta_projects.[] ] | one_or_many)
        else .
    end |
    if type == "object"
        then delpaths([["meta"]]) #| delpaths([["type"]]) | delpaths([["id"]])
        else .
    end
) | one_or_many