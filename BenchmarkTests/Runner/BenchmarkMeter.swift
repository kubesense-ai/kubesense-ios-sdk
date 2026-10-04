/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import KubesenseInternal
import KubesenseBenchmarks
import OpenTelemetryApi
import OpenTelemetrySdk

internal final class Meter: KubesenseInternal.BenchmarkMeter {
    let meter: MeterSdk

    init(provider: MeterProviderSdk) {
        self.meter = provider.get(name: "benchmarks")
    }

    func counter(metric: @autoclosure () -> String) -> KubesenseInternal.BenchmarkCounter {
        DoubleCounterWrapper(counter: meter.counterBuilder(name: metric()).ofDoubles().build())
    }

    func gauge(metric: @autoclosure () -> String) -> KubesenseInternal.BenchmarkGauge {
        DoubleGaugeWrapper(gauge: meter.gaugeBuilder(name: metric()).build())
    }

    func observe(metric: @autoclosure () -> String, callback: @escaping (any KubesenseInternal.BenchmarkGauge) -> Void) {
        _ = meter.gaugeBuilder(name: metric()).buildWithCallback { callback(ObservableDoubleMeasurementWrapper(measurement: $0)) }
    }
}

private final class DoubleCounterWrapper: KubesenseInternal.BenchmarkCounter {
    var counter: DoubleCounterSdk

    init(counter: DoubleCounterSdk) {
        self.counter = counter
    }

    func add(value: Double, attributes: @autoclosure () -> [String: String]) {
        counter.add(value: value, attributes: attributes().mapValues { AttributeValue.string($0) })
    }
}

private final class DoubleGaugeWrapper: KubesenseInternal.BenchmarkGauge {
    let gauge: DoubleGaugeSdk

    init(gauge: DoubleGaugeSdk) {
        self.gauge = gauge
    }

    func record(value: Double, attributes: @autoclosure () -> [String: String]) {
        gauge.record(value: value, attributes: attributes().mapValues { AttributeValue.string($0) })
    }
}

private struct ObservableDoubleMeasurementWrapper: KubesenseInternal.BenchmarkGauge {
    let measurement: ObservableMeasurementSdk

    func record(value: Double, attributes: @autoclosure () -> [String: String]) {
        measurement.record(value: value, attributes: attributes().mapValues { AttributeValue.string($0) })
    }
}
