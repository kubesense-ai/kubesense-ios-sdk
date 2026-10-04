# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.

"""Adds a source file to an Xcode project everywhere a sibling file of the same directory is referenced.

The Kubesense customizations add a few files (RemoteConfigDocument.swift, its tests). SwiftPM and CocoaPods
pick them up by path, but Kubesense/Kubesense.xcodeproj lists every file explicitly. This mirrors the
sibling's file reference, group membership and build files, so the new file lands in the same targets.

Usage:
    python3 tools/kubesense-sync/xcodeproj_add.py Kubesense/Kubesense.xcodeproj/project.pbxproj \
        RCDataModels.swift RemoteConfigDocument.swift
"""
import re, sys, hashlib

def new_id(text, seed):
    h = hashlib.sha1(seed.encode()).hexdigest().upper()
    i = 0
    while True:
        cand = h[i:i+24] if i + 24 <= len(h) else hashlib.sha1((seed+str(i)).encode()).hexdigest().upper()[:24]
        if cand not in text:
            return cand
        i += 1

def add(path, sibling, newname):
    text = open(path).read()
    if f'/* {newname} */ = {{isa = PBXFileReference' in text:
        print(f'{newname}: already referenced'); return
    m = re.search(r'\t\t(\w{24}) /\* ' + re.escape(sibling) + r' \*/ = \{isa = PBXFileReference; ([^\n]*)\};\n', text)
    assert m, sibling
    sib_ref = m.group(1)
    attrs = m.group(2).replace(f'path = {sibling};', f'path = {newname};')
    ref = new_id(text, 'ref' + newname)
    text = text[:m.end()] + f'\t\t{ref} /* {newname} */ = {{isa = PBXFileReference; {attrs}}};\n' + text[m.end():]
    # group children
    text, n = re.subn(r'(\n(\t+)' + sib_ref + r' /\* ' + re.escape(sibling) + r' \*/,\n)',
                      lambda g: g.group(1) + f'{g.group(2)}{ref} /* {newname} */,\n', text)
    assert n >= 1, 'group'
    # build files
    builds = re.findall(r'\t\t(\w{24}) /\* ' + re.escape(sibling) + r' in (\w+) \*/ = \{isa = PBXBuildFile; fileRef = ' + sib_ref + r' [^\n]*\n', text)
    for build_id, phase in builds:
        bid = new_id(text, 'build' + newname + build_id)
        line_re = r'\t\t' + build_id + r' /\* ' + re.escape(sibling) + r' in ' + phase + r' \*/ = \{isa = PBXBuildFile;[^\n]*\n'
        mm = re.search(line_re, text)
        text = text[:mm.end()] + f'\t\t{bid} /* {newname} in {phase} */ = {{isa = PBXBuildFile; fileRef = {ref} /* {newname} */; }};\n' + text[mm.end():]
        text, k = re.subn(r'(\n(\t+)' + build_id + r' /\* ' + re.escape(sibling) + r' in ' + phase + r' \*/,\n)',
                          lambda g: g.group(1) + f'{g.group(2)}{bid} /* {newname} in {phase} */,\n', text)
        assert k >= 1, 'phase'
    open(path, 'w').write(text)
    print(f'{newname}: 1 file ref, {n} group entr(y/ies), {len(builds)} build file(s)')

if __name__ == '__main__':
    add(sys.argv[1], sys.argv[2], sys.argv[3])
