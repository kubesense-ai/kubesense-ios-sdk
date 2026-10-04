#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# -----------------------------------------------------------
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2019-Present Datadog, Inc.
# -----------------------------------------------------------

import sys
import traceback
import argparse
from src.dogfood.package_resolved import PackageResolvedFile, PackageID
from src.utils import print_succ, print_err

def dogfood(args):
    # Read kubesense-ios-sdk `Package.resolved``
    kubesense_sdk_ios_package = PackageResolvedFile(path=args.dogfooded_package_resolved_path)
    kubesense_sdk_ios_package.print()

    if kubesense_sdk_ios_package.version > 3:
        raise Exception(
            f'The `{kubesense_sdk_ios_package.path}` uses version ({kubesense_sdk_ios_package.version}) not supported by dogfooding automation.'
        )

    # Read dependent `Package.resolved`
    dependent_package = PackageResolvedFile(path=args.repo_package_resolved_path)
    
    # Update version of `kubesense-ios-sdk`:
    dependent_package.update_dependency(
        package_id=PackageID(v1='KubesenseSDK', v2='kubesense-ios-sdk'),
        new_branch=args.dogfooded_branch,
        new_revision=args.dogfooded_commit,
        new_version=None
    )

    # Add or update `kubesense-ios-sdk` dependencies:
    for dependency_id in kubesense_sdk_ios_package.read_dependency_ids():
        dependency = kubesense_sdk_ios_package.read_dependency(package_id=dependency_id)

        if dependent_package.has_dependency(package_id=dependency_id):
            dependent_package.update_dependency(
                package_id=dependency_id,
                new_branch=dependency['state'].get('branch'),
                new_revision=dependency['state']['revision'],
                new_version=dependency['state'].get('version'),
            )
        else:
            dependent_package.add_dependency(
                package_id=dependency_id,
                repository_url=dependency['location'],
                branch=dependency['state'].get('branch'),
                revision=dependency['state']['revision'],
                version=dependency['state'].get('version'),
            )

    dependent_package.save()
    dependent_package.print()

    print_succ(f'kubesense-ios-sdk dependency was successfully updated in "{args.repo_package_resolved_path}" to:')
    print_succ(f'    → branch: {args.dogfooded_branch}')
    print_succ(f'    → commit: {args.dogfooded_commit}')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Updates kubesense-ios-sdk dependency in "Package.resolved" of SDK-dependent project.')
    parser.add_argument('--dogfooded-package-resolved-path', type=str, required=True, help='Path to "Package.resolved" from kubesense-ios-sdk')
    parser.add_argument('--dogfooded-branch', type=str, required=True, help='Name of the branch to dogfood from')
    parser.add_argument('--dogfooded-commit', type=str, required=True, help='SHA of the commit to dogfood')
    parser.add_argument('--repo-package-resolved-path', type=str, required=True, help='Path to "Package.resolved" file in SDK-dependent project (the one to modify)')
    args = parser.parse_args()
    
    try:
        dogfood(args=args)
    except Exception as error:
        print_err(f'Failed to update dependency: {error}')
        print('-' * 60)
        traceback.print_exc(file=sys.stdout)
        print('-' * 60)
        sys.exit(1)

    sys.exit(0)