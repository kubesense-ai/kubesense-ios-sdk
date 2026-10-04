/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

internal struct CoreContext {
    /// Provides the history of app foreground / background states.
    var applicationStateHistory: AppStateHistory?

    /// Provides the current active RUM context, if any
    var rumContext: RUMCoreContext?

    /// Provides the current user information, if any
    var userInfo: UserInfo?

    /// Provides the current account information, if any
    var accountInfo: AccountInfo?
}

internal final class ContextMessageReceiver: FeatureMessageReceiver {
    /// Creates a new `ContextMessageReceiver`.
    ///
    /// - parameters:
    ///   - samplerProvider: The sampler provider that will be updated with the RUM
    ///   deterministic tracer.
    init(samplerProvider: SamplerProvider) {
        self.samplerProvider = samplerProvider
        self.context = .init()
    }

    /// The up-to-date core context.
    ///
    /// The context is synchronized using a read-write lock.
    @ReadWriteLock
    var context: CoreContext

    /// The tracer sampler that should be updated with the RUM deterministic sampler.
    let samplerProvider: SamplerProvider

    /// Process messages receives from the bus.
    ///
    /// - Parameters:
    ///   - message: The Feature message
    ///   - core: The core from which the message is transmitted.
    func receive(message: FeatureMessage, from core: KubesenseCoreProtocol) -> Bool {
        switch message {
        case .context(let context):
            return update(context: context, from: core)
        default:
            return false
        }
    }

    /// Updates context of the `KubesenseTracer` if available.
    ///
    /// - Parameter context: The updated core context.
    private func update(context kubesenseContext: KubesenseContext, from core: KubesenseCoreProtocol) -> Bool {
        let rumContext = kubesenseContext.additionalContext(ofType: RUMCoreContext.self)

        _context.mutate {
            $0.applicationStateHistory = kubesenseContext.applicationStateHistory
            $0.rumContext = rumContext
            $0.userInfo = kubesenseContext.userInfo
            $0.accountInfo = kubesenseContext.accountInfo
        }

        samplerProvider.updateWith(deterministicSampler: rumContext?.sessionSampler)

        return true
    }
}
