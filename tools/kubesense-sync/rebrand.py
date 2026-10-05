# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.

"""Rewrite an upstream Datadog dd-sdk-ios tree into Kubesense terminology.

The token map below is the whole of the mechanical part of the fork. Everything it cannot express —
the site model, the collector endpoint, the upload paths, remote configuration, versions — is a
hand-made customization, listed in docs/UPSTREAM_SYNC.md, and has to be re-applied after running this.

Usage:
    python3 tools/kubesense-sync/rebrand.py apply [--dry-run]      # rebrand this checkout in place
    python3 tools/kubesense-sync/rebrand.py check                  # list what is still unbranded
    python3 tools/kubesense-sync/rebrand.py collisions             # identifiers the rules would merge
    python3 tools/kubesense-sync/rebrand.py attribution --ref <tag> # prove the notices survived
    python3 tools/kubesense-sync/rebrand.py spec --ref <tag>       # print the fork's customizations

`apply` deletes the upstream paths the fork does not ship (`REMOVED_PATHS`), rewrites the content of
every other tracked text file, then renames paths with `git mv` so that history follows the files. It is idempotent: running it twice changes nothing the second time.
Paths are renamed with the very same rules as contents, so that references to files from
`Package.swift`, the podspecs and the Xcode projects keep matching the files on disk.
"""

import argparse
import collections
import difflib
import filecmp
import os
import re
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

# Apache-2.0 §4 requires redistributions to keep upstream's attribution notices. These lines are
# never rewritten, wherever they appear.
PRESERVED_LINE = re.compile(
    r'This product includes software developed at Datadog'
    # The same notice, wrapped onto a second line.
    r'|at Datadog \(https://www\.datadoghq\.com/?\)'
    r'|^\W*Datadog \(https://www\.datadoghq\.com/?\)'
    r'|Copyright (?:©\s*|\([cC]\)\s*)?\d{4}(?:\s*-\s*(?:Present|\d{4}))? Datadog'
    # A copyright line wrapped before the holder's name.
    r'|^\W*Datadog, Inc\.\s*$'
    # Third-party files carry a modification notice naming Datadog (Kronos, Sysctl, Flight School), or
    # credit Datadog as the author of their changes (the symbol prefixing of the vendored protobuf-c).
    r'|(?:altered|modified) by Datadog'
    r'|\\authors Datadog Inc\.'
    # The header of the fork's own files names the upstream project it adds to.
    r'|Kubesense addition to the fork of dd-sdk-ios'
)

# Whole files that are legal notices.
PRESERVED_FILES = re.compile(r'(^|/)(LICENSE|NOTICE|LICENSE-3rdparty\.csv)$')

# Upstream paths this fork does not ship: Datadog's internal CI (GitLab pipeline, Chainguard tokens, code
# owners, Synthetics end-to-end and benchmark apps, dogfooding into Datadog's apps, the Vault client and
# the scripts built on it, the CI environment check, the Confluence publisher); the Session Replay
# snapshot tests, whose reference images live in Datadog's private snapshots repository (their
# SRFixtures package stays); the Xcode file templates, which stamp new files with Datadog's copyright;
# the profiling protobuf and Swift Package Index doc generators; the Xcode project's performance
# baselines, recorded on Datadog's devices for test classes that no longer exist; Datadog's GitHub issue
# and PR templates, Dependabot and stale-issue settings, and the agent skills for its branch, commit, PR
# and feature-docs workflow; and the documents that only make sense with them. The fork must not reuse
# these paths for files of its own: `apply` would delete them. `apply` deletes them, so every upgrade drops them again; `spec` therefore never sees them,
# and `attribution` does not expect their notices, since a file that is not distributed carries no
# notice to keep. Matched against upstream's and the rebranded spelling.
REMOVED_PATHS = re.compile(
    r'^(E2ETests|BenchmarkTests|tools/dogfooding|tools/sr-snapshots|tools/secrets|tools/xcode-templates'
    r'|\.github/chainguard|\.github/ISSUE_TEMPLATE|Kubesense/Kubesense\.xcodeproj/xcshareddata/xcbaselines'
    r'|\.claude/skills/(git-branch|git-commit|open-pr|update-feature-docs))/'
    # Everything of the snapshot tests but SRFixtures, a package the IntegrationTests runner imports.
    r'|^KubesenseSessionReplay/SRSnapshotTests/(?!SRFixtures/)'
    r'|^(\.gitlab-ci\.yml|\.github/CODEOWNERS|\.github/PULL_REQUEST_TEMPLATE\.md|\.github/dependabot\.yml'
    r'|\.github/workflows/stale\.yml|MIGRATION\.md|docs/session_replay_performance\.md|\.github/workflows/changelog-to-confluence\.yaml'
    r'|tools/(e2e-build-upload|benchmark-build-upload|runner-setup|upload-smoke-test-reports|sr-snapshot-test'
    r'|env-check|protoc-pprof|doc-build)\.sh)$'
)

# Files this fork owns outright. They talk about upstream on purpose, so the rules never touch them;
# `spec` still carries them over as part of the customization layer.
FORK_OWNED_FILES = re.compile(r'^(README\.md|CLAUDE\.md|docs/UPSTREAM_SYNC\.md)$|(^|/)CHANGELOG\.md$')

# Tokens that must keep their upstream spelling: they name things that exist outside this repository
# (external projects and tools, a Datadog-hosted test page), or wire names the Kubesense Android SDK
# kept as they are.
PRESERVED_TOKENS = [
    # Upstream projects with no Kubesense counterpart.
    'github.com/DataDog/rum-events-format',
    'github.com/Datadog/rum-events-format',
    'github.com/DataDog/dd-go',
    'github.com/DataDog/datadog-ci',
    'github.com/DataDog/dd-sdk-swift-testing',
    'github.com/DataDog/dd-sdk-ios-apollo-interceptor',
    'DataDog/dd-mobile-session-replay-snapshots',
    # Hosts the prebuilt OpenTelemetryApi binary the Cartfile depends on, for Carthage users.
    'DataDog/opentelemetry-swift-packages',
    'dd-mobile-session-replay-snapshots',
    'dd-sdk-ios-apollo-interceptor',
    'dd-openfeature-provider-swift',
    'dd-sdk-swift-testing',
    # The Swift package product of dd-sdk-swift-testing, resolved by name from the Xcode project.
    'DatadogSDKTesting',
    # Its `@Suite(.datadogTesting)` trait (TestUtilities stubs it when the package is not linked).
    'datadogTesting',
    # Command line tools of Datadog's own CI.
    '@datadog/datadog-ci',
    'datadog-ci',
    'dd-octo-sts',
    'dd-trace-java',
    'dd-trace-go',
    'datadoghq.atlassian.net',
    'ci-dd-sdk-ios',
    'datadoghq.dev',
    # The flags assignments request keeps these headers (Android `PrecomputedAssignmentsRequestFactory`).
    # `DD-CLIENT-TOKEN` is the same header, compared case-insensitively to recognise the SDK's own requests.
    'dd-client-token',
    'DD-CLIENT-TOKEN',
    'dd-application-id',
    # Field of the precompute-assignments request body, unchanged in the Android flags module.
    '"dd_env"',
]

# Tokens kept like PRESERVED_TOKENS, but only as whole names. The Android fork kept the log correlation
# attributes `dd.trace_id` / `dd.span_id` on the wire, while it renamed the RUM ones `_dd.trace_id` /
# `_dd.span_id` to `_kubesense.*` (`RumAttributes.TRACE_ID`): a plain substring mask would keep both.
PRESERVED_PATTERNS = [
    re.compile(r'(?<![A-Za-z0-9_])dd\.(?:trace|span)_id\b'),
]

# Interface Builder object ids (`ADw-wv-DDT`, `dHi-dd-Jze`) are opaque and sometimes look like
# `DD`/`dd` prefixes. They are masked so that no rule rewrites them.
IB_OBJECT_ID = re.compile(r'(?<![A-Za-z0-9-])[A-Za-z0-9]{3}-[A-Za-z0-9]{2}-[A-Za-z0-9]{3}(?![A-Za-z0-9-])')

# Ordered: specific rules first, generic ones last.
RULES = [
    # --- repositories -----------------------------------------------------------------------------
    (r'github\.com/[Dd]ata[Dd]og/dd-sdk-ios(?![\w-])', 'github.com/kubesense-ai/kubesense-ios-sdk'),
    (r'github\.com/[Dd]ata[Dd]og/dd-sdk-android(?![\w-])', 'github.com/kubesense-ai/kubesense-android-sdk'),
    (r'github\.com/[Dd]ata[Dd]og/dd-sdk-flutter(?![\w-])', 'github.com/kubesense-ai/kubesense-flutter-sdk'),
    (r'github\.com/[Dd]ata[Dd]og/browser-sdk(?![\w-])', 'github.com/kubesense-ai/kubesense-browser-sdk'),
    (r'(?<![\w/-])[Dd]ata[Dd]og/dd-sdk-ios(?![\w-])', 'kubesense-ai/kubesense-ios-sdk'),
    (r'(?<![\w-])dd-sdk-ios(?!\w)', 'kubesense-ios-sdk'),
    (r'(?<![\w-])dd-sdk-android(?!\w)', 'kubesense-android-sdk'),
    (r'(?<![\w-])dd-sdk-flutter(?!\w)', 'kubesense-flutter-sdk'),

    # --- browser SDK (WebView tracking) -----------------------------------------------------------
    # The browser fork spells this one with a capital S; it is looked up by name at runtime
    # (`window.KubeSenseEventBridge`, packages/core/src/transport/eventBridge.ts).
    (r'\bDatadogEventBridge\b', 'KubeSenseEventBridge'),
    (r'\bDD_RUM\b', 'KUBESENSE_SDK'),
    (r'\bDD_LOGS\b', 'KUBESENSE_LOGS'),

    # --- hosts, bundle identifiers, e-mails -------------------------------------------------------
    (r'docs\.datadoghq\.com', 'docs.kubesense.ai'),
    (r'app\.datadoghq\.com', 'app.kubesense.ai'),
    (r'www\.datadoghq\.com', 'www.kubesense.ai'),
    (r'\bcom\.datadog(?:hq|qh)\b', 'ai.kubesense'),
    (r'datadoghq\.com', 'kubesense.ai'),
    (r'datadoghq\.eu', 'kubesense.ai'),
    (r'datad0g\.com', 'dev.kubesense.ai'),
    (r'ddog-gov\.com', 'kubesense.ai'),

    # --- wire names, matching the Android fork's RequestFactory -----------------------------------
    (r'\bDD-API-KEY\b', 'KUBESENSE-API-KEY'),
    (r'\bDD-EVP-ORIGIN-VERSION\b', 'KUBESENSE-EVP-ORIGIN-VERSION'),
    (r'\bDD-EVP-ORIGIN\b', 'KUBESENSE-EVP-ORIGIN'),
    (r'\bDD-REQUEST-ID\b', 'KUBESENSE-REQUEST-ID'),
    (r'\bDD-IDEMPOTENCY-KEY\b', 'KUBESENSE-IDEMPOTENCY-KEY'),
    (r'\bddsource\b', 'ksource'),
    (r'\bddtags\b', 'ktags'),
    (r'\bx-datadog-', 'x-kubesense-'),
    # `_dd`, `_dd.*` and `_dd-custom-header-*`; `\b` would not match after a `_`.
    (r'(?<![A-Za-z0-9])_dd\b', '_kubesense'),

    # --- identifiers ------------------------------------------------------------------------------
    # The Objective-C entry point: `DDDatadog` would otherwise become `KubesenseKubesense`, and
    # `Kubesense` alone collides with the `DatadogTests` test case in the same module.
    (r'(?<![A-Za-z0-9])DDDatadog', 'KubesenseSDK'),
    # Test cases whose `DD` and `Datadog` spellings would merge into one class (and one file name)
    # in the same test target.
    (r'\bDDConfigurationTests\b', 'KubesenseObjcConfigurationTests'),
    (r'\bDDProfilerTests\b', 'KubesenseMachProfilerTests'),
    (r'(?<![A-Za-z0-9])DD_', 'KUBESENSE_'),
    (r'(?<![A-Za-z0-9])dd_', 'kubesense_'),
    (r'DATADOG', 'KUBESENSE'),
    (r'DataDog', 'Kubesense'),
    (r'Datadog', 'Kubesense'),
    (r'datadog', 'kubesense'),
    # Objective-C names (`DDRUMMonitor`), prefixed types and test helpers (`DDSpan`, `DDAssertEqual`).
    # Not `KS`: KSCrash, which the crash reporting module imports, owns that prefix.
    (r'(?<![A-Za-z0-9])DD(?=[A-Z])', 'Kubesense'),
    (r'(?<![A-Za-z0-9])(Mock|NoOp)?Dd(?=[A-Z])', lambda m: f'{m.group(1) or ""}Kubesense'),
    (r'(?<![A-Za-z0-9])dd(?=[A-Z])', 'kubesense'),
    (r'(?<![A-Za-z0-9-])dd-(?=[A-Za-z\\])', 'kubesense-'),
    (r'(?<=api-surface-)dd-', 'kubesense-'),
]

COMPILED = [(re.compile(pattern), replacement) for pattern, replacement in RULES]


def _mask(line, tokens):
    placeholders = {}
    for index, token in enumerate(tokens):
        if token in line:
            key = f'\x00{index}\x00'
            placeholders[key] = token
            line = line.replace(token, key)

    def keep_pattern(match):
        key = f'\x00p{len(placeholders)}\x00'
        placeholders[key] = match.group(0)
        return key

    for pattern in PRESERVED_PATTERNS:
        line = pattern.sub(keep_pattern, line)
    ib_ids = []

    def keep_ib(match):
        ib_ids.append(match.group(0))
        return f'\x01{len(ib_ids) - 1}\x01'

    line = IB_OBJECT_ID.sub(keep_ib, line)
    return line, placeholders, ib_ids


def _unmask(line, placeholders, ib_ids):
    for index, value in enumerate(ib_ids):
        line = line.replace(f'\x01{index}\x01', value)
    for key, token in placeholders.items():
        line = line.replace(key, token)
    return line


def rebrand_line(line):
    if PRESERVED_LINE.search(line):
        return line
    line, placeholders, ib_ids = _mask(line, PRESERVED_TOKENS)
    for pattern, replacement in COMPILED:
        line = pattern.sub(replacement, line)
    return _unmask(line, placeholders, ib_ids)


def rebrand_text(text):
    return ''.join(rebrand_line(line) for line in text.splitlines(keepends=True))


def rename_path(path):
    # The same rules as the content, component by component, so that every reference to a file
    # (Package.swift, podspecs, project.pbxproj) is rewritten exactly like the file's own name.
    return '/'.join(rebrand_line(part) for part in path.split('/'))


def tracked_files(root=REPO_ROOT):
    """The files to consider: tracked ones in a git checkout, every file in an exported tree."""
    if os.path.exists(os.path.join(root, '.git')):
        output = subprocess.run(['git', 'ls-files', '-z'], cwd=root, capture_output=True, check=True).stdout
        return [path for path in output.decode().split('\0') if path]
    files = []
    for directory, subdirectories, names in os.walk(root):
        # A symlink to a directory is a single tracked entry in git, listed with the subdirectories here.
        links = [name for name in subdirectories if os.path.islink(os.path.join(directory, name))]
        for name in names + links:
            files.append(os.path.relpath(os.path.join(directory, name), root))
    return sorted(files)


def is_text(data):
    return b'\0' not in data[:8192]


def skipped(path):
    return (
        PRESERVED_FILES.search(path)
        or FORK_OWNED_FILES.search(path)
        or path.startswith('tools/kubesense-sync/')
    )


def removed(path):
    return bool(REMOVED_PATHS.search(path) or REMOVED_PATHS.search(rename_path(path)))


def remove_paths(paths, dry_run, root, use_git):
    if dry_run or not paths:
        return
    if use_git:
        subprocess.run(
            ['git', 'rm', '-q', '--pathspec-from-file=-', '--pathspec-file-nul'],
            cwd=root, input='\0'.join(paths).encode(), check=True,
        )
    else:
        for path in paths:
            os.remove(os.path.join(root, path))


def read_text(absolute):
    if os.path.islink(absolute) or not os.path.isfile(absolute):
        return None
    with open(absolute, 'rb') as handle:
        data = handle.read()
    if not is_text(data):
        return None
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return None


SOURCE_FILE = re.compile(r'\.(swift|m|mm|h|c|cpp)$')


def apply(dry_run, root=REPO_ROOT, quiet=False):
    use_git = os.path.exists(os.path.join(root, '.git'))
    files = tracked_files(root)
    dropped = [path for path in files if removed(path)]
    remove_paths(dropped, dry_run, root, use_git)
    if not quiet:
        print(f'removed: {len(dropped)} file(s) {"would be deleted" if dry_run else "deleted"}')
    files = [path for path in files if not removed(path)]
    changed = 0
    for path in files:
        if skipped(path):
            continue
        absolute = os.path.join(root, path)
        text = read_text(absolute)
        if text is None:
            if os.path.isfile(absolute) and not os.path.islink(absolute) and not quiet:
                with open(absolute, 'rb') as handle:
                    if is_text(handle.read()):
                        print(f'skipped (not utf-8): {path}', file=sys.stderr)
            continue
        rebranded = rebrand_text(text)
        if rebranded != text:
            changed += 1
            if not dry_run:
                with open(absolute, 'w', encoding='utf-8', newline='') as handle:
                    handle.write(rebranded)
    if not quiet:
        print(f'content: {changed} file(s) {"would change" if dry_run else "changed"}')

    renames = {path: rename_path(path) for path in files if not skipped(path)}
    renames = {source: target for source, target in renames.items() if source != target}

    # macOS checkouts are case-insensitive: two sources landing on paths that differ only by case
    # would silently overwrite one another. Directories are checked as well as files.
    final_paths = (set(files) - set(renames)) | set(renames.values())
    seen = {}
    for path in final_paths:
        parts = path.split('/')
        for depth in range(1, len(parts) + 1):
            prefix = '/'.join(parts[:depth])
            key = prefix.lower()
            if key in seen and seen[key] != prefix:
                sys.exit(f'case collision: {seen[key]} <-> {prefix}')
            seen[key] = prefix
    targets = list(renames.values())
    if len(targets) != len(set(targets)):
        duplicates = [t for t, n in collections.Counter(targets).items() if n > 1]
        sys.exit(f'two files would be renamed to the same path: {duplicates[:5]}')
    clashes = sorted(set(targets) & (set(files) - set(renames)))
    if clashes:
        sys.exit(f'renames would overwrite existing files: {clashes[:5]}')
    # Two sources with the same file name in one module do not build (Xcode and SwiftPM derive object
    # file names from it), so a rename must not create a duplicate that upstream does not have.
    merged = collections.defaultdict(set)
    for path in files:
        if SOURCE_FILE.search(path):
            target = renames.get(path, path)
            merged[(target.split('/')[0], os.path.basename(target))].add(os.path.basename(path))
    duplicates = sorted(key for key, names in merged.items() if len(names) > 1)
    if duplicates:
        sys.exit(f'renames would create duplicate source file names: {duplicates[:5]}')

    for source, target in sorted(renames.items()):
        if dry_run:
            continue
        os.makedirs(os.path.dirname(os.path.join(root, target)) or root, exist_ok=True)
        if use_git:
            # git mv keeps the history attached to the file.
            subprocess.run(['git', 'mv', source, target], cwd=root, check=True)
        else:
            os.rename(os.path.join(root, source), os.path.join(root, target))
    if not quiet:
        print(f'paths: {len(renames)} file(s) {"would move" if dry_run else "moved"}')

    if not dry_run:
        remove_empty_directories(root)


def remove_empty_directories(root=REPO_ROOT):
    for directory, _, _ in os.walk(root, topdown=False):
        # The .git directory itself, not every path containing ".git" (.github, .gitlab).
        if '.git' in os.path.relpath(directory, root).split(os.sep):
            continue
        # Listed afresh: the walk's own listing predates the removal of this directory's children.
        if directory != root and not os.path.islink(directory) and not os.listdir(directory):
            os.rmdir(directory)


def export_ref(ref, destination):
    archive = subprocess.run(['git', 'archive', '--format=tar', ref], cwd=REPO_ROOT, capture_output=True, check=True)
    subprocess.run(['tar', '-x', '-C', destination], input=archive.stdout, check=True)


def rebranded_upstream(ref, destination):
    """Exports `ref` from this repository's history and rebrands it, without touching the checkout."""
    export_ref(ref, destination)
    apply(dry_run=False, root=destination, quiet=True)


def read_lines(path):
    if os.path.islink(path):
        return [f'symlink -> {os.readlink(path)}\n']
    with open(path, 'rb') as handle:
        data = handle.read()
    if not is_text(data):
        return None
    return data.decode('utf-8', 'replace').splitlines(keepends=True)


def file_mode(path):
    """The git mode of a file, so the patch keeps executable scripts executable."""
    return '100755' if not os.path.islink(path) and os.access(path, os.X_OK) else '100644'


def spec(ref):
    """Prints, as a patch, everything this fork changes on top of the rebranded `ref`.

    That patch is the fork's customization layer: applied to a newer upstream release after
    `apply`, it carries the fork forward.
    """
    with tempfile.TemporaryDirectory() as upstream:
        rebranded_upstream(ref, upstream)
        upstream_files = set(tracked_files(upstream))
        fork_files = set(tracked_files())
        # Untracked, non-ignored files are part of the working fork too.
        untracked = subprocess.run(
            ['git', 'ls-files', '-z', '--others', '--exclude-standard'],
            cwd=REPO_ROOT, capture_output=True, check=True,
        ).stdout.decode().split('\0')
        fork_files |= {path for path in untracked if path}
        for path in sorted(upstream_files | fork_files):
            # Step 2 of the procedure checks these out of the fork before the patch is applied.
            if path.startswith('tools/kubesense-sync/') or path == 'docs/UPSTREAM_SYNC.md':
                continue
            upstream_path = os.path.join(upstream, path)
            fork_path = os.path.join(REPO_ROOT, path)
            in_upstream = path in upstream_files and os.path.lexists(upstream_path)
            in_fork = path in fork_files and os.path.lexists(fork_path)
            if not in_upstream and not in_fork:
                continue
            before = read_lines(upstream_path) if in_upstream else []
            after = read_lines(fork_path) if in_fork else []
            if before is None or after is None:
                if in_upstream and in_fork and not filecmp.cmp(upstream_path, fork_path, shallow=False):
                    print(f'# binary file differs: {path}')
                elif in_upstream != in_fork:
                    print(f'# binary file {"added" if in_fork else "removed"}: {path}')
                continue
            old_mode = file_mode(upstream_path) if in_upstream else None
            new_mode = file_mode(fork_path) if in_fork else None
            if before == after and old_mode == new_mode:
                continue
            source = f'a/{path}' if in_upstream else '/dev/null'
            target = f'b/{path}' if in_fork else '/dev/null'
            sys.stdout.write(f'diff --git a/{path} b/{path}\n')
            if not in_upstream:
                sys.stdout.write(f'new file mode {new_mode}\n')
            elif not in_fork:
                sys.stdout.write(f'deleted file mode {old_mode}\n')
            elif old_mode != new_mode:
                sys.stdout.write(f'old mode {old_mode}\nnew mode {new_mode}\n')
            for line in difflib.unified_diff(before, after, source, target):
                sys.stdout.write(line if line.endswith('\n') else line + '\n\\ No newline at end of file\n')


LEFTOVER = re.compile(
    r'[Dd]ata[Dd]og|DATADOG|datadoghq|datadogqh|\bdd-sdk|ddsource|ddtags'
    r'|(?<![A-Za-z0-9])(?:DD|dd)[_-]'
    r'|(?<![A-Za-z0-9])_dd\b'
    r'|(?<![A-Za-z0-9])(?:Mock|NoOp)?(?:DD|Dd|dd)[A-Z]'
)


def leftovers_in(line):
    if PRESERVED_LINE.search(line):
        return False
    masked, _, _ = _mask(line, PRESERVED_TOKENS)
    return bool(LEFTOVER.search(masked))


def check():
    leftovers = 0
    for path in tracked_files():
        if skipped(path):
            continue
        if leftovers_in(path):
            print(f'path: {path}')
            leftovers += 1
        text = read_text(os.path.join(REPO_ROOT, path))
        if text is None:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if leftovers_in(line):
                print(f'{path}:{number}: {line.strip()[:140]}')
                leftovers += 1
    print(f'{leftovers} leftover(s)')
    return leftovers


IDENTIFIER = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')


def collisions(root=REPO_ROOT):
    """Lists distinct identifiers that the rules would rewrite to the same name.

    Run it on a pristine upstream checkout, before `apply`. Most groups are harmless (an Objective-C
    name such as `DDSite` next to the Swift type `DatadogSite`); a group whose members are declared
    in the same module is a compile error waiting to happen and needs a dedicated rule.
    """
    targets = collections.defaultdict(set)
    for path in tracked_files(root):
        if skipped(path):
            continue
        text = read_text(os.path.join(root, path))
        if text is None:
            continue
        for line in text.splitlines():
            if PRESERVED_LINE.search(line):
                continue
            for token in IDENTIFIER.findall(line):
                targets[rebrand_line(token)].add(token)
    groups = {target: sources for target, sources in targets.items() if len(sources) > 1}
    for target in sorted(groups):
        print(f'{target}: {", ".join(sorted(groups[target]))}')
    print(f'{len(groups)} group(s)')


def attribution(ref):
    """Proves that every attribution line of `ref` still exists verbatim in the fork."""
    with tempfile.TemporaryDirectory() as upstream:
        export_ref(ref, upstream)
        expected = collections.Counter()
        for path in tracked_files(upstream):
            if removed(path):
                continue
            text = read_text(os.path.join(upstream, path))
            if text is None:
                continue
            # Compared without surrounding whitespace: NOTICE quotes upstream's notice indented.
            for line in text.splitlines():
                if PRESERVED_LINE.search(line):
                    expected[line.strip()] += 1
        actual = collections.Counter()
        for path in tracked_files():
            text = read_text(os.path.join(REPO_ROOT, path))
            if text is None:
                continue
            for line in text.splitlines():
                if PRESERVED_LINE.search(line):
                    actual[line.strip()] += 1
        missing = {line: count - actual[line] for line, count in expected.items() if actual[line] < count}
        for line, count in sorted(missing.items()):
            print(f'missing x{count}: {line.strip()[:140]}')
        print(f'{sum(expected.values())} attribution line(s) in {ref}, '
              f'{sum(actual.values())} in the fork, {sum(missing.values())} missing')
        return sum(missing.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    apply_parser = sub.add_parser('apply')
    apply_parser.add_argument('--dry-run', action='store_true')
    sub.add_parser('check')
    sub.add_parser('collisions')
    attribution_parser = sub.add_parser('attribution')
    attribution_parser.add_argument('--ref', required=True, help='the upstream tag this fork is based on')
    spec_parser = sub.add_parser('spec')
    spec_parser.add_argument('--ref', required=True, help='the upstream tag this fork is based on')
    args = parser.parse_args()
    if args.command == 'apply':
        apply(args.dry_run)
    elif args.command == 'spec':
        spec(args.ref)
    elif args.command == 'collisions':
        collisions()
    elif args.command == 'attribution':
        sys.exit(1 if attribution(args.ref) else 0)
    else:
        sys.exit(1 if check() else 0)


if __name__ == '__main__':
    main()
