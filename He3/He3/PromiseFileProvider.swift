//
//  PromiseFileProvider.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/9/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import Cocoa

class DocumentPromiseProvider : NSFilePromiseProvider {
	
    struct UserInfoKeys {
		static let docKey = "doc"
        static let urlKey = "url"
    }

	/** Required:
		Return an array of UTI strings of data types the receiver can write to the pasteboard.
		By default, data for the first returned type is put onto the pasteboard immediately, with the remaining types being promised.
		To change the default behavior, implement -writingOptionsForType:pasteboard: and return NSPasteboardWritingPromised
		to lazily provided data for types, return no option to provide the data for that type immediately.
	 
		Use the pasteboard argument to provide different types based on the pasteboard name, if desired.
		Do not perform other pasteboard operations in the function implementation.
	*/
	override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		var types = super.writableTypes(for: pasteboard)
		types.append(.docDragType) // Add our own internal drag type (document known by conroller).
		types.append(.fileURL) // Add the .fileURL drag type (to promise files to other apps).
		return types
	}
	
	/** Required:
		Return the appropriate property list object for the provided type.
		This will commonly be the NSData for that data type.  However, if this function returns either a string, or any other property-list type,
		the pasteboard will automatically convert these items to the correct NSData format required for the pasteboard.
	*/
	override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
		guard let userInfoDict = userInfo as? [String: Any] else { return nil }
	
		switch type {
		case .fileURL:
			// Incoming type is "public.file-url", return (from our userInfo) the URL.
			if let url = userInfoDict[FilePromiseProvider.UserInfoKeys.urlKey] as? NSURL {
				return url.pasteboardPropertyList(forType: type)
			}
		case .docDragType:
			// Incoming type is "com.slashlos.mydragdrop", return (from our userInfo) the table row index.
			if let doc = userInfoDict[DocumentPromiseProvider.UserInfoKeys.docKey] as? String {
				return doc
			}
		default: break
		}
		
		return super.pasteboardPropertyList(forType: type)
	}
	
	/** Optional:
		Returns options for writing data of a type to a pasteboard.
		Use the pasteboard argument to provide different options based on the pasteboard name, if desired.
		Do not perform other pasteboard operations in the function implementation.
	 */
	public override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard)
		-> NSPasteboard.WritingOptions {
		return super.writingOptions(forType: type, pasteboard: pasteboard)
	}
}

class FilePromiseProvider: NSFilePromiseProvider {
    
    struct UserInfoKeys {
		static let tagKey = "tagNumber"
        static let rowKey = "rowNumber"
        static let urlKey = "url"
    }
    
    /** Required:
        Return an array of UTI strings of data types the receiver can write to the pasteboard.
        By default, data for the first returned type is put onto the pasteboard immediately, with the remaining types being promised.
        To change the default behavior, implement -writingOptionsForType:pasteboard: and return NSPasteboardWritingPromised
        to lazily provided data for types, return no option to provide the data for that type immediately.
     
        Use the pasteboard argument to provide different types based on the pasteboard name, if desired.
        Do not perform other pasteboard operations in the function implementation.
    */
    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types = super.writableTypes(for: pasteboard)
        types.append(.rowDragType) // Add our own internal drag type (row drag and drop reordering).
        types.append(.fileURL) // Add the .fileURL drag type (to promise files to other apps).
        return types
    }
    
    /** Required:
        Return the appropriate property list object for the provided type.
        This will commonly be the NSData for that data type.  However, if this function returns either a string, or any other property-list type,
        the pasteboard will automatically convert these items to the correct NSData format required for the pasteboard.
    */
    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard let userInfoDict = userInfo as? [String: Any] else { return nil }
    
        switch type {
        case .fileURL:
            // Incoming type is "public.file-url", return (from our userInfo) the URL.
            if let url = userInfoDict[FilePromiseProvider.UserInfoKeys.urlKey] as? NSURL {
                return url.pasteboardPropertyList(forType: type)
            }
        case .rowDragType:
            // Incoming type is "com.mycompany.mydragdrop", return (from our userInfo) the table row index.
            if let tagRow = userInfoDict[FilePromiseProvider.UserInfoKeys.rowKey] as? Int {
                return tagRow
            }
        default: break
        }
        
        return super.pasteboardPropertyList(forType: type)
    }
    
    /** Optional:
        Returns options for writing data of a type to a pasteboard.
        Use the pasteboard argument to provide different options based on the pasteboard name, if desired.
        Do not perform other pasteboard operations in the function implementation.
     */
    public override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard)
        -> NSPasteboard.WritingOptions {
        return super.writingOptions(forType: type, pasteboard: pasteboard)
    }

}
