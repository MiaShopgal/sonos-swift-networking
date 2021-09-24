//
//  File.swift
//
//
//  Created by James Hickman on 2/26/21.
//

import XCTest
@testable import SonosNetworking
@testable import Alamofire
@testable import Mocker

final class FavoritesLoadNetworkTests: XCTestCase {
    private var subject: FavoritesLoadNetwork!
    private var completionExpectation: XCTestExpectation?

    private var didSucceed = false
    private var didFail = false
    private var responseData: Data?
    private var responseError: Error?

    static var allTests = [
        ("testHTTPMethod", testHTTPMethod),
        ("testEncoding", testEncoding),
        ("testPreparedUrl", testPreparedUrl),
        ("testHeaders", testHeaders),
        ("testParameters", testParameters),
        ("testSuccess", testSuccess),
        ("testFailure", testFailure),
    ]
    
    override func setUp() {
        subject = FavoritesLoadNetwork(accessToken: MockedData.accessToken,
                                       groupId: MockedData.groupId,
                                       action: MockedData.action,
                                       favoriteId: MockedData.favoriteId,
                                       playOnCompletion: MockedData.playOnCompletion,
                                       playModes: MockedData.playModes,
                                       success: { [weak self] data in
                                        self?.didSucceed = true
                                        self?.responseData = data
                                        self?.completionExpectation?.fulfill()
                                    },
                                       failure: { [weak self] error in
                                        self?.didFail = true
                                        self?.responseError = error
                                        self?.completionExpectation?.fulfill()
                                    })
        
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        subject.session = Alamofire.Session(configuration: configuration)
    }
    
    override func tearDown() {
        subject = nil
        completionExpectation = nil
        responseData = nil
        responseError = nil
    }
    
    func testHTTPMethod() {
        XCTAssertEqual(subject.HTTPMethod(), MockedData.expectedHTTPMethod)
    }
    
    func testEncoding() {
        XCTAssertNotNil(subject.encoding() as? JSONEncoding)
    }
    
    func testPreparedUrl() {
        XCTAssertEqual(try subject.preparedURL().asURL(), try MockedData.expectedPreparedUrl.asURL())
    }
    
    func testHeaders() {
        XCTAssertEqual(subject.headers()?.dictionary, MockedData.expectedHeaders.dictionary)
    }
    
    func testParameters() {
        XCTAssertEqual(subject.parameters()?.keys, MockedData.expectedParameters.keys)
        XCTAssertEqual(subject.parameters()?.count, MockedData.expectedParameters.count)
    }
    
    func testSuccess() {
        XCTAssertFalse(didSucceed)
        do {
            let url = try subject.preparedURL().asURL()
            let mockedData = try JSONSerialization.data(withJSONObject: MockedData.expectedResults, options: [])
            let mock = Mock(url: url, dataType: .json, statusCode: 200, data: [.post: mockedData])
            mock.register()

            let completionExpectation = expectation(description: "Request should succeed.")
            self.completionExpectation = completionExpectation

            subject.performRequest()
            wait(for: [completionExpectation], timeout: 1.0)
            XCTAssertTrue(self.didSucceed)
            guard let responseData = self.responseData else {
                assertionFailure("Response data should not be nil.")
                return
            }
            XCTAssertEqual(mockedData, responseData)
        } catch let error {
            assertionFailure("Failed to create URL from provided string: \(error.localizedDescription)")
        }
    }

    func testFailure() {
        XCTAssertFalse(didFail)
        do {
            let url = try subject.preparedURL().asURL()
            let error = AFError.ServerTrustFailureReason.noPublicKeysFound.underlyingError
            let mock = Mock(url: url, dataType: .json, statusCode: 400, data: [.post: Data()], requestError: error)
            mock.register()

            let completionExpectation = expectation(description: "Request should fail.")
            self.completionExpectation = completionExpectation

            subject.performRequest()
            wait(for: [completionExpectation], timeout: 1.0)
            XCTAssertTrue(didFail)
        } catch let error {
            assertionFailure("Failed to create URL from provided string: \(error.localizedDescription)")
        }
    }
    
}

fileprivate final class MockedData {
    
    public static let accessToken: String = "accessToken"
    public static let groupId: String = "groupId"
    public static let action: String = "action"
    public static let favoriteId: String = "favoriteId"
    public static let playOnCompletion: Bool = true
    public static let playModes: [String] = ["playMode1", "playMode2"]

    public static let expectedHTTPMethod: HTTPMethod = .post
    public static let expectedEncoding: ParameterEncoding = JSONEncoding.default
    public static let expectedPreparedUrl: URLConvertible = "https://api.ws.sonos.com/control/api/v1/groups/\(groupId)/favorites"
    public static let expectedHeaders: HTTPHeaders = [
        HTTPHeader(name: "Content-Type", value: "application/json"),
        HTTPHeader(name: "Authorization", value: "Bearer \(accessToken)")
    ]
    public static let expectedParameters: Parameters = [
        "action": action,
        "favoriteId": favoriteId,
        "playOnCompletion": playOnCompletion,
        "playModes": playModes
    ]
    public static let expectedResults: [String: Any] = [
        "namespace": "favorites",
        "response": "loadFavorite",
        "success": true,
        "type": "none",
        "householdId": "HHID_4231",
        "groupId": "XYZ-123abc456:12"
    ]

}
