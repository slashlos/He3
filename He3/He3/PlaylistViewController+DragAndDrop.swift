//
//  PlaylistViewController+DragAndDrop.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/6/20.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation
import Cocoa

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}
fileprivate var appDelegate : AppDelegate {
    get {
        return NSApp.delegate as! AppDelegate
    }
}

// MARK: NSTableViewDataSource

extension PlaylistViewController: NSTableViewDataSource {

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
		let arrayController = [playlistArrayController,playitemArrayController][tableView.tag]!
		let item = (arrayController.arrangedObjects as! [AnyObject])[row]
		let fileURL = item.fileURL!
		
		let fileExtension = (tableView as! PlayTableView).pathExtension
		let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
															 fileExtension as CFString, nil)
		let provider = NSFilePromiseProvider(fileType: typeIdentifier!.takeRetainedValue() as String, delegate: self)

		//	this dictionary gets us to the source object for our provider delegate
		provider.userInfo = [FilePromiseProvider.UserInfoKeys.tagKey : tableView.tag,
							 FilePromiseProvider.UserInfoKeys.rowKey : row,
							 FilePromiseProvider.UserInfoKeys.urlKey : fileURL as Any]
		return provider
    }
	
    func draggingUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        if dragSequenceNo != info.draggingSequenceNumber {
            let sourceTableView = info.draggingSource as? NSTableView
            let pboard: NSPasteboard = info.draggingPasteboard
            let items = pboard.pasteboardItems!

            print("\(String(describing: sourceTableView?.identifier)) draggingUpdate \(items.count) item(s)")

            appDelegate.newViewOptions = appDelegate.getViewOptions
            dragSequenceNo = info.draggingSequenceNumber
        }
        return .copy
    }
	
    func tableView(_ tableView: NSTableView,
				   validateDrop info: NSDraggingInfo,
				   proposedRow row: Int,
				   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        let sourceTableView = info.draggingSource as? NSTableView
		var dragOperation: NSDragOperation = []
		let pboard = info.draggingPasteboard

        print("source \(String(describing: sourceTableView?.identifier))")
		
		if sourceTableView == tableView {
			dragOperation = [.move]
		}
		else
		if sourceTableView == playlistTableView || sourceTableView == playitemTableView {
			dragOperation = .copy
		}
		else
        {
			guard let items = pboard.pasteboardItems else { return dragOperation }
			for item in items {
				if item.availableType(from: [(kUTTypeImage as NSPasteboard.PasteboardType),.fileURL]) != nil {
					// Drag source is coming from another app as a promised image file.
					dragOperation = [.copy]
				}
			}
			
			//	Has a drop operatoion been determined yet?
			if dragOperation == [] {
				//	Look for URLs we can handle
				let acceptableTypes = [kUTTypeMovie,kUTTypeVideo,kUTTypeImage,kUTTypeText,kUTTypePDF]
				let options = [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
							   NSPasteboard.ReadingOptionKey(rawValue: PlayList.className()) : true,
							   NSPasteboard.ReadingOptionKey(rawValue: PlayItem.className()) : true,
							   NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : acceptableTypes]
					as [NSPasteboard.ReadingOptionKey : Any]
				
				if let urls = pboard.readObjects(forClasses: [NSURL.self], options: options) {
					if !urls.isEmpty { dragOperation = [.copy] }
				}
			}
        }
		return dragOperation
    }
	
	//	Drop the internal items from source tableView to target tableView handling
	//	projections from a playlist to individual items and from a playitem to add
	//	to the currently selected playlist's list of playitems.
	
    func dropInternalItems(_ tableView: NSTableView, dropInfo info: NSDraggingInfo, toRow: Int) {
        let sourceTableView = info.draggingSource as? NSTableView
		
        // We have inter tableView drag-n-drop ?
        // if source is a playlist, drag its items into the destination via copy
        // if source is a playitem, drag all items into the destination playlist
        // creating a new playlist item unless, we're dropping onto an existing.
        
		switch sourceTableView {
		case playlistTableView:
            let selectedRowIndexes = sourceTableView?.selectedRowIndexes
            
            for index in selectedRowIndexes! {
                let playlist = (playlistArrayController.arrangedObjects as! [PlayList])[index]
                for playItem in playlist.list {
                    add(item: playItem, atIndex: -1)
                }
            }

		case playitemTableView:
            // These playitems get dropped into a new or append a playlist
            let items: [PlayItem] = playitemArrayController.arrangedObjects as! [PlayItem]
            var selectedPlaylist: PlayList? = playlistArrayController.selectedObjects.first as? PlayList
            let selectedRowIndexes = sourceTableView?.selectedRowIndexes

            if selectedPlaylist != nil && toRow < tableView.numberOfRows {
                selectedPlaylist = (playlistArrayController.arrangedObjects as! [PlayList])[toRow]
				selectedPlaylist?.willChangeValue(forKey: k.tally)

                for index in selectedRowIndexes! {
                    let item = items[index]
                    let togo = selectedPlaylist?.list.count
                    if let undo = self.undoManager {
                        undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": togo!] as [String : Any]] (PlaylistViewController) -> () in
                            selectedPlaylist?.list.removeLast()
                            selectedPlaylist?.list.remove(at: oldVals["index"] as! Int)
                            if !undo.isUndoing {
                                undo.setActionName("Add PlayItem")
                            }
                        })
                    }
                    observe(item, keyArray: itemIvars, observing: true)
                    selectedPlaylist?.list.append(items[index])
                }
				selectedPlaylist?.didChangeValue(forKey: k.tally)
            }
            else
            {
                add(list: PlayList(), atIndex: -1)
                tableView.scrollRowToVisible(toRow)
                ///playlistTableView.reloadData()
            }
			
		default:
			if let view = sourceTableView {
				print(String(format: "unknown source view: %p", view))
				print(view)
				return
			}
			else
			{
				fatalError("nil for sourceTableView in dropInternalItems()")
			}
		}
		
		tableView.selectRowIndexes(IndexSet.init(integer: toRow), byExtendingSelection: false)
	}
	
	//	Given a URL, return a playitem list for it
	func playitemsForURL(_ fileOrLink: URL, completion: ([PlayItem]) -> Void) {
		let dc = NSDocumentController.shared
		let isSandboxed = appDelegate.isSandboxed
		var playitems = [PlayItem]()
		let fm = FileManager.default
		var urls = [fileOrLink]
		
		//  Resolve alias before storing bookmark and store a bookmark
		while urls.count > 0 {
			let url = urls.removeFirst()
			var playitem : PlayItem

			if url.isFileURL {
				var isDirectory : ObjCBool = false

				//  Unknown files have to be sandboxed, and skip on errors
				guard isSandboxed == appDelegate.storeBookmark(url: url) else {
					print("Yoink, unable to sandbox \(String(describing: url)))")
					continue
				}
				
				// We support only playitems as files so flatten path
				guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
				if isDirectory.boolValue {
					do {
						let keys = [kCFURLIsReadableKey]
						let fileURLs = try fm.contentsOfDirectory(at: url,
																  includingPropertiesForKeys: keys as? [URLResourceKey],
																  options: [.skipsHiddenFiles])
						urls.append(contentsOf: fileURLs)
					} catch let error {
						DispatchQueue.main.async {
							NSApp.presentError(error)
						}
					}
					continue
				}
			}

			//  If we already know this url 1) known document, 2) our global items cache, use its settings
			if [k.h3l,k.hpl].contains(url.pathExtension), let dict = NSDictionary.init(contentsOf: url) {
				if nil != dict.value(forKey: k.list) {
					for item in PlayList(with: dict as! Dictionary<String, Any>).list {
						playitems.append(item)
					}
				}
				continue
			}
			else
			if [k.h3i,k.hpi,k.hic].contains(url.pathExtension), let dict = NSDictionary.init(contentsOf: url) {
				if nil != dict.value(forKey: k.link) {
					playitem = PlayItem(from: dict as! Dictionary<String, Any>)
					playitems.append(playitem)
				}
				continue
			}
			else
			if let doc = dc.document(for: url as URL) {
				playitem = (doc as! Document).playitem()
			}
			else
			if let dict = defaults.dictionary(forKey: (url.absoluteString)) {
				playitem = PlayItem(from: dict)
			}
			else
			{
				let attr = appDelegate.metadataDictionaryForFileAt(url.path)
				let time = attr?[kMDItemDurationSeconds] as? Double ?? 0.0
				let fuzz = url.deletingPathExtension().lastPathComponent as NSString
				let name = fuzz.removingPercentEncoding
				
				playitem = PlayItem(name:name!, link:url as URL, time:time, rank:-1)
			}
			
			//	Always update (sandbox) the file link
			if url.isFileURL { playitem.link = url }
			playitems.append(playitem)
		}
		completion( playitems )
	}
	
	/// Given an NSDraggingInfo from an incoming drag, handle any and all promise drags.
	///	Note that promise drags can come from any app that offers it (i.e. Safari or Photos).
	func handlePromisedDrops(_ tableView: NSTableView, draggingInfo: NSDraggingInfo, toRow: Int, dropOperation: NSTableView.DropOperation) -> Bool {
		guard let promises = draggingInfo.draggingPasteboard.readObjects(forClasses:
			[NSFilePromiseReceiver.self,NSURL.self], options: nil), !promises.isEmpty else { return false }
		var newIndexOffset = 0
 		var handled = 0

		//	We have incoming drag item(s) that are file promises.
		//	Allow drop-on items to update stale sandbox bookbmark

		// At the start of insertion(s), clear the current table view selection.
		tableView.deselectAll(self)
		
		for promise in promises {
			var playlist: PlayList?

			if let promiseReceiver = promise as? NSFilePromiseReceiver {
				// Show the progress indicator as we start receiving this promised file.
				progressIndicator.isHidden = false
				progressIndicator.startAnimation(self)
				
				// Ask our file promise receiver to fulfull on their promise.
				promiseReceiver.receivePromisedFiles(atDestination: destinationURL,
													 options: [:],
													 operationQueue: filePromiseQueue) { (fileURL, error) in
					/** Finished copying the promised file.
						Back on the main thread, insert the newly created image file into the table view.
					*/
					OperationQueue.main.addOperation {
						if error != nil {
							self.reportURLError(fileURL, error: error!)
						} else {
							let item = PlayItem(name: fileURL.lastPathComponent, link: fileURL, time: 0.0, rank: 0)
							self.add(item: item, atIndex: toRow)

							/** Select the newly inserted item,
								extend the selection so to accumulate multiple selected photos.
							*/
							let indexSet = IndexSet(integer: toRow)
							tableView.selectRowIndexes(indexSet, byExtendingSelection: true)
						}
						// Stop the progress indicator as we are done receiving this promised file.
						self.progressIndicator.isHidden = true
						self.progressIndicator.stopAnimation(self)
						handled += 1
					}
				}
			}
			else
			if let url = promise as? NSURL {

				//  add(item:) and add(list:) affect array controller selection,
				//  so we must alter selection to the drop row for playlist;
				//  note that we append items so adjust the newIndexOffset
				switch tableView {
				case playlistTableView:
					switch dropOperation {
					case .on:
						//  selected playlist is already set
						playlist = (playlistArrayController.arrangedObjects as! Array)[toRow]
						playlistArrayController.setSelectionIndex(toRow)

					default:
						playlist = PlayList(name: (url as URL).lastPathComponent, list: [PlayItem]())
						add(list: playlist!, atIndex: -1)
						playlistTableView.reloadData()
						
						//  Pick our selected playlist
						let index = playlistArrayController.selectionIndexes.first
						let selectionRow = index! + 1
						tableView.selectRowIndexes(IndexSet.init(integer: selectionRow), byExtendingSelection: true)
						newIndexOffset = -toRow
					}
					 
				default: // playitemTableView:
					playlist = playlistArrayController.selectedObjects.first as? PlayList
				}

				//	see what item(s) we can muster from this URL
				playitemsForURL(url as URL) { (playitems) in
					playlist?.willChangeValue(forKey: k.tally)
					
					for playitem in playitems {
						let path = playitem.link.absoluteString
						let list: Array<PlayItem> = playlist!.list.sorted(by: { (lhs, rhs) -> Bool in
							return lhs.rank < rhs.rank
						})
						playitem.rank = (list.count > 0) ? (list.last?.rank)! + 1 : 1
						
						//  Insert item at valid offset, else append
						//	for drop .on we could do an update using new item ?
						if (toRow+newIndexOffset) < (self.playitemArrayController.arrangedObjects as AnyObject).count {
							self.add(item: playitem, atIndex: toRow + newIndexOffset)
							
							//  Dropping on from a sourceTableView implies replacement
							if dropOperation == .on {
								let playitems: [PlayItem] = (self.playitemArrayController.arrangedObjects as! [PlayItem])
								let oldItem = playitems[toRow+newIndexOffset+1]

								//  We've shifted so remove old item at new location
								self.remove(item: oldItem, atIndex: toRow+newIndexOffset+1)
							}
						}
						else
						{
							self.add(item: playitem, atIndex: -1)
						}
						defaults.set(playitem.dictionary(), forKey: path)

						newIndexOffset += 1
					}
					handled += 1
				}
				
				playlist?.didChangeValue(forKey: k.tally)
			}
		}
		
		return handled == promises.count
	}

    // Drop the external dragged items in this table view to the target row.
    func dropExternalItems(_ tableView: NSTableView, draggingInfo: NSDraggingInfo, toRow: Int, dropOperation: NSTableView.DropOperation) {
        // If possible, first handle the incoming dragged photos as file promises.
        if handlePromisedDrops(tableView, draggingInfo: draggingInfo, toRow: toRow, dropOperation: dropOperation) {
            // Successfully processed the dragged items that were promised to us.
        } else {
            var numItemsInserted = 0
            draggingInfo.enumerateDraggingItems(
                options: NSDraggingItemEnumerationOptions.concurrent,
                for: tableView,
                classes: [NSPasteboardItem.self],
                searchOptions: [:],
                using: {(draggingItem, idx, stop) in
                    if let pasteboardItem = draggingItem.item as? NSPasteboardItem {
                        // Are we being passed a file URL as the drag type?
                        if  let itemType = pasteboardItem.availableType(from: [.fileURL]),
                            let filePath = pasteboardItem.string(forType: itemType),
                            let url = URL(string: filePath) {
							
							let item = PlayItem(name: url.simpleSpecifier, link: url, time: 0.0, rank: 0)
							self.add(item: item, atIndex: toRow)
							numItemsInserted += 1
                        }
                    }
                })
            
            // Select the newly inserted photo items.
            let selectionRange = toRow..<toRow + numItemsInserted
            let indexSet = IndexSet(integersIn: selectionRange)
            tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
            
            // If any of the dragged URLs were not image files, alert the user.
			if numItemsInserted != draggingInfo.draggingPasteboard.pasteboardItems?.count {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("CannotImportTitle", comment: "")
                alert.informativeText = NSLocalizedString("CannotImportMessage", comment: "")
                alert.addButton(withTitle: NSLocalizedString("OKTitle", comment: ""))
                alert.alertStyle = .warning
                alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
            }
        }
    }
	
    func moveInternalItems(_ tableView: NSTableView, dropInfo info: NSDraggingInfo, toRow: Int) {
        var indexesToMove = IndexSet()
		
        info.enumerateDraggingItems(
            options: NSDraggingItemEnumerationOptions.concurrent,
            for: tableView,
            classes: [NSPasteboardItem.self],
            searchOptions: [:],
            using: {(draggingItem, idx, stop) in
                if  let pasteboardItem = draggingItem.item as? NSPasteboardItem,
                    let index = pasteboardItem.propertyList(forType: .rowDragType) as? Int {
                        indexesToMove.insert(index)
                    }
            })
                
        // Move/drop the photos in their correct place using their indexes.
		moveObjectsFromIndexes(tableView, indexSet: indexesToMove, toIndex: toRow)
        
        // Set the selected rows to those that were just moved.
        let rowsMovedDown = rowsMovedDownward(toRow, indexSet: indexesToMove)
        let selectionRange = toRow - rowsMovedDown..<toRow - rowsMovedDown + indexesToMove.count
        let indexSet = IndexSet(integersIn: selectionRange)
        tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
	}
	
	func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let sourceTableView = info.draggingSource as? NSTableView
		
		if [playlistTableView,playitemTableView].contains(sourceTableView) {
            /// Drag source came from one of own table viewa.
			/// Move each dragged item to their new place.
			///	Also handle cross-table <-> outline drops.
			if sourceTableView == tableView {
				// We have intra tableView drag-n-drop ?
				moveInternalItems(tableView, dropInfo: info, toRow: row)
			}
			else
			{
				// We have inter tableView drag-n-drop ?
				dropInternalItems(tableView, dropInfo: info, toRow: row)
			}
		}
		else
		{
			/// The drop source is from another app (Finder, Mail, Safari, etc.) and there may be more than one file.
			/// Drop each dragged image file to their new place.
			dropExternalItems(tableView, draggingInfo: info, toRow: row, dropOperation: dropOperation)
		}
		return true
	}
	
    /** Implement this function to know when the dragging session has ended.
        This delegate function can be used to know when the dragging source operation ended at a specific location,
        such as the trash (by checking for an operation of NSDragOperationDelete).
    */
    func tableView(_ tableView: NSTableView,
                   draggingSession session: NSDraggingSession,
                   endedAt screenPoint: NSPoint,
                   operation: NSDragOperation) {
        if operation == .delete, let items = session.draggingPasteboard.pasteboardItems {
			let arrayController = [playlistArrayController,playitemArrayController][tableView.tag]!

            // User dragged the photo to the Finder's trash.
            for pasteboardItem in items {
                if let itemRow = pasteboardItem.propertyList(forType: .rowDragType) as? Int {
                    let item = (arrayController.arrangedObjects as! [AnyObject])[itemRow]
					Swift.debugPrint("Remove \(String(describing: item.turl))")
                }
            }
        }
    }
    
    // Reports the error and related URL, generated from the NSFilePromiseReceiver operation.
    func reportURLError(_ url: URL, error: Error) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("ErrorTitle", comment: "")
        alert.informativeText = String(format: NSLocalizedString("ErrorMessage", comment: ""), url.lastPathComponent, error.localizedDescription)
        alert.addButton(withTitle: NSLocalizedString("OKTitle", comment: ""))
        alert.alertStyle = .warning
        alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
	
    // MARK: - Table Row Movement Utilities
    
    // Move the set of objects within the indexSet to the 'toIndex' row number.
    func moveObjectsFromIndexes(_ tableView: NSTableView, indexSet: IndexSet, toIndex: Int) {
		let arrayController = [playlistArrayController,playitemArrayController][tableView.tag]!

        var insertIndex = toIndex
        var currentIndex = indexSet.last
        var aboveInsertCount = 0
        var removeIndex = 0
      
        while currentIndex != nil {
            if currentIndex! >= toIndex {
                removeIndex = currentIndex! + aboveInsertCount
                aboveInsertCount += 1
            } else {
                removeIndex = currentIndex!
                insertIndex -= 1
            }

			let object = (arrayController.arrangedObjects as! [AnyObject])[removeIndex]
			arrayController.remove(atArrangedObjectIndex: removeIndex)
			arrayController.insert(object, atArrangedObjectIndex: insertIndex)
          
            currentIndex = indexSet.integerLessThan(currentIndex!)
        }
    }
    
    // Returns the number of rows dragged in a downward direction within the table view.
    func rowsMovedDownward(_ row: Int, indexSet: IndexSet) -> Int {
        var rowsMovedDownward = 0
        var currentIndex = indexSet.first
        while currentIndex != nil {
            if currentIndex! < row {
                rowsMovedDownward += 1
            }
            currentIndex = indexSet.integerGreaterThan(currentIndex!)
        }
        return rowsMovedDownward
    }

}

// MARK: - NSFilePromiseProviderDelegate

extension PlaylistViewController: NSFilePromiseProviderDelegate {

    /** This function is called at drop time to provide the title of the file being dropped.
        This sample uses a hard-coded string for simplicity, but depending on your use case, you should take the fileType parameter into account.
    */
	func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
		let userInfo = filePromiseProvider.userInfo as? [String: Any]
		let tag = userInfo![FilePromiseProvider.UserInfoKeys.tagKey] as? Int
		var fileURL : URL
		
        // Return the item's URL promise's
		let item = itemFromFilePromiserProvider(filePromiseProvider: filePromiseProvider)!
		switch tag {
		case 0:
			fileURL = (item as! PlayList).fileURL
		case 1:
			fileURL = (item as! PlayItem).fileURL
		default:
			fatalError("unknown tag key for filePromiseProvider")
		}

		return fileURL.lastPathComponent
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
			let tag = userInfo[FilePromiseProvider.UserInfoKeys.tagKey] as? Int,
			let row = userInfo[FilePromiseProvider.UserInfoKeys.rowKey] as? Int {
			
			let arrayController = [playlistArrayController,playitemArrayController][tag];
			let objects = arrayController!.arrangedObjects as! [AnyObject]
			item = objects[row]
		}
        return item
    }
}

