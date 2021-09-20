//
//  He3Tests.swift
//  He3Tests
//
//  Created by Carlos D. Santiago on 4/21/20.
//  Copyright © 2020-2021 CD M Santiago. All rights reserved.
//

import XCTest

@testable import Down

fileprivate var appDelegate : AppDelegate {
    get {
        return NSApp.delegate as! AppDelegate
    }
}

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}

struct CastingError: Error {
    let fromType: Any.Type
    let toType: Any.Type
	
    init<FromType, ToType>(fromType: FromType.Type, toType: ToType.Type) {
        self.fromType = fromType
        self.toType = toType
    }
}

extension CastingError: LocalizedError {
    var localizedDescription: String { return "Can not cast from \(fromType) to \(toType)" }
}

extension CastingError: CustomStringConvertible {
	var description: String { return localizedDescription } }

// MARK: - Data cast extensions

extension Data {
    func toDictionary(options: JSONSerialization.ReadingOptions = []) throws -> [String: Any] {
        return try to(type: [String: Any].self, options: options)
    }

    func to<T>(type: T.Type, options: JSONSerialization.ReadingOptions = []) throws -> T {
        guard let result = try JSONSerialization.jsonObject(with: self, options: options) as? T else {
            throw CastingError(fromType: type, toType: T.self)
        }
        return result
    }
}

// MARK: - String cast extensions

extension String {
    func asJSON<T>(to type: T.Type, using encoding: String.Encoding = .utf8) throws -> T {
        guard let data = data(using: encoding) else { throw CastingError(fromType: type, toType: T.self) }
        return try data.to(type: T.self)
    }

    func asJSONToDictionary(using encoding: String.Encoding = .utf8) throws -> [String: Any] {
        return try asJSON(to: [String: Any].self, using: encoding)
    }
}

// MARK: - Dictionary cast extensions

extension Dictionary {
    func toData(options: JSONSerialization.WritingOptions = []) throws -> Data {
        return try JSONSerialization.data(withJSONObject: self, options: options)
    }
}

class He3Tests: XCTestCase {
	
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
		super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
    }

    func testPlayListUTI() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		var playlistTypeUTI : AnyObject?
		let playlistFileURL = URL.init(fileURLWithPath: "/Users/slashlos/GitHub/He3/He3/He3Tests/PlayList.hpl")
		do {
			try (playlistFileURL as NSURL).getResourceValue(&playlistTypeUTI, forKey: URLResourceKey.typeIdentifierKey)
			print("playlistTypeUTI \(String(describing: playlistTypeUTI))")
			let playlistUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, playlistFileURL.pathExtension as CFString, nil)
			print("testUTI \(String(describing: playlistUTI))")
		}
		catch let error {
			print("\(error.localizedDescription)")
		}
	
    }

    func testPlayItemUTI() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
		var playitemTypeUTI : AnyObject?
		let playitemFileURL = URL.init(fileURLWithPath: "/Users/slashlos/GitHub/He3/He3/He3Tests/PlayItem.hpi")
		do {
			try (playitemFileURL as NSURL).getResourceValue(&playitemTypeUTI, forKey: URLResourceKey.typeIdentifierKey)
			print("playitemTypeUTI \(String(describing: playitemTypeUTI))")
			let playitemUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, playitemFileURL.pathExtension as CFString, nil)
			print("testUTI \(String(describing: playitemUTI))")
		}
		catch let error {
			print("\(error.localizedDescription)")
		}
	
    }
	
	func testPlayLists() {
        var aDicts = [Dictionary<String,Any>]()
		let t_playlist = "testPlayLists"
        
		aDicts.append(PlayItem().dictionary())
		aDicts.append(PlayItem().dictionary())
		aDicts.append(PlayItem().dictionary())
		aDicts.append(PlayItem().dictionary())
       
        defaults.set(aDicts, forKey: t_playlist)

		//	show read back our 5; code from restorePlaylist()
		let rewind = appDelegate.restorePlaylist(t_playlist)
		print("\(rewind) returned")
	}
	
	func testDescriber(text: String, value: Any) {
		print("\n//////////////////////////////////////////")
		print("-- \(text)\n\n  type: \(type(of: value))\n  value: \(value)")
	}

	func testCastings() {
		let json1: [String: Any] = ["key1" : 1, "key2": true, "key3" : ["a": 1, "b": 2], "key4": [1,2,3]]
		let jsonData = try? json1.toData()
		testDescriber(text: "Sample test of func toDictionary()", value: json1)
		if let data = jsonData {
			print("  Result: \(String(describing: try? data.toDictionary()))")
		}

		testDescriber(text: "Sample test of func to<T>() -> [String: Any]", value: json1)
		if let data = jsonData {
			print("  Result: \(String(describing: try? data.to(type: [String: Any].self)))")
		}

		testDescriber(text: "Sample test of func to<T>() -> [String] with cast error", value: json1)
		if let data = jsonData {
			do {
				print("  Result: \(String(describing: try data.to(type: [String].self)))")
			} catch {
				print("  ERROR: \(error)")
			}
		}

		let array = [1,4,5,6]
		testDescriber(text: "Sample test of func to<T>() -> [Int]", value: array)
		if let data = try? JSONSerialization.data(withJSONObject: array) {
			print("  Result: \(String(describing: try? data.to(type: [Int].self)))")
		}

		let json2 = ["key1": "a", "key2": "b"]
		testDescriber(text: "Sample test of func to<T>() -> [String: String]", value: json2)
		if let data = try? JSONSerialization.data(withJSONObject: json2) {
			print("  Result: \(String(describing: try? data.to(type: [String: String].self)))")
		}

		let jsonString = "{\"key1\": \"a\", \"key2\": \"b\"}"
		testDescriber(text: "Sample test of func to<T>() -> [String: String]", value: jsonString)
		print("  Result: \(String(describing: try? jsonString.asJSON(to: [String: String].self)))")

		testDescriber(text: "Sample test of func to<T>() -> [String: String]", value: jsonString)
		print("  Result: \(String(describing: try? jsonString.asJSONToDictionary()))")

		let wrongJsonString = "{\"key1\": \"a\", \"key2\":}"
		testDescriber(text: "Sample test of func to<T>() -> [String: String] with JSONSerialization error", value: jsonString)
		do {
			let json = try wrongJsonString.asJSON(to: [String: String].self)
			print("  Result: \(String(describing: json))")
		} catch {
			print("  ERROR: \(error)")
		}
	}
	
    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
