# App Extension: Dotnet Project

This is the app to develop the extension "dotnet-project".

It's meant to make it much easier to setup apps so that they work with IntelliSense and the new .csproj format.

Find out more on <https://github.com/2sxc-apps/app-extension-dotnet-project>

## Current Build Layout

The helper is currently composed from one small root import plus a few focused aggregators:

- `app.csproj` imports `extensions/dotnet-project/all-in-one.import.csproj`
- `all-in-one.import.csproj` is the composition root and imports:
  - `namespace-and-output-type.import.props`
  - `defaults.props`
  - `host-resolution.props`
  - `common-references.props`
  - `design-time.props` only when `DesignTimeBuild=true`
  - `edition/ignore-editions.import.props`
- `host-resolution.props` always imports both detection files, resolves `RunningInDnn` and `RunningInOqtane`, validates `HelperHostMode`, then conditionally imports the DNN or Oqtane branch
- `dnn/dnn.props` is a thin DNN aggregator that imports `dnn-settings.props` and `dnn-references.props`
- `oqtane/oqtane.props` is a thin Oqtane aggregator that imports `oqtane-settings.props`
- `design-time.props` is a design-time-only aggregator for Razor tooling and VS Code IntelliSense support
- `common-references.props` contains shared references that depend on the resolved `PathBin`
- `edition/ignore-editions.import.props` removes edition-specific folders from IntelliSense inputs using `IgnoredEditionDirs`

## Current Responsibilities

- `defaults.props`
  - defines default host mode, bin paths, target frameworks and language versions
  - provides a fallback `TargetFramework` so validation can run before host resolution completes
- `host-resolution.props`
  - imports `dnn/dnn-detection.props` and `oqtane/oqtane-detection.props`
  - normalizes `HelperHostMode`
  - sets `RunningInDnn` or `RunningInOqtane`
  - derives `OqtaneIsProd` and `OqtaneIsDev`
  - fails fast on invalid, ambiguous, or missing host resolution
  - conditionally imports `dnn/dnn.props` or `oqtane/oqtane.props`
- `dnn/dnn-detection.props`
  - sets `DetectedDnn=true` when `DotNetNuke.dll` exists under `DnnBinPath`
- `dnn/dnn-settings.props`
  - sets `TargetFramework`, `LangVersion`, and `PathBin` for the DNN branch
- `dnn/dnn-references.props`
  - adds DNN DLL references
  - adds classic legacy Razor DLL references used in DNN scenarios
  - currently also adds the ASP.NET Core 2.2 Razor package references used by the helper
- `oqtane/oqtane-detection.props`
  - detects Oqtane prod and dev layouts using `Oqtane.Server.dll`
- `oqtane/oqtane-settings.props`
  - sets `TargetFramework` and `LangVersion` for the Oqtane branch
  - sets `PathBin` to the prod path when prod is detected, otherwise falls back to the dev path
- `common-references.props`
  - adds shared references from `PathBin` plus `Dependencies\*.dll`
- `design-time/razor-tooling.props`
  - resolves Razor analyzer and helper assembly paths from the installed Razor SDK
- `design-time/design-time-core.props`
  - adds `DESIGN_TIME_BUILD`
  - extends `NoWarn`
  - includes `**\*.cshtml` as `AdditionalFiles`
  - wires the Razor analyzer
- `design-time/dnn-design-time.props`
  - adds the Razor helper assembly references used for legacy Razor IntelliSense when those assemblies can be resolved
- `edition/ignore-editions.import.props`
  - defaults `IgnoredEditionDirs` to `live;bs3;bs4` for backward compatibility
  - supports multiple ignored folders as a semicolon-separated list
  - removes all matching folders from `None`, `Content`, `Compile`, and `EmbeddedResource`
  - normalizes simple spaces around semicolons before expanding the list
  - when overriding from the MSBuild command line, use `%3B` instead of a literal `;`

## Diagrams

### 1. Import flow

```mermaid
flowchart TD
    APP[app.csproj] --> ROOT[all-in-one.import.csproj]

    ROOT --> NS[namespace-and-output-type.import.props<br/>RootNamespace = AppCode<br/>OutputType = Library]
    ROOT --> DEF[defaults.props<br/>defaults for HelperHostMode, paths, TFMs, LangVersion]
    ROOT --> HOST[host-resolution.props<br/>shared host resolution and platform dispatch]
    ROOT --> COMMON[common-references.props<br/>shared DLL references from bin and Dependencies]
    ROOT -->|if DesignTimeBuild is true| DT[design-time.props<br/>aggregate Razor design-time tooling]
    ROOT --> IGN[edition/edition.props<br/>exclude ignored edition folders]

    HOST --> DD[dnn-detection.props<br/>detect DNN markers]
    HOST --> OD[oqtane-detection.props<br/>detect Oqtane markers]
    HOST -->|if RunningInDnn is true| DNN[dnn/dnn.props<br/>aggregate DNN parts]
    HOST -->|if RunningInOqtane is true| OQT[oqtane/oqtane.props<br/>aggregate Oqtane parts]

    DT --> RAZOR[design-time/razor-tooling.props<br/>resolve analyzer and Razor helper paths]
    DT --> DTC[design-time/design-time-core.props<br/>constants, NoWarn, AdditionalFiles, Analyzer]
    DT --> DTDNN[design-time/dnn-design-time.props<br/>legacy Razor helper references]

    DNN --> DS[dnn-settings.props]
    DNN --> DR[dnn-references.props]

    OQT --> OS[oqtane-settings.props]

    IGN --> IGNS[IgnoredEditionDirs<br/>default live<br/>semicolon-separated list]
```

### 2. Host resolution and dispatch

```mermaid
flowchart TD
    DEF[defaults.props] --> HM[HelperHostMode default:<br/>if empty => Auto]
    DEF --> DB[DnnBinPath default:<br/>..\\..\\..\\..\\bin]
    DEF --> OPB[OqtaneProdBinPath default:<br/>..\\..\\..\\..\\..\\..]
    DEF --> ODB[OqtaneDevBinPath default:<br/>..\\..\\..\\..\\..\\..\\bin\\Debug\\net10.0]

    HR[host-resolution.props] --> DD[dnn-detection.props<br/>if DotNetNuke.dll exists under DnnBinPath<br/>then DetectedDnn = true]
    OPB --> OD
    ODB --> OD[oqtane-detection.props<br/>if Oqtane.Server.dll exists in prod path<br/>then DetectedOqtaneProd = true<br/>if Oqtane.Server.dll exists in dev path<br/>then DetectedOqtaneDev = true<br/>if either is true<br/>then DetectedOqtane = true]

    HM --> MODE{HelperHostModeNormalized}
    DD --> AUTO
    OD --> AUTO
    HR --> MODE

    MODE -->|dnn| RD[RunningInDnn = true]
    MODE -->|oqtane| RO[RunningInOqtane = true]
    MODE -->|auto| AUTO{Auto detection}

    AUTO -->|only DNN detected| RD
    AUTO -->|only Oqtane detected| RO
    AUTO -->|both detected| E1[Error:<br/>ambiguous host detection]
    AUTO -->|neither branch matches| E2[Error:<br/>no host markers found]

    MODE -->|invalid mode| E3[Error:<br/>invalid HelperHostMode]

    RO --> PROD{DetectedOqtaneProd = true?}
    PROD -->|yes| P[OqtaneIsProd = true]
    RO --> DEVCHK{DetectedOqtaneDev = true?}
    DEVCHK -->|yes| DEV[OqtaneIsDev = true]
    PROD -->|no prod and no dev marker| DEV

    RD --> IMPD[host-resolution imports dnn.props]
    RO --> IMPO[host-resolution imports oqtane.props]
```

### 3. Platform-specific and design-time branches

```mermaid
flowchart LR
    RD[RunningInDnn = true] --> DS[dnn-settings.props<br/>imported only in DNN branch<br/>TargetFramework from DnnTargetFramework<br/>LangVersion from DnnLangVersion<br/>PathBin from DnnBinPath]
    RD --> DR[dnn-references.props<br/>DotNetNuke references<br/>System.Web references<br/>legacy Razor runtime references<br/>ASP.NET Core 2.2 Razor package references]

    RO[RunningInOqtane = true] --> OS[oqtane-settings.props<br/>imported only in Oqtane branch<br/>TargetFramework from OqtaneTargetFramework<br/>LangVersion from OqtaneLangVersion]
    P[OqtaneIsProd = true] --> OSP[PathBin becomes OqtaneProdBinPath]
    DEV[OqtaneIsDev = true] --> OSD[if PathBin is empty<br/>use OqtaneDevBinPath]

    DT[design-time.props<br/>imported only for DesignTimeBuild] --> RT[design-time tooling aggregate]
    RT --> DTC[design-time-core.props<br/>DESIGN_TIME_BUILD constant<br/>NoWarn extensions<br/>AdditionalFiles and Analyzer wiring]
    RT --> RZ[design-time/razor-tooling.props<br/>resolve analyzer and helper assembly paths<br/>from Razor SDK source-generators or tools]
    RT --> DTDNN[design-time/dnn-design-time.props<br/>Razor Utilities Shared and ObjectPool helper refs]

    COMMON[common-references.props] --> CR[include ToSic DLLs from bin<br/>include Connect.Koi if present<br/>include System.Text.Json if present<br/>include DLLs from Dependencies]
    IGN[edition/ignore-editions.import.props] --> EDI[remove each IgnoredEditionDirs entry<br/>from None Content Compile EmbeddedResource]
```
