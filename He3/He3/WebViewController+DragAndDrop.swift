//
//  WebViewController+DragAndDrop.swift
//  He3
//
//  Created by Carlos D. Santiago on 10/25/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import WebKit

extension WebViewController: NSFilePromiseProviderDelegate {

	/** This function is called at drop time to provide the title of the file being dropped.
		This sample uses a hard-coded string for simplicity, but depending on your use case, you should take the fileType parameter into account.
	*/
	func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
		// Return the item's URL promise's
		let item = itemFromFilePromiserProvider(filePromiseProvider: filePromiseProvider)!

		if let playlist = (item as? PlayList) {
			return playlist.fileURL.lastPathComponent
		}
		else
		{
			let playitem = (item as! PlayItem)
			return playitem.fileURL.lastPathComponent
		}
	}
	
	func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
							 writePromiseTo url: URL,
							 completionHandler: @escaping (Error?) -> Void) {
		do {
			let item = itemFromFilePromiserProvider(filePromiseProvider: filePromiseProvider)!
			let userInfo = filePromiseProvider.userInfo as? [String: Any]
			let tag = userInfo![FilePromiseProvider.UserInfoKeys.tagKey] as? Int
			var dict : Dictionary<String,Any>
			
			 /** Copy the file to the location provided to us. We always do a copy, not a move.
				 It's important you call the completion handler.
			 */
			switch tag {
			case 0:
				dict = (item as! PlayList).dictionary()
			case 1:
				dict = (item as! PlayItem).dictionary()
			default:
				throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
			}
			try (dict as NSDictionary).write(to: url)
			if url.hideFileExtensionInPath() {
				print("provide => \(String(describing: url.absoluteString.removingPercentEncoding))")
			}
			completionHandler(nil)
		} catch let error {
			OperationQueue.main.addOperation {
				self.presentError(error, modalFor: self.view.window!,
								  delegate: nil, didPresent: nil, contextInfo: nil)
			}
			completionHandler(error)
		}
	}
	
	/** You should provide a non main operation queue (e.g. one you create) via this function.
		This way you don't stall the main thread while writing the promise file.
	*/
	func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
		return filePromiseQueue
	}
	
	// Utility function to return a Playlist/PlayItem object from the NSFilePromiseProvider.
	func itemFromFilePromiserProvider(filePromiseProvider: NSFilePromiseProvider) -> AnyObject? {
		var item : AnyObject?
		
		if  let userInfo = filePromiseProvider.userInfo as? [String: Any],
			let url = userInfo[FilePromiseProvider.UserInfoKeys.urlKey] as? String {
			item = UserDefaults.value(forKey: url) as AnyObject?
		}
		return item
	}
}


