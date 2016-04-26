# RedGate.ThirdParty.NodeJs

This repository is used to build the `RedGate.ThirdParty.NodeJs` NuGet package.

## How the NuGet package works

The `RedGate.ThirdParty.NodeJs` NuGet package contains the follow files of interest:

- `tools\nodejs-sfx.exe` - a self-extracting 7-zip archive file that contains the nodejs fileset.
- `build\RedGate.ThirdParty.NodeJs.props` - this msbuild properties file is imported into your project when you install the package. It defines the following useful msbuild properties that can then be referenced in your project file.
  - `NodeJsVersion` - the version number of nodejs, e.g. "5.10.1".
  - `NodeJsDir` - the full path of the nodejs folder, including the final folder separator character, e.g. `"C:\Tools\NodeJs\5.10.1\"`.
  - `NodeJsPath` - the full path of the `node.exe` file, e.g. `"C:\Tools\NodeJs\5.10.1\node.exe"`.
  - `NpmPath` - the full path of the `npm.cmd` file, e.g. `"C:\Tools\NodeJs\5.10.1\npm.cmd"`.
 - `build\RedGate.ThirdParty.NodeJs.targets` - this msbuild targets file is imported into your project when you install the package. It defines a build target to ensure that the nodejs files in the `nodejs-sfx.exe` archive are extracted to the `NodeJsDir` folder, ready to be used by the rest of the build.
 
To avoid problems with the 256 character limit of paths on NTFS, nodejs is extracted to `C:\Tools\NodeJs` rather than somewhere relative to your own project files. This has implications when multiple builds on the same machine:

1. Your own builds should not modify the contents of the extracted nodejs. To do so risks multiple builds interfering with each other. For example, don't try to install any npm packages globally.
2. The build target that extracts nodejs is thread safe. A global mutext is used to ensure that multiple builds will not attempt to extract nodejs at the same time.

## How this repository works

### Prerequisites

To build the `RedGate.ThirdParty.NodeJs`, you need to satisfy the following:

- Have the 64-bit Windows version of nodejs cleanly installed to `C:\Program Files\nodejs\'
- Have the 64-bit version of 7-zip installed.

### Run the build script.

1. From a PowerShell console, run the `.build\_init.ps1` script. This will establish three global functions, `Build`, `Clean` and `Rebuild`.
2. From the same console, invoke `Build`. This will produce a `dist` sub-folder that contains both the newly built NuGet package.

## Support

Questions, bug reports and pull requests can be submitted on the [project's GitHub page](https://github.com/red-gate/RedGate.ThirdParty.NodeJs/). If you are internal to Redgate, you can also post on the [#build](https://redgate.slack.com/messages/build/) Slack channel.      