/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

@testable import KubesenseCrashReporting

extension KubesenseCrashReport: AnyMockable, RandomMockable {
    public static func mockAny() -> KubesenseCrashReport {
        return .mockWith()
    }

    public static func mockRandom() -> KubesenseCrashReport {
        return KubesenseCrashReport(
            date: .mockRandom(),
            type: .mockRandom(),
            message: .mockRandom(),
            stack: .mockRandom(),
            threads: .mockRandom(),
            binaryImages: .mockRandom(),
            meta: .mockRandom(),
            wasTruncated: .mockRandom(),
            context: .mockRandom(),
            additionalAttributes: mockRandomAttributes()
        )
    }

    public static func mockWith(
        date: Date? = .mockAny(),
        type: String = .mockAny(),
        message: String = .mockAny(),
        stack: String = .mockAny(),
        threads: [KubesenseThread] = .mockAny(),
        binaryImages: [BinaryImage] = .mockAny(),
        meta: Meta = .mockAny(),
        wasTruncated: Bool = .mockAny(),
        context: Data? = .mockAny(),
        additionalAttributes: [String: Encodable]? = nil
    ) -> KubesenseCrashReport {
        return KubesenseCrashReport(
            date: date,
            type: type,
            message: message,
            stack: stack,
            threads: threads,
            binaryImages: binaryImages,
            meta: meta,
            wasTruncated: wasTruncated,
            context: context,
            additionalAttributes: additionalAttributes
        )
    }

    public static func mockRandomWith(context: CrashContext) -> KubesenseCrashReport {
        return mockRandomWith(contextData: context.data)
    }

    public static func mockRandomWith(contextData: Data) -> KubesenseCrashReport {
        return mockWith(
            date: .mockRandomInThePast(),
            type: .mockRandom(),
            message: .mockRandom(),
            stack: .mockRandom(),
            context: contextData,
            additionalAttributes: mockRandomAttributes()
        )
    }
}

extension KubesenseCrashReport.Meta: AnyMockable, RandomMockable {
    public static func mockAny() -> KubesenseCrashReport.Meta {
        return .mockWith()
    }

    public static func mockRandom() -> KubesenseCrashReport.Meta {
        return KubesenseCrashReport.Meta(
            incidentIdentifier: .mockRandom(),
            process: .mockRandom(),
            parentProcess: .mockRandom(),
            path: .mockRandom(),
            codeType: .mockRandom(),
            exceptionType: .mockRandom(),
            exceptionCodes: .mockRandom()
        )
    }

    public static func mockWith(
        incidentIdentifier: String? = .mockAny(),
        process: String? = .mockAny(),
        parentProcess: String? = .mockAny(),
        path: String? = .mockAny(),
        codeType: String? = .mockAny(),
        exceptionType: String? = .mockAny(),
        exceptionCodes: String? = .mockAny()
    ) -> KubesenseCrashReport.Meta {
        return KubesenseCrashReport.Meta(
            incidentIdentifier: incidentIdentifier,
            process: process,
            parentProcess: parentProcess,
            path: path,
            codeType: codeType,
            exceptionType: exceptionType,
            exceptionCodes: exceptionCodes
        )
    }
}
