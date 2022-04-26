export interface BbtDef {
    need: string[];
    resource: string;
    operations: CmdDef[];
    option: number;
}

export function isBbtDef(def: any): def is BbtDef {
    let ok = def.need !== undefined &&
        def.resource !== undefined &&
        def.operations !== undefined;
    if (ok) {
        let ope = def.operations;
        if (Array.isArray(ope))
            ok = ok && ope.every(isCmdDef);
        else
            createRequiredNonNullErr("operations");
    }
    return ok;
}

export interface CmdDef {
    name: string;
    command: string;
    exitCode: number;
    expected: Check[];
}

export function isCmdDef(def: any): def is CmdDef {
    let ok = def.name !== undefined
        && def.command !== undefined
        && def.exitCode !== undefined
        && def.expected !== undefined;
    if (ok) {
        let exp = def.expected;
        if (!def.name)
            createRequiredNonNullErr("name");
        else if (!def.command)
            createRequiredNonNullErr("command");
        else if (Array.isArray(exp))
            ok = ok && exp.every(isCheck);
        else
            createRequiredNonNullErr("expected");
    }
    return ok;
}

export interface Check {
    act: string;
    value: string;
}

export function isCheck(def: any): def is Check {
    const ok = def.act !== undefined
        && def.value !== undefined;
    if (ok)
        if (!def.act)
            createRequiredNonNullErr("act");
        else if (!def.value)
            createRequiredNonNullErr("value");
    return ok;
}

function createRequiredNonNullErr(fieldName: string): Error {
    return new Error("The [" + fieldName + "] field must be non null.");
}