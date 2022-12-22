export class AssertionType {

    public static readonly CONSOLE_OUTPUT = "console-output";
    public static readonly FILE_OUTPUT = "file-output";
    public static readonly FILE_UPDATE = "file-update";
    public static readonly FILE_DELETE = "file-delete";

    public static readonly values = [
        AssertionType.CONSOLE_OUTPUT,
        AssertionType.FILE_OUTPUT,
        AssertionType.FILE_UPDATE,
        AssertionType.FILE_DELETE
    ];
}

export class PathConstants {

    public static readonly MNT_ROOT = "/mnt/main/";
    public static readonly DEF = "/mnt/main/bbtdef.json";
    public static readonly RESOURCE = "/mnt/main/resource/";
    public static readonly ENV = "/mnt/main/env/";

    public static readonly values = [
        PathConstants.MNT_ROOT,
        PathConstants.DEF,
        PathConstants.RESOURCE,
        PathConstants.ENV
    ];
}

export class ResultStatus {
    public static readonly OK = "ok";
    public static readonly NG = "ng";

    public static get(b: boolean) {
        return b ? this.OK : this.NG;
    }
}

export class Option {
    public static readonly OFD = 1;
}
