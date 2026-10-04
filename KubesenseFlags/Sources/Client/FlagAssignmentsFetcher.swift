/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal

internal protocol FlagAssignmentsFetching {
    func flagAssignments(
        for evaluationContext: FlagsEvaluationContext,
        completion: @escaping (Result<[String: FlagAssignment], FlagsError>) -> Void
    )
}

internal final class FlagAssignmentsFetcher: FlagAssignmentsFetching {
    let customEndpoint: URL?
    let customHeaders: [String: String]?

    private let featureScope: any FeatureScope
    private let fetch: (URLRequest, @escaping (Result<Data, Error>) -> Void) -> Void

    private static let decoder = JSONDecoder()

    convenience init(
        customEndpoint: URL?,
        customHeaders: [String: String]?,
        featureScope: any FeatureScope
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil

        let urlSession = URLSession(configuration: configuration)

        self.init(
            customEndpoint: customEndpoint,
            customHeaders: customHeaders,
            featureScope: featureScope,
            fetch: urlSession.fetch
        )
    }

    init(
        customEndpoint: URL?,
        customHeaders: [String: String]?,
        featureScope: any FeatureScope,
        fetch: @escaping (URLRequest, @escaping (Result<Data, Error>) -> Void) -> Void
    ) {
        self.customEndpoint = customEndpoint
        self.customHeaders = customHeaders
        self.featureScope = featureScope
        self.fetch = fetch
    }

    func flagAssignments(
        for evaluationContext: FlagsEvaluationContext,
        completion: @escaping (Result<[String: FlagAssignment], FlagsError>) -> Void
    ) {
        featureScope.context { [weak self] context in
            guard let self else {
                completion(.failure(.clientNotInitialized))
                return
            }
            do {
                let request = try URLRequest.flagAssignmentsRequest(
                    url: self.url(with: context),
                    evaluationContext: evaluationContext,
                    context: context,
                    customHeaders: self.customHeaders
                )
                self.fetch(request) { [featureScope] result in
                    switch result {
                    case .success(let data):
                        do {
                            let response = try Self.decoder.decode(FlagAssignmentsResponse.self, from: data)

                            // Log any flags that failed to decode to telemetry
                            if !response.failedFlags.isEmpty {
                                for (flagKey, errorDescription) in response.failedFlags {
                                    let error = InternalError(description: errorDescription)
                                    DD.logger.warn(
                                        "Failed to decode flag '\(flagKey)' from flag assignments response. Flag will be dropped from configuration.",
                                        error: error
                                    )
                                    featureScope.telemetry.debug(
                                        "Failed to decode flag '\(flagKey)' from flag assignments response",
                                        attributes: [
                                            "flagKey": flagKey,
                                            "errorDescription": errorDescription
                                        ]
                                    )
                                }
                            }

                            completion(.success(response.flags))
                        } catch {
                            featureScope.telemetry.error(
                                "Failed to decode \(FlagAssignmentsResponse.self) from flag assignments response",
                                error: error
                            )
                            completion(.failure(.invalidResponse))
                        }
                    case .failure(let error):
                        DD.logger.error("Failed to fetch flag assignments from the server.", error: error)
                        featureScope.telemetry.error("Failed to fetch flag assignments from the server", error: error)
                        completion(.failure(.networkError(error)))
                    }
                }
            } catch let error {
                DD.logger.error("Failed to encode flag assignments request body.", error: error)
                featureScope.telemetry.error("Failed to encode flag assignments request body.", error: error)
                completion(.failure(.invalidConfiguration))
            }
        }
    }

    private func url(with context: KubesenseContext) -> URL {
        // The Kubesense collector route for flag assignments, on the core-level collector endpoint.
        customEndpoint ?? context.intakeEndpoint.appendingPathComponent("precompute-assignments")
    }
}

extension URLSession {
    fileprivate func fetch(
        _ request: URLRequest,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let task = self.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard
                let data,
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode
            else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            completion(.success(data))
        }
        task.resume()
    }
}
