//
//  Document.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017-2021 CD M Santiago. All rights reserved.
//
//  Document instance read/save/write are to default; use super for files

import Cocoa
import Foundation
import QuickLook
import ServiceManagement

// Document Class Types
//
//	A Helium document is any file can be read by super but state written by us to defaults.
//	Such documnet sare never modified in place; only their state can changed and maintained
//	by a playitem object cached in user defaults.
//
//	A Playlist document is a file which is read or written by super; its format adheres
//	to an Apple propertly-list file.  Its state can be changed and maintained by its
//	cache in user defaults. It encompasses several Playitem objects.
//
//	A Playitem document is a file which is read or written by super; its format adhers
//	to an Apple property-list file.  Its state can be changed and maintained by its
//	cache in user defaults. It encompasses a single URL context, similarly as a union of
//		* a .webloc Safari file,
//		* a Finder alias,
//	and enriched with its object state written to disk and its cache in user defaults.
//
//	A Release document is an assets based static URL - information released to the user,
//	for read-only purposes, such as release notes, help text, etc. It does feature a
//	Playitem object to track its state as cache in the user defaults.

struct DocGroup : OptionSet {
    let rawValue: Int

    static var helium    = DocGroup(rawValue: 0)
	static let playitem  = DocGroup(rawValue: 1)
    static let playlist  = DocGroup(rawValue: 2)
	static let release	 = DocGroup(rawValue: 3)
}
let docHelium : DocGroup = []

let docGroups = [k.Helium, k.ItemName, k.PlayName, k.Release]
let docNames  = [k.Helium, k.ItemName, k.PlayName, k.Release]

extension NSPasteboard.PasteboardType {
    static let docDragType = NSPasteboard.PasteboardType("com.slashlos.docDragDrop")
}

fileprivate var docController : DocumentController {
	get {
		return NSDocumentController.shared as! DocumentController
	}
}

class Document : NSDocument {
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    override class var autosavesInPlace: Bool {
		//	Actually we do and want visible dirty dot icon
		//	centered atop the close button as a red "dot".
        return false
    }
    var defaults = UserDefaults.standard
    var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
    }
    var settings: Settings
    var items: [PlayList]
	
	//	We "might" be a global playlist if no fileURL
	//	as seen when we are our window is restored.
	var isGlobalPlaylist: Bool = false
    
    var docGroup : DocGroup {
        get {
			if [k.ItemType,k.ItemName].contains(self.fileType)
			|| [k.hpi,k.h3i].contains(fileURL?.pathExtension)  {
				return .playitem
			}
			else
			if [k.PlayType,k.PlayName].contains(self.fileType)
			|| [k.hpl,k.h3l].contains(fileURL?.pathExtension) {
				return .playlist
			}
			else
			if [k.IcntType,k.IcntName].contains(self.fileType)
			|| [k.hic].contains(fileURL?.pathExtension)  {
				return .playitem
			}
			
            return .helium
        }
    }
    
    var heliumPanelController : HeliumController? {
        get {
            guard let hpc : HeliumController = windowControllers.first as? HeliumController else { return nil }
            return hpc
        }
    }
    var homeURL : URL {
        get {
            guard let hpc = heliumPanelController else { return URL.init(string: UserSettings.HomePageURL.value)! }
            return hpc.homeURL
        }
    }
    var url : URL? {
        get {
            if let url = self.fileURL
            {
                return url
            }
            else
            if let hpc = heliumPanelController, let webView = hpc.webView
            {
                return webView.url
            }
            else
            {
				return fileType == k.ItemType ? homeURL : nil
            }
        }
    }

    func dictionary() -> Dictionary<String,Any> {
        var dict: Dictionary<String,Any> = Dictionary()
        dict[k.name] = self.displayName
        dict[k.link] = self.fileURL?.absoluteString
        dict[k.date] = settings.date.value
        dict[k.time] = settings.time.value
        dict[k.rank] = settings.rank.value
        dict[k.rect] = NSStringFromRect(settings.rect.value)
        dict[k.plays] = settings.plays.value
        dict[k.label] = settings.autoHideTitlePreference.value.rawValue as AnyObject
        dict[k.hover] = settings.floatAboveAllPreference.value.rawValue as AnyObject
        dict[k.alpha] = settings.opacityPercentage.value
        dict[k.trans] = settings.translucencyPreference.value.rawValue as AnyObject
        dict[k.agent] = settings.customUserAgent.value
        return dict
    }
    
    func playitem() -> PlayItem {
        let item = PlayItem()
        item.name = self.displayName
		if let linkURL = heliumPanelController?.webView?.url {
			item.link = linkURL
			item.name = linkURL.deletingPathExtension().lastPathComponent
		}
        item.date = self.settings.date.value
        item.time = self.settings.time.value
        item.rank = self.settings.rank.value
        item.rect = self.settings.rect.value
        item.plays = self.settings.plays.value
        item.label = self.settings.autoHideTitlePreference.value.rawValue
        item.hover = self.settings.floatAboveAllPreference.value.rawValue
        item.alpha = self.settings.opacityPercentage.value
        item.trans = self.settings.translucencyPreference.value.rawValue
        item.agent = self.settings.customUserAgent.value
        return item
    }
    
	func playlist() -> PlayList {
		guard [.playlist].contains(docGroup), let playlist = items.first else {
			let item = PlayList()
			item.name = self.displayName
			item.date = self.settings.date.value
			item.list = [self.playitem()]
			return item
		}
		playlist.update(with: dictionary())
		return playlist
	}
	
	func playlists() -> [Dictionary<String,Any>] {
		var plists = [Dictionary<String,Any>]()
		
		for plist in items {
			plists.append(plist.dictionary())
		}
		
		return plists
	}
	
	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)
		
		coder.encode(isGlobalPlaylist, forKey: "isGlobalPlaylist")
	}
	override func restoreState(with coder: NSCoder) {
		super.restoreState(with: coder)
		
		isGlobalPlaylist = coder.decodeBool(forKey: "isGlobalPlaylist")
	}

    func restoreSettings(with dictionary: Dictionary<String,Any>) {
        //  Wait until we're restoring after open or in intialization
        guard !appDelegate.openForBusiness || UserSettings.RestoreDocAttrs.value else { return }
        
        if let name : String = dictionary[k.name] as? String, name != self.displayName {
            self.displayName = name
        }
        if let link : URL = dictionary[k.link] as? URL, link != self.fileURL {
            self.fileURL = link
        }
        if let date : TimeInterval = dictionary[k.date] as? TimeInterval, date != self.settings.date.value {
            self.settings.date.value = date
        }
        if let time : TimeInterval = dictionary[k.time] as? TimeInterval, time != self.settings.time.value {
            self.settings.time.value = time
        }
        if let rank : Int = dictionary[k.rank] as? Int, rank != self.settings.rank.value {
            self.settings.rank.value = rank
        }
        if let rect = dictionary[k.rect] as? String {
            self.settings.rect.value = NSRectFromString(rect)
			if let window = self.windowControllers.first?.window, !NSEqualRects(NSZeroRect, CGRect(for: rect)) {
                window.setFrame(from: rect)
            }
        }
        if let plays : Int = dictionary[k.plays] as? Int, plays != self.settings.plays.value {
            self.settings.plays.value = plays
        }
        if let label : Int = dictionary[k.label] as? Int, label != self.settings.autoHideTitlePreference.value.rawValue {
            self.settings.autoHideTitlePreference.value = HeliumController.AutoHideTitlePreference(rawValue: label)!
        }
        if let hover : Int = dictionary[k.hover] as? Int, hover != self.settings.floatAboveAllPreference.value.rawValue {
            self.settings.floatAboveAllPreference.value = HeliumController.FloatAboveAllPreference(rawValue: hover)
        }
        if let alpha : Int = dictionary[k.alpha] as? Int, alpha != self.settings.opacityPercentage.value {
            self.settings.opacityPercentage.value = alpha
        }
        if let trans : Int = dictionary[k.trans] as? Int, trans != self.settings.translucencyPreference.value.rawValue {
            self.settings.translucencyPreference.value = HeliumController.TranslucencyPreference(rawValue: trans)!
        }

        if self.settings.time.value == 0.0, let url = self.url, url.isFileURL {
            let attr = appDelegate.metadataDictionaryForFileAt((self.fileURL?.path)!)
            if let secs = attr?[kMDItemDurationSeconds] {
                self.settings.time.value = secs as! TimeInterval
            }
        }
        if self.settings.rect.value == NSZeroRect, let fileURL = self.fileURL, let dict = defaults.dictionary(forKey: fileURL.absoluteString) {
            if let rect = dict[k.rect] as? String {
                self.settings.rect.value = NSRectFromString(rect)
                if let window = self.windowControllers.first?.window {
                    window.setFrame(from: rect)
                }
            }
        }
        if let agent : String = dictionary[k.agent] as? String, agent != settings.customUserAgent.value {
            self.settings.customUserAgent.value = agent
            if let hpc = heliumPanelController, let webView = hpc.webView {
                webView.customUserAgent = agent
            }
        }
    }
    
    func restoreSettings(with playitem: PlayItem) {
		restoreSettings(with: playitem.dictionary())
	}
	
    func update(to url: URL) {
        self.fileURL = url
        
        if let dict = defaults.dictionary(forKey: url.absoluteString) {
            let item = PlayItem(from: dict)
            
            if item.rect != NSZeroRect {
                self.settings.rect.value = item.rect
                self.updateChangeCount(.changeDone)
             }
        }
        if url.isFileURL { _displayImage = nil }
    }
    func update(with item: PlayItem) {
        self.update(to: item.link)
    }
    
    override func defaultDraftName() -> String {
        return docNames[docGroup.rawValue]
    }

    var _displayImage: NSImage?
    var displayImage: NSImage {
        get {
            switch docGroup {
            case .playlist:
				return NSImage.init(named: k.listIcon)!

            default:
                guard _displayImage == nil else { return _displayImage! }
                
				guard let url = self.fileURL, url.isFileURL else { return NSImage.init(named: k.itemIcon)! }
				
				let size = NSSize.init(width: 32.0, height: 32.0)
				
				let ref = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL , size, nil)
				if let cgImage = ref?.takeUnretainedValue() {
					_displayImage = NSImage(cgImage: cgImage, size: size)
					ref?.release()
					return _displayImage!
				}
				return NSImage.init(named: k.docIcon)!
            }
        }
    }
    var dragImage : NSImage {
        get {
            return displayImage.resize(w: 32, h: 32)
        }
    }
    override var displayName: String! {
        get {
			guard let fileURL = self.fileURL else {
				return [.helium,.playitem].contains(docGroup) ? k.AppLogo : super.displayName
			}
            if fileURL.isFileURL || k.asset == fileURL.scheme
            {
                return fileURL.deletingPathExtension().lastPathComponent
            }
            else
            if k.local == fileURL.scheme {
                let paths = fileURL.pathComponents
				assert(paths[0] == "/")
                let cache = paths[1]
                let stamp = paths[2]

				if k.defaults == paths[1] {
					return fileURL.deletingPathExtension().lastPathComponent.capitalized
				}
				
                if let date = stamp.tad2Date() {
                    let dateFMT = DateFormatter()
                    dateFMT.locale = Locale(identifier: "en_US_POSIX")
                    dateFMT.dateFormat = "MMM d, yy h:mm:ss a"

                    return String(format: "%@ - %@", cache.capitalized, dateFMT.string(from: date))
                }
            }
            return super.displayName
        }
        set (newName) {
            super.displayName = newName
        }
    }
    
    // MARK: Initialization
    override init() {
        settings = Settings()
        items = [PlayList]()
        
        super.init()
    }
    
    convenience init(type typeName: String) throws {
        do {
            self.init()
        
            //  sync docGroup group identifier to typeName
            fileType = typeName
        }
    }
        
    convenience init(contentsOf url: URL) throws {
        do {
			let typeName = try docController.typeForContents(of: url)
            try self.init(contentsOf: url, ofType: typeName)
        }
    }
    
    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        //  Record url and type, caller will load via notification
        do {
            self.init()

            fileURL = url
            fileType = typeName
			
			//	a global playlists is source from local defaults
			guard url.scheme == k.local else { return }
			let paths = url.deletingPathExtension().pathComponents
			guard paths[0] == "/", paths[1] == k.defaults else { return }
			isGlobalPlaylist = typeName == k.PlayType
        }
    }
    
    override func data(ofType typeName: String) throws -> Data {
        var array = [PlayList]()

		switch typeName {
		case k.ItemType:
			// Save as single playlist of our settings
			let playitem = self.playitem()
			let playlist = PlayList(name: displayName, list: [playitem])
			array.append(playlist)

		case k.PlayType:
			//  Write playlists, history and searches
			  
			// Save playlist(s) - no maximum
			array += items

		default:
			array.append(PlayList(name: displayName, list: [playitem()]))
		}
		
        return KeyedArchiver.archivedData(withRootObject: array)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        //	Always try first for securely encoded archive
        do {
			if [k.ItemType].contains(typeName) || [.playitem].contains(docGroup) {
				do {
					let playlists = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self,PlayList.self,PlayItem.self], from: data) as! [PlayList]
					for playlist in playlists {
						items.append(playlist)
					}
				} catch let error {
					let dict = try PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions.mutableContainers, format: nil)
					let item = PlayItem(from: dict as! Dictionary<String, Any>)
					items.append(PlayList(name: fileURL?.lastPathComponent ?? item.name, list: [item]))
					
					if 0 == items.count { NSApp.presentError(error) }
				}
			}
			else
			if [k.PlayType].contains(typeName) || [.playlist].contains(docGroup) {
				do {
					let playlists = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self,PlayList.self,PlayItem.self], from: data) as! [PlayList]
					for playlist in playlists {
						items.append(playlist)
					}
				} catch let error {
					let dict = try PropertyListSerialization.propertyList(from: data, options: PropertyListSerialization.ReadOptions.mutableContainers, format: nil)
					
					//	Our dictionary = PlayList must have 3 keys
					if let plist = dict as? Dictionary<String,Any>, 3 == plist.keys.count, plist.keys.sorted().elementsEqual([k.date,k.list,k.name]) {
						let item = PlayList(with: dict as! Dictionary<String, Any>)
						items.append(item)
					}
					else
					if let plist = dict as? Dictionary<String,Any>, 1 == plist.keys.count, k.Playlists == plist.keys.first {
						for plist in plist[k.Playlists] as! [Dictionary<String,Any>] {
							let item = PlayList(with: plist)
							items.append(item)
						}
					}
					else
					{
						NSApp.presentError(error)
						return
					}
				}
			}
			else
			{
                for (i,item) in items.enumerated() {
                    switch i {
                    case 0:
                        fileURL = item.list.first?.link
                        
                    default:
                        ///Swift.print("\(i) -> \(item.description)")
						break
                    }
                }
            }
        }
        catch let error {
            Swift.print("\(error.localizedDescription)")
        }
		
		if let url = fileURL, let dict = defaults.dictionary(forKey: url.absoluteString) {
			restoreSettings(with: dict)
		}
    }

    override func read(from url: URL, ofType typeName: String) throws {
		let oneOfUs = [k.hpi,k.h3i,k.hpl,k.h3l,k.hic].contains(url.pathExtension)
		
        //	Push to super any file: URLs for our documents.
		//	Handle local: URLs here, otherwise defer to WkWebView
		if [k.ItemType,k.ItemName].contains(typeName)
		|| [k.PlayType,k.PlayName].contains(typeName)
		|| [k.IcntType,k.IcntName].contains(typeName)
		|| oneOfUs {
			do {
				if k.local == url.scheme {
					let paths = url.deletingPathExtension().pathComponents
					assert([k.asset,k.defaults].contains(paths[1]))
					let keyPath = paths[2]
					
					switch paths[1] {
					case k.asset:
						break
					
					case k.defaults:
						if k.PlayType == typeName {
							items = appDelegate.restorePlaylists(keyPath)
						}
						else
						{
							items = appDelegate.restorePlaylists(keyPath)
						}
						
					default:
						let message = String(format: "Unknown local sub-scheme: %@", paths[1])
						fatalError(message)
					}
					
					//	A global playlist is a local: defaults URL on our short list
					self.isGlobalPlaylist = [k.histories,k.playlists].contains(keyPath)
				}
				else
				if oneOfUs
				{
					try super.read(from: url, ofType: typeName)
				}
				
				if let dict = defaults.dictionary(forKey: url.absoluteString) {
					restoreSettings(with: dict)
				}
			} catch let error {
				if let dict = NSDictionary(contentsOf: url) as? [String : AnyObject] {
					if let saved = dict["items"] as? [PlayList] {
						items.append(contentsOf: saved)
					}
					if let attrs = dict["attrs"] as? Dictionary<String,Any> {
						restoreSettings(with: attrs)
					}
				}
				else
				{
					NSApp.presentError(error)
				}
			}
		}
    }
    
	@objc @IBAction override func revertToSaved(_ sender: (Any)?) {
		
        //  If we have a file and type revert to them
        if let url = fileURL, let type = fileType {
            do {
                try revert(toContentsOf: url, ofType: type)
            }
            catch let error {
                NSApp.presentError(error)
            }
        }

        //  non-file revert handling, either defaults or an asset
		if let url = fileURL, let dict = defaults.dictionary(forKey: url.absoluteString) {
			restoreSettings(with: dict)
        }
    }
    
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {

        //  Defer custom setups until we have a webView
        if [k.Custom].contains(typeName) { return }

        //  revert() should call read(data) then restore controller later
        try read(from: url, ofType: typeName)
    }
    
	open override func autosave(withImplicitCancellability autosavingIsImplicitlyCancellable: Bool, completionHandler: @escaping (Error?) -> Void) {
		guard hasUnautosavedChanges else { return }
		
		//	Since we autosave in place, a URL is not really necessary
		if let url = url, url.isFileURL, [.playitem,.playlist].contains(docGroup) {
			do {
				let typeName = try docController.typeForContents(of: url)
				save(to: url, ofType: typeName, for: .autosaveInPlaceOperation, completionHandler: completionHandler)
			} catch let error {
				NSApp.presentError(error)
			}
		}
		else
		{
			do {
				if let url = fileURL, let type = fileType {
					try self.write(to: url, ofType: type)
				}
				else
				{
					cacheSettings(fileURL ?? homeURL)
				}
				completionHandler(nil)
			} catch let error {
				NSApp.presentError(error)
			}
		}
	}

    @objc @IBAction override func save(_ sender: (Any)?) {
        
		if let url = url, url.isFileURL, [.playitem,.playlist].contains(docGroup) {
			do {
				let typeName = try docController.typeForContents(of: url)

				save(to: url, ofType: typeName, for: .saveOperation, completionHandler: {_ in
					self.updateChangeCount(.changeCleared)
				})
			} catch let error {
				NSApp.presentError(error)
			}
        }
        else
        {
			do {
				if let url = fileURL, let type = fileType {
					try self.write(to: url, ofType: type)
				}
				else
				{
					cacheSettings(fileURL ?? homeURL)
				}
				updateChangeCount(.changeCleared)
            } catch let error {
                NSApp.presentError(error)
            }
        }
    }
    
	
	@objc @IBAction func selectFileType(_ sender: Any?) {
		if let item = (sender as! NSPopUpButton).selectedItem, item.isEnabled {
			let type = [k.ItemType,k.PlayType,k.WebArchive][item.tag]
			if let extn = self.fileNameExtension(forType: type, saveOperation: .saveAsOperation) {
				savePanel.allowedFileTypes = [extn]
			}
			else
			if 3 == item.tag {
				savePanel.allowedFileTypes = [k.webarchive]
			}
		}
	}

	var savePanel = NSSavePanel()

    @objc @IBAction override func saveAs(_ sender: Any?) {
        if let window = windowControllers.first?.window {
			let storyboard = NSStoryboard(name: "Main", bundle: nil)
 			let saveAsController = (storyboard.instantiateController(withIdentifier: "SaveAsViewController") as! SaveAsViewController)
			let saveAsView = saveAsController.view
			let formatPopup = saveAsController.formatPopup
			formatPopup?.target = self
			
			///let saveType = [k.ItemType,k.PlayType].contains(self.fileType) ? self.fileType! : k.ItemType
			//let saveType = [k.ItemType,k.PlayType].contains(self.fileType) ? self.fileType : k.ItemType

			//	Allow web archive as selection but not allowed as file type
			formatPopup?.item(withTitle: k.WebArchive)?.isEnabled = [k.http,k.https].contains(fileURL?.scheme)
			formatPopup?.item(withTitle: k.WebArchive)?.isHidden = ![k.http,k.https].contains(fileURL?.scheme)
			
			if let item = formatPopup?.item(withTitle: defaultDraftName()) {
				formatPopup?.select(item)
			}
			else
			{
				//	We can always write a playitem
				formatPopup?.selectItem(at: 0)
			}
			
			//	We will only saveAs or write to our own supported types
			savePanel.nameFieldStringValue = url?.lastPathComponent ?? defaultDraftName()
			savePanel.allowedFileTypes = [self.fileNameExtension(forType: k.ItemType, saveOperation: .saveAsOperation)!]
			
			//	Fixup autolayout
			saveAsView.translatesAutoresizingMaskIntoConstraints = false
			saveAsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 360.0).isActive = true
			saveAsView.heightAnchor.constraint(greaterThanOrEqualToConstant: 83.0).isActive = true
			savePanel.accessoryView = saveAsView
			
            savePanel.beginSheetModal(for: window, completionHandler: { (result: NSApplication.ModalResponse) in
                if result == .OK {
                    do {
						if let saveURL = self.savePanel.url, let tag = formatPopup?.selectedTag() {
							switch tag {
							case 0,1:
								try self.write(to: saveURL, ofType: [k.ItemType,k.PlayType][tag])
								if saveURL.hideFileExtensionInPath() {
									self.updateChangeCount(.changeCleared)
								}
							case 2:
								Swift.print("save webarchive: \(saveURL.path)")
								if let wvc = window.contentViewController as? WebViewController {
									saveAsController.webArchiveMenuItem.representedObject = saveURL
									wvc.archive(saveAsController.webArchiveMenuItem)
								}
							default:
								fatalError("Unknown save as format:\(tag)")
							}
                        }
                    } catch let error {
                        NSApp.presentError(error)
                    }
                }
            })
         }
    }
    
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
		cacheSettings(url)

        guard url != homeURL else {
			updateChangeCount(.changeCleared)
			completionHandler(nil)
            return
        }

		if url.isFileURL, [.playitem,.playlist].contains(docGroup) {
			if UserSettings.SecureFileEncoding.value {
				super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
			}
			else
			{
				do {
					try writeSafely(to: url, ofType: typeName, for: saveOperation)
					completionHandler(nil)
				} catch let error {
					completionHandler(error)
				}
			}
		}
        else
        {
            do {
                try writeSafely(to: url, ofType: typeName, for: saveOperation)
                completionHandler(nil)
            } catch let error {
                completionHandler(error)
            }
        }
    }
    
    override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
		//	So we have a delegate but let super and our save() do what is necessary
		super.save(withDelegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
    }
    
    func cacheSettings(_ url : URL) {
        guard url != homeURL else { return }
        //  soft update fileURL to cache if needed
        if self.url != url { self.fileURL = url }
        defaults.set(self.dictionary(), forKey: url.absoluteString)
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
		if [k.ItemType,k.PlayType].contains(typeName) {
			if url.isFileURL, UserSettings.SecureFileEncoding.value {
				try super.write(to: url, ofType: typeName)
			}
			else
			{
				switch typeName {
				case k.ItemType:
					try NSDictionary(dictionary: self.playitem().dictionary()).write(to: url)
					
				case k.PlayType:
					var plists = [Dictionary<String,Any>]()

					if k.local == url.scheme {
						let paths = url.deletingPathExtension().pathComponents
						assert([k.asset,k.defaults].contains(paths[1]))
						let keyPath = paths[2]

						switch paths[1] {
						case k.asset:
							let message = String(format: "Unwriteable scheme: %@", url.absoluteString)
							fatalError(message)

						case k.defaults:
							items.saveToDefaults(keyPath)
							
						default:
							let message = String(format: "Unknown scheme: %@", paths[1])
							fatalError(message)
						}
					}
					else
					{
						for item in items {
							plists.append(item.dictionary())
						}
						
						try NSDictionary(dictionary: [k.Playlists:plists]).write(to: url)
					}
					
				default:
					fatalError("Unknown docGroup: \(docGroup.rawValue) in write(_,:)")
				}
			}
		}
		
		//	Regardless of URL, cache settings
		cacheSettings(url)
		
		//  When written, clear its change count
        self.updateChangeCount(.changeCleared)
    }
    
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
		if saveOperation == .saveOperation || !UserSettings.SecureFileEncoding.value {
			try write(to: url, ofType: typeName)
		}
		else
		{
            try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
        }
        updateChangeCount( [.saveOperation                  : .changeCleared,
                            .saveAsOperation                : .changeCleared,
                            .saveToOperation                : .changeCleared,
                            .autosaveElsewhereOperation     : .changeAutosaved,
                            .autosaveInPlaceOperation       : .changeAutosaved,
                            .autosaveAsOperation            : .changeAutosaved][saveOperation] ?? .changeCleared)
    }
    
    override var shouldRunSavePanelWithAccessoryView: Bool {
        get {
			return [.playitem,.playlist].contains(docGroup)
        }
    }
    
    override func makeWindowControllers() {
		let group = [ k.Helium, k.Helium, k.PlayName, k.PlayName, k.Release ][docGroup.rawValue] /// has to match docGroups ordering
        let identifier = String(format: "%@Controller", group)
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        let controller = storyboard.instantiateController(withIdentifier: identifier) as! NSWindowController
        self.addWindowController(controller)
        docController.addDocument(self)
    }
}


