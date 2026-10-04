/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import KubesenseInternal
import TestUtilities
@_spi(Internal)
@testable import KubesenseCore

class SharedContextTests: XCTestCase {
    func testInitializationWithKubesenseContext_withNilAccountAndUserInfo_setsNilIds() throws {
        // Given
        let context = KubesenseContext.mockWith(userInfo: nil, accountInfo: nil)

        // When
        let sharedContext = SharedContext(kubesenseContext: context)

        // Then
        XCTAssertNil(sharedContext.userId)
        XCTAssertNil(sharedContext.accountId)
    }

    func testInitializationWithKubesenseContext_withCompleteContext() throws {
        // Given
        let context = KubesenseContext.mockWith(
            userInfo: UserInfo(
                id: "user-789"
            ),
            accountInfo: AccountInfo(
                id: "account-999"
            )
        )

        // When
        let sharedContext = SharedContext(kubesenseContext: context)

        // Then
        XCTAssertEqual(sharedContext.userId, "user-789")
        XCTAssertEqual(sharedContext.accountId, "account-999")
    }
}
