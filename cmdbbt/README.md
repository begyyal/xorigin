# Overview

CMDBBT is a automatic testing tool.  
It performs based on the definition described in advance,  
and executes the described command, confirms the results if it matches expected results.

# Premise

- MIT Lisense, description is in source file.
- Compliant to Bash and Docker.

# How to use

Just only describes the definition and execute `./start.sh` .  
The command must be executed at the definition path, not cmdbbt repository root.  
The result is output in stdout.  

It shows definition format, result format, and above shell options in following.  

## Definition format

The definition\`s file is opened as `bbtdef.json` in default.  
If you want to name other, please add definition\`s name to command arguments.  
In this case, first argument excluding options is treated definition`s name.  

```
{
	"need": [
		"a/b/shjp.sh"
	],
	"resource": "resource/cmdbbt/",
	"operations": [
		{
			"name": "test1",
			"command": "./shjp.sh ./test.json ne.mimimi",
			"exitCode": 0,
			"expected": [
				{
					"act": "console-output",
					"value": "22"
				}
			]
		}
	]
}
```

- `need`
  - Common required assets for test commands.
  - This is treated relative path from directory path of definition.
  - Only tip of directory hierarchy is copied to docker, so should describes `./shjp.sh` not `./a/b/shjp.sh` at command in above example.
- `resource`
  - Required assets for each test commands.
  - This is treated relative path from directory path of definition.
  - Please set directories named `operations[].name` by operation, and create `input` and `output` directories under it`s named directories if you need.
  - It shows directory structure example in following.
  ```
  resource/cmdbbt/test1/input/test.json
  resource/cmdbbt/test2/input/hoge.txt
  resource/cmdbbt/test2/output/fuga.txt
  ```
- `operations`
  - A operation in this means one command execution and checkings.
- `operations[].name`
  - Test case name.
  - This must be unique.
- `operations[].command`
  - A command you want to test.
- `operations[].exitCode`
  - Expected exit code.
- `operations[].expected`
  - Pairs containing the type to check and its value.
- `operations[].expected[].act`
  - The type to check.
  - It shows types in following.
  
|name|what matches|
|:---|:---|
|console-output|Stdout which output by the command.|
|file-output|not implimented|
|file-update|not implimented|
|file-delete|not implimented|

- `operations[].expected[].value`
  - The value what is expected to matches.
  - If act type is file matching, this value is treated as a file path.
  - If act type is console-output, array can express multiple line.

## Result format

```
{
    "result": false,
    "errList": [
        {
            "name": "test1",
            "cause": "console-output",
            "actual": [
                "223"
            ]
        }
    ]
}
```

- `result`
  - Test result. `true` means ok, `false` means ng.
- `errList`
  - If result is ng, this contains details of testing failure.
- `errList.name`
  - This is tied to `operations[].name`.
- `errList.cause`
  - Type of a factor of the failure, This is tied to `operations[].expected[].act` or be `exit-code`.
- `errList.actual`
  - Actual values which differed from expected by executing command.
  - If cause type is file matching, this value sets as a file path.

## Command options

|long|short|detail|
|:---|:---|:---|
|--omit-filedef|-o|Omitting `operations[].expected[].act` of file matching.<br>If this is active, it checks if file match implicitly with the resource folder as positive.|
|--apt-get||Required library of apt-get as runtime enviroment.<br>Cmdbbt uses ubuntu image, so the library should be listed in [here](https://packages.ubuntu.com/en/).<br>If need multiple, please separating by commma.|
