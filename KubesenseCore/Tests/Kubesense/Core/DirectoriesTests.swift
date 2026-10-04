/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities
import KubesenseInternal
@testable import KubesenseCore

class DirectoriesTests: XCTestCase {
    lazy var directory = Directory(url: temporaryDirectory)

    override func setUp() {
        super.setUp()
        CreateTemporaryDirectory()
    }

    override func tearDown() {
        DeleteTemporaryDirectory()
        super.tearDown()
    }

    func testWhenCreatingCoreDirectory_thenItsNameIsUniqueForClientTokenAndSite() throws {
        // Given
        let fixtures: [(instanceName: String, site: KubesenseSite, expectedName: String)] = [
            ("abcdef", .prod, "593a89b98809cfd20c6deaa3e05d1ef7deb60e76a3f27ff4849ff333b49afa23"),
            ("abcdef", .staging, "308d710a0422207d664f7ceead3b07cb5dd8030854af5bca13ae3f5312a04961"),
            ("ghijkl", .prod, "8bd701ac506bb06888c51f269322c44be3a3b7500253a0df8c47d47f1f1a52db"),
            ("ghijkl", .staging, "657c0701dc437c07f476389285e74fe46b7b7b872f59ca7216565c42b1e3b9f2"),
        ]

        // When
        let coreDirectories = try fixtures.map { instanceName, site, _ in
            try CoreDirectory(
                in: directory,
                instanceName: instanceName,
                site: site
            )
        }
        defer { coreDirectories.forEach { $0.delete() } }

        // Then
        zip(fixtures, coreDirectories).forEach { fixture, coreDirectory in
            let directoryName = coreDirectory.coreDirectory.url.lastPathComponent
            XCTAssertEqual(directoryName, fixture.expectedName)
            XCTAssertFalse(
                directoryName.contains(fixture.instanceName),
                "The core directory name must not include client token"
            )
        }
    }

    func testGivenDifferentSDKConfigurations_whenCreatingCoreDirectories_thenEachDirectoryIsUnique() throws {
        // When
        let coreDirectories = try (0..<50).map { index in
            try CoreDirectory(
                in: directory,
                instanceName: .mockRandom(among: .alphanumerics, length: 31) + "\(index)",
                site: .mockRandom()
            )
        }
        defer { coreDirectories.forEach { $0.delete() } }

        // Then
        let uniqueCoreDirectoryURLs = Set(coreDirectories.map({ $0.coreDirectory.url }))
        XCTAssertEqual(
            coreDirectories.count,
            uniqueCoreDirectoryURLs.count,
            "It must create unique core directory URL for each SDK configuration"
        )
    }

    func testGivenCoreDirectory_whenCreatingFeatureDirectories_thenTheirPathsAreRelative() throws {
        // Given
        let coreDirectory = temporaryCoreDirectory.create()
        defer { coreDirectory.delete() }

        // When
        let featureDirectories = try coreDirectory.getFeatureDirectories(forFeatureNamed: .mockRandom())

        // Then
        XCTAssertTrue(
            featureDirectories.authorized.url.path.contains(coreDirectory.coreDirectory.url.path),
            "Feature's authorized directory must be relative to core directory"
        )
        XCTAssertTrue(
            featureDirectories.unauthorized.url.path.contains(coreDirectory.coreDirectory.url.path),
            "Feature's unauthorized directory must be relative to core directory"
        )
    }
}
