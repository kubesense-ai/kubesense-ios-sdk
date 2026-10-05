# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.

"""Turns a KubesenseShopBenchmarks result bundle into a Markdown table of SDK overhead.

Usage:
    python3 Benchmarks/report.py <result.xcresult> [--output report.md]

Each row is one metric; each profile column is the median of its iterations, followed by the change
against the `off` profile (no SDK). Hitch and frame-rate rows only exist on a physical device: the
simulator does not report them.
"""

import argparse
import json
import os
import statistics
import subprocess
import sys

PROFILES = ['off', 'rum', 'replay', 'full']

# (display name prefix, label, test kind, scale from the reported unit, shown unit)
METRICS = [
    ('Duration (ApplicationFirstFramePresentationResponsive)', 'Launch to responsive', 'Launch', 1000, 'ms'),
    ('Duration (Scroll_DraggingAndDeceleration)', 'Scroll duration', 'Scroll', 1000, 'ms'),
    ('Hitch Time Ratio (Scroll_DraggingAndDeceleration)', 'Scroll hitch time ratio', 'Scroll', 1, 'ms/s'),
    ('Frame Rate (Scroll_DraggingAndDeceleration)', 'Scroll frame rate', 'Scroll', 1, 'fps'),
    ('CPU Time', 'CPU time while scrolling', 'Scroll', 1000, 'ms'),
    ('CPU Instructions Retired', 'CPU instructions while scrolling', 'Scroll', 1 / 1000, 'M'),
    ('Memory Peak Physical', 'Peak memory', 'Scroll', 1 / 1024, 'MB'),
    ('Absolute Memory Physical', 'Memory after scrolling', 'Scroll', 1 / 1024, 'MB'),
]


def load_metrics(result_bundle):
    output = subprocess.run(
        ['xcrun', 'xcresulttool', 'get', 'test-results', 'metrics', '--path', result_bundle],
        capture_output=True, check=True, text=True,
    ).stdout
    # {(kind, profile): {display name: [measurements]}}
    results = {}
    for test in json.loads(output):
        # "SDKOverheadBenchmarks/testLaunch_off()" -> ("Launch", "off")
        name = test['testIdentifier'].split('/')[-1].removeprefix('test').removesuffix('()')
        kind, _, profile = name.partition('_')
        for run in test['testRuns']:
            for metric in run['metrics']:
                results.setdefault((kind, profile), {})[metric['displayName']] = metric['measurements']
    return results


def find(measured, prefix):
    for display_name, measurements in measured.items():
        if display_name.startswith(prefix):
            return measurements
    return None


def report(results, device):
    lines = [
        f'Medians of each profile; the change is against `off` (no SDK). Device: {device}.',
        '',
        '| Metric | ' + ' | '.join(PROFILES) + ' |',
        '| --- |' + ' ---: |' * len(PROFILES),
    ]
    for prefix, label, kind, scale, unit in METRICS:
        medians = {}
        for profile in PROFILES:
            measurements = find(results.get((kind, profile), {}), prefix)
            if measurements:
                medians[profile] = statistics.median(measurements) * scale
        if not medians:
            continue
        cells = []
        for profile in PROFILES:
            value = medians.get(profile)
            if value is None:
                cells.append('n/a')
                continue
            cell = f'{value:,.1f} {unit}'
            base = medians.get('off')
            if profile != 'off' and base:
                cell += f' ({(value - base) / abs(base):+.1%})'
            cells.append(cell)
        lines.append(f'| {label} | ' + ' | '.join(cells) + ' |')
    return '\n'.join(lines) + '\n'


def device_name(result_bundle):
    output = subprocess.run(
        ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', result_bundle],
        capture_output=True, check=True, text=True,
    ).stdout
    summary = json.loads(output)
    devices = summary.get('devicesAndConfigurations') or []
    if not devices:
        return 'unknown'
    device = devices[0].get('device', {})
    return ' '.join(filter(None, [device.get('deviceName'), device.get('platform'), device.get('osVersion')]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('result_bundle')
    parser.add_argument('--output', help='also write the table to this file')
    args = parser.parse_args()
    if not os.path.isdir(args.result_bundle):
        sys.exit(f'no result bundle at {args.result_bundle}')
    table = report(load_metrics(args.result_bundle), device_name(args.result_bundle))
    sys.stdout.write(table)
    if args.output:
        with open(args.output, 'w') as handle:
            handle.write(table)


if __name__ == '__main__':
    main()
