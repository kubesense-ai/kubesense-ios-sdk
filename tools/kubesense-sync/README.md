# kubesense-sync

Tooling for keeping this fork on top of [DataDog/dd-sdk-ios](https://github.com/DataDog/dd-sdk-ios).
The procedure is in [docs/UPSTREAM_SYNC.md](../../docs/UPSTREAM_SYNC.md).

| File | Purpose |
| --- | --- |
| `rebrand.py apply [--dry-run]` | Rewrites this checkout: content through the token map, paths with `git mv`; refuses case collisions and duplicate source file names |
| `rebrand.py check` | Lists anything still carrying Datadog naming; must print `0 leftover(s)` |
| `rebrand.py collisions` | Run on a pristine upstream tree: identifiers the rules would merge into one name |
| `rebrand.py attribution --ref <tag>` | Proves every attribution line of the upstream tag still exists verbatim |
| `rebrand.py spec --ref <tag>` | Prints the customization layer: the working tree against the rebranded tag |
| `upstream.json` | The baseline release and tag, and the module version map |
| `xcodeproj_add.py` | Registers a new source file in `project.pbxproj` next to a sibling file |
| `verify/build.sh` | Builds library targets for macOS / Mac Catalyst, or type-checks test targets against `verify/XCTestStub.swift`, with the Command Line Tools only |
| `verify/run-runtime-tests.sh` | Runs the swift-testing tests in `verify/runtime` on macOS: sites, endpoint normalization, the remote configuration document and provider, a core applying a cached document, and the Logs / Trace / Flags exposure upload URLs and headers |

`rebrand.py` is Python 3 with no dependencies. Its token map is `RULES`; `PRESERVED_TOKENS` (substrings) and
`PRESERVED_PATTERNS` (whole names only, empty today) are never rewritten, and
`PRESERVED_LINE` protects the attribution notices. It never touches `LICENSE`, `NOTICE`,
`LICENSE-3rdparty.csv`, the fork-owned files (`README.md`, `CLAUDE.md`, `CHANGELOG.md`,
`docs/UPSTREAM_SYNC.md`) or this directory.

`verify/runtime` depends on the repository through `.package(path: "../../../..")`, whose package identity
is the name of the checkout directory: it must be `kubesense-ios-sdk`.
