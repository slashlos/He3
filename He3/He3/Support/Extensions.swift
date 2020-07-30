//
//  Extensions.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/6/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
import Cocoa
///import CommonCrypto

// From https://stackoverflow.com/questions/12837965/converting-nsdictionary-to-xml
/*
extension Any {
    func xmlString() -> String {
        if let booleanValue = (self as? Bool) {
            return String(format: (booleanValue ? "true" : "false"))
        }
        else
        if let intValue = (self as? Int) {
            return String(format: "%d", intValue)
        }
        else
        if let floatValue = (self as? Float) {
            return String(format: "%f", floatValue)
        }
        else
        if let doubleValue = (self as? Double) {
            return String(format: "%f", doubleValue)
        }
        else
        {
            return String(format: "<%@>", self)
        }
    }
}
*/
extension Array {
    func xmlString(withElement element: String, isFirstElemenet: Bool) -> String {
        var xml = String.init()

        xml.append(String(format: "<%@>\n", element))
        self.forEach { (value) in
            if let array: Array<Any> = (value as? Array<Any>) {
                xml.append(array.xmlString(withElement: "Array", isFirstElemenet: false))
            }
            else
            if let dict: Dictionary<AnyHashable,Any> = (value as? Dictionary<AnyHashable,Any>) {
                xml.append(dict.xmlString(withElement: "Dictionary", isFirstElement: false))
            }
            else
            {/*
                if let booleanValue = (value as? Bool) {
                    xml.append(String(format: (booleanValue ? "true" : "false")))
                }
                else
                if let intValue = (value as? Int) {
                    xml.append(String(format: "%d", intValue))
                }
                else
                if let floatValue = (value as? Float) {
                    xml.append(String(format: "%f", floatValue))
                }
                else
                if let doubleValue = (value as? Double) {
                    xml.append(String(format: "%f", doubleValue))
                }
                else
                {
                    xml.append(String(format: "<%@>", value as! CVarArg))
                }*/
                Swift.print("value: \(value)")
                xml.append(toLiteral(value))
            }
        }
        xml.append(String(format: "<%@>\n", element))

        return xml
    }
}

// From https://stackoverflow.com/questions/27624331/unique-values-of-array-in-swift
extension Array where Element : Hashable {
    var unique: [Element] {
        return Array(Set(self))
    }
}

extension Array where Element:PlayList {
    func has(_ name: String) -> Bool {
        return self.name(name) != nil
    }
    func name(_ name: String) -> PlayList? {
        for play in self {
            if play.name == name {
                return play
            }
        }
        return nil
    }
    func list(_ name: String) -> [PlayList] {
        var list = [PlayList]()
        for play in self {
            if play.name == name {
                list.append(play)
            }
        }
        return list
    }
}

extension Array where Element:PlayItem {
    func has(_ name: String) -> Bool {
        return self.item(name) != nil
    }
    func item(_ name: String) -> PlayItem? {
        for item in self {
            if item.name == name {
                return item
            }
        }
        return nil
    }
    func link(_ urlString: String) -> PlayItem? {
        for item in self {
            if item.link.absoluteString == urlString {
                return item
            }
        }
        return nil
    }
}

extension CGRect {
	init(for cgString: String) {
		let r = NSRectFromString(cgString)
		self.init(x: r.origin.x, y: r.origin.y, width: r.size.width, height: r.size.height)
	}
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

//  https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex-string-in-swift
extension Data {
    private static let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }

    public func hexEncodedString() -> String {
        return String(self.reduce(into: "".unicodeScalars, { (result, value) in
            result.append(Data.hexAlphabet[Int(value/16)])
            result.append(Data.hexAlphabet[Int(value%16)])
        }))
    }
}
/*
extension Data {
    // https://forums.swift.org/t/cryptokit-sha256-much-much-slower-than-cryptoswift/27983/12
    static func sha256(data: Data) -> Data {
        var buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(CC_SHA256_DIGEST_LENGTH), alignment: 8)
        var buffer2 = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CC_SHA256_DIGEST_LENGTH))
        defer {
            buffer.deallocate()
            buffer2.deallocate()
        }
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> () in
            CC_SHA256(ptr.baseAddress!, CC_LONG(data.count), buffer.assumingMemoryBound(to: UInt8.self))
        }
        CC_SHA256(buffer, CC_LONG(CC_SHA256_DIGEST_LENGTH), buffer2)
        return Data(buffer: UnsafeBufferPointer(start: buffer2, count: Int(CC_SHA256_DIGEST_LENGTH)))
    }
}
*/
//https://stackoverflow.com/questions/21789770/determine-mime-type-from-nsdata
extension Data {
    private static let mimeTypeSignatures: [UInt8 : String] = [
        0xFF : "image/jpeg",
        0x89 : "image/png",
        0x47 : "image/gif",
        0x49 : "image/tiff",
        0x4D : "image/tiff",
        0x25 : "application/pdf",
        0xD0 : "application/vnd",
        0x46 : "text/plain",
        ]

    var mimeType: String {
        var c: UInt8 = 0
        copyBytes(to: &c, count: 1)
        return Data.mimeTypeSignatures[c] ?? "application/octet-stream"
    }
}

extension Dictionary {
    //  Return an XML string from the dictionary
    func xmlString(withElement element: String, isFirstElement: Bool) -> String {
        var xml = String.init()
        
        if isFirstElement { xml.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n") }
        
        xml.append(String(format: "<%@>\n", element))
        for node in self.keys {
            let value = self[node]
            
            if let array: Array<Any> = (value as? Array<Any>) {
                xml.append(array.xmlString(withElement: node as! String, isFirstElemenet: false))
            }
            else
            if let dict: Dictionary<AnyHashable,Any> = (value as? Dictionary<AnyHashable,Any>) {
                xml.append(dict.xmlString(withElement: node as! String, isFirstElement: false))
            }
            else
            {
                xml.append(String(format: "<%@>", node as! CVarArg))
                xml.append(toLiteral(value as Any))
                xml.append(String(format: "</%@>\n", node as! CVarArg))
            }
        }
                
        xml.append(String(format: "</%@>\n", element))

        return xml
    }
    func xmlHTMLString(withElement element: String, isFirstElement: Bool) -> String {
        let xml = self.xmlString(withElement: element, isFirstElement: isFirstElement)
        
        return xml.replacingOccurrences(of: "&", with: "&amp", options: .literal, range: nil)
    }
}

extension NSImage {
    
	func resize(size: NSSize) -> NSImage {
		let newImage = NSImage(size: size)
		newImage.lockFocus()
		self.draw(in: NSMakeRect(0, 0, size.width, size.height),
				  from: NSMakeRect(0, 0, self.size.width, self.size.height),
				  operation: .sourceOver,
				  fraction: CGFloat(1))
		newImage.unlockFocus()
		newImage.size = size
		return NSImage(data: newImage.tiffRepresentation!)!

	}
	func resize(w: CGFloat, h: CGFloat) -> NSImage {
		return self.resize(size: NSMakeSize(w, h))
	}
    func resize(w: Int, h: Int) -> NSImage {
		return resize(w: CGFloat(w), h: CGFloat(h))
    }
}

extension NSObject {
    func kvoTooltips(_ keyPaths : [String]) {
        for keyPath in (keyPaths)
        {
            self.willChangeValue(forKey: keyPath)
        }
        
        for keyPath in (keyPaths)
        {
            self.didChangeValue(forKey: keyPath)
        }
    }
}

extension NSUserInterfaceItemIdentifier {
	static let link = NSUserInterfaceItemIdentifier(rawValue: "link")
	static let playlists = NSUserInterfaceItemIdentifier(rawValue: "Playlists")
}

extension NSView {
    func fit(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: parentView.bottomAnchor).isActive = true
    }
    func center(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
        self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
    }
    func vCenter(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
    }
    func top(_ parentView: NSView) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        self.leadingAnchor.constraint(equalTo: parentView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: parentView.trailingAnchor).isActive = true
    }
}

extension NSView {
	var snapshot : NSImage? {
		get {
			guard let window = self.window, let content = window.contentView else { return nil }

			var rect = content.bounds
			rect = content.convert(rect, to: nil)
			rect = window.convertToScreen(rect)

			//  Adjust for titlebar; kTitleUtility = 16, kTitleNormal = 22
			let delta : CGFloat = CGFloat((window.styleMask.contains(.utilityWindow) ? kTitleUtility : kTitleNormal))
			rect.origin.y += delta
			rect.size.height += delta*2

			guard let cgImage = CGWindowListCreateImage(rect, .optionIncludingWindow, CGWindowID(window.windowNumber), .bestResolution) else { return nil }
			let image = NSImage(cgImage: cgImage, size: rect.size)

			return image
		}
	}
}

// From https://stackoverflow.com/questions/31093678/how-to-get-rid-of-array-brackets-while-printing/31093744#31093744
extension Sequence {
    var list: String {
        return map { "\($0)" }.joined(separator: ", ")
    }
    var listing: String {
        return map { "\($0)" }.joined(separator: "\n")
    }
}

struct UAHelpers {
    static func isValidUA(uaString: String) -> Bool {
        // From https://stackoverflow.com/questions/20569000/regex-for-http-user-agent
        let regex = try! NSRegularExpression(pattern: ".+?[/\\s][\\d.]+")
        return (regex.firstMatch(in: uaString, range: uaString.nsrange) != nil)
    }
}

extension NSViewController {
    func modalOKCancel(_ message: String, info: String?) -> Bool {
        let alert: NSAlert = NSAlert()
        alert.messageText = message
        if info != nil {
            alert.informativeText = info!
        }
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
            return true
        default:
            return false
        }
    }

    func sheetOKCancel(_ message: String, info: String?,
                       acceptHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                acceptHandler(response)
            })
        }
        else
        {
            acceptHandler(alert.runModal())
        }
        alert.buttons.first!.becomeFirstResponder()
    }
    
    func userAlertMessage(_ message: String, info: String?) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                return
            })
        }
        else
        {
            alert.runModal()
            return
        }
    }
	
    func userConfirmMessage(_ message: String, info: String?) -> Bool {
        let alert = NSAlert()
        var ok = false
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                ok = response == NSApplication.ModalResponse.alertFirstButtonReturn
            })
        }
        else
        {
            ok = alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
        }
        return ok
    }
	
    public func userTextInput(_ prompt: String, defaultText: String?) -> String? {
        var text : String? = nil

        // Create alert
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = prompt
        
        // Create urlField
        let textField = URLField(withValue: defaultText, modalTitle: title)
        textField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        alert.accessoryView = textField

        // Add urlField and buttons to alert
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let keyWindow = NSApp.keyWindow {
            if let hpc = keyWindow.windowController as? HeliumController {
                textField.borderColor = hpc.homeColor
            }
            alert.beginSheetModal(for: keyWindow, completionHandler: { response in
                // buttons are accept, cancel, default
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // swiftlint:disable:next force_cast
                    text = (alert.accessoryView as! NSTextField).stringValue
                 }
            })
        }
        else
        {
            //  No window, so load panel modally
            NSApp.activate(ignoringOtherApps: true)

            if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                text = (alert.accessoryView as! NSTextField).stringValue
            }
        }
        // Set focus on urlField
        alert.accessoryView!.becomeFirstResponder()
        
        return text
    }
}

// MARK: - CastingError
// https://stackoverflow.com/a/57577620/564870
/*
	let value1 = try? data.toDictionary()
	let value2 = try? data.to(type: [String: Any].self)
	let value3 = try? data.to(type: [String: String].self)
	let value4 = try? string.asJSONToDictionary()
	let value5 = try? string.asJSON(to: [String: String].self)
*/

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

// MARK:- Functions

//  Create a file Handle or url for writing to a new file located in the directory specified by 'dirpath'.
//  If the file basename.extension already exists at that location, then append "-N" (where N is a whole
//  number starting with 1) until a unique basename-N.extension file is found.  On return oFilename
//  contains the name of the newly created file referenced by the returned NSFileHandle (autoreleased).
func NewFileHandleForWriting(path: String, name: String, type: String, outFile: inout String?) -> FileHandle? {
    let fm = FileManager.default
    var file: String? = nil
    var fileURL: URL? = nil
    var uniqueNum = 0
    
    do {
        while true {
            let tag = (uniqueNum > 0 ? String(format: "-%d", uniqueNum) : "")
            let unique = String(format: "%@%@.%@", name, tag, type)
            file = String(format: "%@/%@", path, unique)
            fileURL = URL.init(fileURLWithPath: file!)
            if false == ((((try? fileURL?.checkResourceIsReachable()) as Bool??)) ?? false) { break }
            
            // Try another tag.
            uniqueNum += 1;
        }
        outFile = file!
        
        if fm.createFile(atPath: file!, contents: nil, attributes: [FileAttributeKey(rawValue: FileAttributeKey.extensionHidden.rawValue): true]) {
            let fileHandle = try FileHandle.init(forWritingTo: fileURL!)
            print("\(file!) was opened for writing")
            return fileHandle
        } else {
            return nil
        }
    } catch let error {
        NSApp.presentError(error)
        return nil;
    }
}

func NewFileURLForWriting(path: String, name: String, type: String) -> URL? {
    let fm = FileManager.default
    var file: String? = nil
    var fileURL: URL? = nil
    var uniqueNum = 0
    
    while true {
        let tag = (uniqueNum > 0 ? String(format: "-%d", uniqueNum) : "")
        let unique = String(format: "%@%@.%@", name, tag, type)
        file = String(format: "%@/%@", path, unique)
        fileURL = URL.init(fileURLWithPath: file!)
        if false == ((((try? fileURL?.checkResourceIsReachable()) as Bool??)) ?? false) { break }
        
        // Try another tag.
        uniqueNum += 1;
    }
    
    if fm.createFile(atPath: file!, contents: nil, attributes: [FileAttributeKey(rawValue: FileAttributeKey.extensionHidden.rawValue): true]) {
        return fileURL
    } else {
        return nil
    }
}

func toLiteral(_ value: Any) -> String {
    if let booleanValue = (value as? Bool) {
        return String(format: (booleanValue ? "1" : "0"))
    }
    else
    if let intValue = (value as? Int) {
        return String(format: "%d", intValue)
    }
    else
    if let floatValue = (value as? Float) {
        return String(format: "%f", floatValue)
    }
    else
    if let doubleValue = (value as? Double) {
        return String(format: "%f", doubleValue)
    }
    else
    if let stringValue = (value as? String) {
        return stringValue
    }
    else
    if let dictValue: Dictionary<AnyHashable,Any> = (value as? Dictionary<AnyHashable,Any>)
    {
        return dictValue.xmlString(withElement: "Dictionary", isFirstElement: false)
    }
    else
    {
        return ((value as AnyObject).description)
    }
}

// MARK:- Secure Encoding

class KeyedArchiver : NSKeyedArchiver {
    open override class func archivedData(withRootObject rootObject: Any) -> Data {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: rootObject, requiringSecureCoding: true)
            return data
        }
        catch let error {
            Swift.print("KeyedArchiver: \(error.localizedDescription)")
            return Data.init()
        }
    }
    open override class func archiveRootObject(_ rootObject: Any, toFile path: String) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: rootObject, requiringSecureCoding: true)
            try data.write(to: URL.init(fileURLWithPath: path))
            return true
        }
        catch let error {
            Swift.print("KeyedArchiver: \(error.localizedDescription)")
            return false
        }
    }
}

class KeyedUnarchiver : NSKeyedUnarchiver {
    open override class func unarchiveObject(with data: Data) -> Any? {
        do {
			let unarchiver = try NSKeyedUnarchiver.init(forReadingFrom: data)
			unarchiver.requiresSecureCoding = false
			let object = unarchiver.decodeObject(of: [PlayList.self,PlayItem.self], forKey: NSKeyedArchiveRootObjectKey)
            return object
        }
        catch let error {
            Swift.print("unarchiveObject(with:) \(error.localizedDescription)")
            return nil
        }
    }

    open override class func unarchiveObject(withFile path: String) -> Any? {
        do {
            let data = try Data(contentsOf: URL.init(fileURLWithPath: path))
			let unarchiver = try NSKeyedUnarchiver.init(forReadingFrom: data)
			unarchiver.requiresSecureCoding = false
			let object = unarchiver.decodeObject(of: [PlayList.self,PlayItem.self], forKey: NSKeyedArchiveRootObjectKey)
            return object
        }
        catch let error {
            Swift.print("unarchiveObject(withFile:) \(error.localizedDescription)")
            return nil
        }
    }
	
    open class func unarchiveObject(withURL url: URL) -> Any? {
		return unarchiveObject(withFile: url.path)
	}
}

