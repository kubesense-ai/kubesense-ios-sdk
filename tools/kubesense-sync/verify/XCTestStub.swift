/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

// Compile-only stand-in for XCTest, used to type-check test targets where XCTest is not installed.
// Never linked or run.
@_exported import Foundation
#if canImport(UIKit)
@_exported import UIKit
#endif

open class XCTest: NSObject {
    open var name: String { "" }
    open func setUp() {}
    open func tearDown() {}
    open func setUpWithError() throws {}
    open func tearDownWithError() throws {}
    open func setUp() async throws {}
    open func tearDown() async throws {}
    open class func setUp() {}
    open class func tearDown() {}
    open var testRunClass: AnyClass? { nil }
    open func run() {}
}

open class XCTestRun: NSObject {
    open var test: XCTest { XCTest() }
    open var hasSucceeded: Bool { true }
    open var failureCount: Int { 0 }
    open var totalFailureCount: Int { 0 }
    open var testCaseCount: Int { 0 }
}

open class XCTestSuite: XCTest {
    open var tests: [XCTest] { [] }
    public init(name: String) {}
    open func addTest(_ test: XCTest) {}
}

open class XCTestExpectation: NSObject {
    public init(description: String) {}
    open var expectationDescription: String = ""
    open var expectedFulfillmentCount: Int = 1
    open var assertForOverFulfill: Bool = true
    open var isInverted: Bool = false
    open func fulfill() {}
}

public struct XCTIssueReference {}

open class XCTAttachment: NSObject {
    public enum Lifetime: Int { case keepAlways, deleteOnSuccess }
    public init(string: String) {}
    public init(data: Data) {}
    public init(data: Data, uniformTypeIdentifier: String) {}
    public init(contentsOfFile url: URL) {}
    open var name: String?
    open var lifetime: Lifetime = .deleteOnSuccess
}

public struct XCTSourceCodeContext { public init() {} }
open class XCTIssue: NSObject {}

public protocol XCTActivity { var name: String { get } ; func add(_ attachment: XCTAttachment) }

public enum XCTContext {
    public static func runActivity<Result>(named name: String, block: (XCTActivity) throws -> Result) rethrows -> Result {
        fatalError()
    }
}

open class XCTestCase: XCTest {
    public override init() { super.init() }
    public init(selector: Selector) { super.init() }
    open var continueAfterFailure: Bool = true
    open var executionTimeAllowance: TimeInterval = 0
    open class var defaultTestSuite: XCTestSuite { XCTestSuite(name: "") }
    open var testRun: XCTestRun? { nil }
    open func invokeTest() {}
    open func record(_ issue: XCTIssue) {}
    open func add(_ attachment: XCTAttachment) {}
    public func expectation(description: String) -> XCTestExpectation { XCTestExpectation(description: description) }
    public func expectation(for predicate: NSPredicate, evaluatedWith object: Any? = nil, handler: (() -> Bool)? = nil) -> XCTestExpectation { XCTestExpectation(description: "") }
    public func expectation(forNotification name: NSNotification.Name, object: Any? = nil, handler: ((Notification) -> Bool)? = nil) -> XCTestExpectation { XCTestExpectation(description: "") }
    public func wait(for expectations: [XCTestExpectation], timeout seconds: TimeInterval = .infinity, enforceOrder: Bool = false) {}
    public func waitForExpectations(timeout: TimeInterval, handler: ((Error?) -> Void)? = nil) {}
    public func fulfillment(of expectations: [XCTestExpectation], timeout seconds: TimeInterval = .infinity, enforceOrder: Bool = false) async {}
    public func addTeardownBlock(_ block: @escaping () -> Void) {}
    public func addTeardownBlock(_ block: @Sendable @escaping () async throws -> Void) {}
    public func measure(_ block: () -> Void) {}
    public func measure(metrics: [XCTMetric], block: () -> Void) {}
    public func measure(metrics: [XCTMetric], options: XCTMeasureOptions, block: () -> Void) {}
    public func keyValueObservingExpectation(for objectToObserve: Any, keyPath: String, expectedValue: Any?) -> XCTestExpectation { XCTestExpectation(description: "") }
}

public protocol XCTMetric {}
public class XCTClockMetric: XCTMetric { public init() {} }
public class XCTMemoryMetric: XCTMetric { public init() {} }
public class XCTCPUMetric: XCTMetric { public init() {} }
open class XCTMeasureOptions: NSObject { open var iterationCount: Int = 5 ; open class var `default`: XCTMeasureOptions { XCTMeasureOptions() } }

open class XCTWaiter: NSObject {
    public enum Result: Int { case completed = 1, timedOut, incorrectOrder, invertedFulfillment, interrupted }
    public override init() {}
    open class func wait(for expectations: [XCTestExpectation], timeout seconds: TimeInterval = .infinity, enforceOrder: Bool = false) -> Result { .completed }
    open func wait(for expectations: [XCTestExpectation], timeout seconds: TimeInterval = .infinity, enforceOrder: Bool = false) -> Result { .completed }
    open class func fulfillment(of expectations: [XCTestExpectation], timeout seconds: TimeInterval = .infinity, enforceOrder: Bool = false) async -> Result { .completed }
}

public protocol XCTestObservation: NSObjectProtocol {}
extension XCTestObservation {
    public func testBundleWillStart(_ testBundle: Bundle) {}
    public func testBundleDidFinish(_ testBundle: Bundle) {}
    public func testCaseWillStart(_ testCase: XCTestCase) {}
    public func testCaseDidFinish(_ testCase: XCTestCase) {}
    public func testSuiteWillStart(_ testSuite: XCTestSuite) {}
    public func testSuiteDidFinish(_ testSuite: XCTestSuite) {}
}
open class XCTestObservationCenter: NSObject {
    open class var shared: XCTestObservationCenter { XCTestObservationCenter() }
    open func addTestObserver(_ observer: XCTestObservation) {}
    open func removeTestObserver(_ observer: XCTestObservation) {}
}

public struct XCTSkip: Error {
    public init(_ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) {}
}
public func XCTSkipIf(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {}
public func XCTSkipUnless(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {}

public func XCTFail(_ message: String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssert(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertEqual<T: Numeric>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotEqual<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotEqual<T: FloatingPoint>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, accuracy: T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertGreaterThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertGreaterThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertLessThan<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertLessThanOrEqual<T: Comparable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) {}
public func XCTAssertThrowsError<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (_ error: Error) -> Void = { _ in }) async {}
public func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertIdentical(_ expression1: @autoclosure () throws -> AnyObject?, _ expression2: @autoclosure () throws -> AnyObject?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTAssertNotIdentical(_ expression1: @autoclosure () throws -> AnyObject?, _ expression2: @autoclosure () throws -> AnyObject?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {}
public func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) throws -> T { fatalError() }
public func XCTExpectFailure(_ failureReason: String? = nil, strict: Bool = true, failingBlock: () throws -> Void) rethrows {}

extension XCTestCase: @unchecked Sendable {}
extension XCTestExpectation: @unchecked Sendable {}
