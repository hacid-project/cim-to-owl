from types import ModuleType

def cim_obj_to_jsonable_obj(obj: any) -> any:
    if callable(obj):
        result = cim_obj_to_jsonable_obj(obj())
        if obj.__doc__:
            result["annotation"] = obj.__doc__
        return result
    as_dict = None
    if isinstance(obj, dict):
        as_dict = obj
        # return dict([(k,convert(v)) for (k,v) in as_dict.items() if not k.startswith("__")])
    # if hasattr(obj, "__dict__"): #isinstance(module, ModuleType):
    if isinstance(obj, ModuleType):
        # as_dict = dict([(m.m_name, m.ml_meth) for m in PyModule_GetDef(obj).m_methods])
        as_dict = dict([(
            k,v) for (k,v) in obj.__dict__.items() if callable(v)
        ])
        # return dict([(k,convert_and_(v)) for (k,v) in as_dict.items() if not k.startswith("__")])
    if as_dict:
        return dict([
            (k,cim_obj_to_jsonable_obj(v))
            for (k,v) in as_dict.items()
            if not k.startswith("__")
        ])
    if isinstance(obj, list) or isinstance(obj, tuple): # isinstance(obj, Sequence):
        return [cim_obj_to_jsonable_obj(child_obj) for child_obj in obj]
    if isinstance(obj, set): # isinstance(obj, Sequence):
        converted = [cim_obj_to_jsonable_obj(child_obj) for child_obj in obj]
        if all([isinstance(item,dict) for item in converted]):
            return dict([(k,v) for item in converted for (k,v) in item.items()])
        else:
            return converted
    return str(obj)

