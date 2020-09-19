//
//  StringHelpers.swift
//  He3 (Helium 3)
//
//  Created by Samuel Beek on 16/03/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//  Copyright © 2017-2019 CD M Santiago. All rights reserved.
//

import Foundation
import Down
import CoreAudioKit

extension String {
    func replacePrefix(_ prefix: String, replacement: String) -> String {
        if hasPrefix(prefix) {
            return replacement + suffix(from: prefix.endIndex)
        }
        else {
            return self
        }
    }
    
    func indexOf(_ target: String) -> Int {
        let range = self.range(of: target)
        if let range = range {
            return self.distance(from: self.startIndex, to: range.lowerBound)
        } else {
            return -1
        }
    }

    func isValidURL() -> Bool {
        guard let urlComponents = URLComponents.init(string: self), urlComponents.host != nil, urlComponents.url != nil else { return false }
        
        return true
        ///let urlRegEx = "((afp:file|https|http|smb)()://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
        ///let predicate = NSPredicate(format:"SELF MATCHES %@", argumentArray:[urlRegEx])
        
        ///return predicate.evaluate(with: self)
    }
}

// From http://nshipster.com/nsregularexpression/
extension String {
    /// An `NSRange` that represents the full range of the string.
    var nsrange: NSRange {
        return NSRange(location: 0, length: utf16.count)
    }
    
    /// Returns a substring with the given `NSRange`,
    /// or `nil` if the range can't be converted.
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self)
            else { return nil }
        return self[range]
    }
    
    /// Returns a range equivalent to the given `NSRange`,
    /// or `nil` if the range can't be converted.
    func range(from nsrange: NSRange) -> Range<String.Index>? {
        return Range(nsrange, in: self)
    }
}

extension String {
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
}

// From https://stackoverflow.com/questions/45562662/how-can-i-use-string-slicing-subscripts-in-swift-4
extension String {
    subscript(value: NSRange) -> Substring {
        return self[value.lowerBound..<value.upperBound]
    }
}

extension String {
    subscript(value: CountableClosedRange<Int>) -> Substring {
        get {
            return self[index(at: value.lowerBound)...index(at: value.upperBound)]
        }
    }
    
    subscript(value: CountableRange<Int>) -> Substring {
        get {
            return self[index(at: value.lowerBound)..<index(at: value.upperBound)]
        }
    }
    
    subscript(value: PartialRangeUpTo<Int>) -> Substring {
        get {
            return self[..<index(at: value.upperBound)]
        }
    }
    
    subscript(value: PartialRangeThrough<Int>) -> Substring {
        get {
            return self[...index(at: value.upperBound)]
        }
    }
    
    subscript(value: PartialRangeFrom<Int>) -> Substring {
        get {
            return self[index(at: value.lowerBound)...]
        }
    }
    
    func index(at offset: Int) -> String.Index {
        return index(startIndex, offsetBy: offset)
    }
}

extension NSString {
    class func string(fromAsset: String) -> String {
        let asset = NSDataAsset.init(name: fromAsset)
        let data = NSData.init(data: (asset?.data)!)
        let text = String.init(data: data as Data, encoding: String.Encoding.utf8)
        
		if fromAsset.hasSuffix(".md"), let html = try? Down(markdownString: text!).toHTML()
		{
			let htmlDoc = String(format: "<html><body>%@</body></html>", html)
			let data = Data(htmlDoc.utf8)
			if let attrs = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
				return attrs.string
			}
		}
		return text!
    }
}

extension NSAttributedString {
    class func string(fromAsset: String) -> NSAttributedString {
        let asset = NSDataAsset.init(name: fromAsset)
        let data = NSData.init(data: (asset?.data)!)
        var text : NSAttributedString
        do {
            text = try NSAttributedString.init(data: data as Data, options:[NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            return text
        } catch {
            let chars = String.init(data: data as Data, encoding: String.Encoding.utf8)!
			if fromAsset.hasSuffix(".md"), let html = try? Down(markdownString: chars).toHTML()
			{
				let htmlDoc = String(format: "<html><body>%@</body></html>", html)
				let data = Data(htmlDoc.utf8)
				if let attrs = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
					return attrs
				}
			}
			return NSAttributedString.init(string: chars)
        }
    }
}

extension String {
    static func prettyStamp() -> String {
        let dateFMT = DateFormatter()
        dateFMT.locale = .current
        dateFMT.dateFormat = "YYYY'-'MM'-'dd 'at' HH.mm.ss"
        let now = Date()

        return String(format: "%@", dateFMT.string(from: now))
    }
    
    static func timestamp() -> String {
        let dateFMT = DateFormatter()
        dateFMT.locale = Locale(identifier: "en_US_POSIX")
        dateFMT.dateFormat = "yyyyMMdd'T'HHmmss.SSSS"
        let now = Date()

        return String(format: "%@", dateFMT.string(from: now))
    }

    func tad2Date() -> Date? {
        let dateFMT = DateFormatter()
        dateFMT.locale = Locale(identifier: "en_US_POSIX")
        dateFMT.dateFormat = "yyyyMMdd'T'HHmmss.SSSS"
        
        return dateFMT.date(from: self)
    }
}

//  https://codereview.stackexchange.com/questions/135424/hex-string-to-bytes-nsdata?newreg=06dfe1d5b9964b928631538c9e48d421
extension String {
    func dataFromHexString() -> Data? {

        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }

        let utf16 = self.utf16
        guard let data = NSMutableData(capacity: utf16.count/2) else { return nil }

        var i = utf16.startIndex
        while i != utf16.endIndex {
            guard
                let hi = decodeNibble(u: utf16[i]),
                let lo = decodeNibble(u: utf16[index(i, offsetBy: 1, limitedBy: utf16.endIndex)!])
            else {
                return nil
            }
            var value = hi << 4 + lo
            data.append(&value, length: 1)
            i = index(i, offsetBy: 2, limitedBy: utf16.endIndex)!
        }
        return data as Data
    }
}

extension String {
    var webloc : URL? {
        get {
            if let url = URL.init(string: self) {
                return url
            }
            else
            if let dict : Dictionary = self.propertyList() as? [String:Any] {
                let urlString = dict["URL"] as! String
                if let url = URL.init(string: urlString) {
                    return url
                }
            }
            return nil
        }
    }
}
