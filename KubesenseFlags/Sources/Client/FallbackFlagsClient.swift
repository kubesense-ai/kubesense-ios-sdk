/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

internal final class FallbackFlagsClient: FlagsClientProtocol {
    private let name: String
    private weak var core: (any KubesenseCoreProtocol)?

    let state: FlagsStateObservable = NOPStateObservable.error

    init(name: String, core: any KubesenseCoreProtocol) {
        self.name = name
        self.core = core
    }

    func setEvaluationContext(
        _ context: FlagsEvaluationContext,
        completion: @escaping (Result<Void, FlagsError>) -> Void
    ) {
        reportIssue(
            """
            Using fallback client to set the evaluation context. \
            Ensure that a client named '\(name)' is created before using it.
            """,
            in: core
        )
        completion(.failure(.clientNotInitialized))
    }

    func getDetails<T>(key: String, defaultValue: T) -> FlagDetails<T> where T: FlagValue, T: Equatable {
        KS.logger.error(
            """
            Using fallback client to get '\(key)' value. \
            Ensure that a client named '\(name)' is created before using it.
            """
        )
        return FlagDetails(key: key, value: defaultValue, error: .providerNotReady)
    }
}

// MARK: - Internal methods consumed by the React Native SDK

extension FallbackFlagsClient: FlagsClientInternal {
    func getFlagAssignments() -> [String: FlagAssignment]? {
        KS.logger.error(
            """
            Using fallback client to get all flag values. \
            Ensure that a client named '\(name)' is created before using it.
            """
        )
        return nil
    }

    func sendFlagEvaluation(key: String, assignment: FlagAssignment, context: FlagsEvaluationContext) {
        KS.logger.error(
            """
            Using fallback client to track '\(key)'. \
            Ensure that a client named '\(name)' is created before using it.
            """
        )
    }
}
