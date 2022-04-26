import { exec, ExecException, ChildProcess } from "child_process";

const SH_DIR = __dirname + "/sh/";
const TIMEOUT_SEC = 180;
const SLEEP_INTERVAL = 0.5;

export class Ticket {
    end: boolean = false;
    process: ChildProcess | null = null;
    async wait() {
        let timeoutFlag = false;
        const start = new Date().getTime();
        while (!this.end && !timeoutFlag) {
            await sleep(SLEEP_INTERVAL);
            timeoutFlag = new Date().getTime() - start > TIMEOUT_SEC * 1000;
        }
    }
}

function sleep(sec: number) {
    return new Promise((resolve) => setTimeout(resolve, sec * 1000));
}

export function execSh(exeName: string, args: string[] = []): Ticket {
    let tic = new Ticket();
    let cb = (error: ExecException | null, stdout: string | Buffer, stderr: string | Buffer) => {
        if (stdout)
            console.log(stdout);
        if (error)
            throw error;
        else if (stderr)
            throw Error(stderr.toString());
        tic.end = true;
    };
    tic.process = exec(SH_DIR + exeName + ".sh " + args.join(" "), cb);
    return tic;
}
