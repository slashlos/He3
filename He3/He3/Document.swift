//
//  Document.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 6/27/17.
//  Copyright © 2017-2020 CD M Santiago. All rights reserved.
//
//  Document instance read/save/write are to default; use super for files

fileprivate var appDelegate : AppDelegate {
    get {
        return NSApp.delegate as! AppDelegate
    }
}

import Cocoa
import Foundation
import QuickLook
import ServiceManagement

// Document type
struct DocGroup : OptionSet {
    let rawValue: Int

    static var helium    = DocGroup(rawValue: 0)
    static let playlist  = DocGroup(rawValue: 1)
}
let docHelium : ViewOptions = []

let docGroups = [k.Helium, k.Playlist]
let docNames = [k.Helium, k.Playlist]

extension NSPasteboard.PasteboardType {
    static let docDragType = NSPasteboard.PasteboardType("com.slashlos.docDragDrop")
}

class Document : NSDocument {
    var appDelegate: AppDelegate = NSApp.delegate as! AppDelegate
    override class var autosavesInPlace: Bool {
        return false
    }
    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        
        //  Update UI (red dot in close button) immediately
        if let hpc = he3PanelController, let hoverBar = hpc.hoverBar {
            hoverBar.closeButton?.needsDisplay = true
        }
    }
    var docController : DocumentController {
        get {
            return NSDocumentController.shared as! DocumentController
        }
    }
    var defaults = UserDefaults.standard
    var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
    }
    var settings: Settings
    var items: [PlayList]
    var contents: Any?
    
    var docGroup : DocGroup {
        get {
            if let fileType = self.fileType {
				let typeGroup = [k.Playlist,k.Playitem].contains(fileType) ? k.Playlist : k.Helium
                return DocGroup(rawValue: docGroups.firstIndex(of: typeGroup) ?? DocGroup.helium.rawValue)
            }
            else
            {
                return .helium
            }
        }
    }
    
    var he3PanelController : HeliumController? {
        get {
            guard let hpc : HeliumController = windowControllers.first as? HeliumController else { return nil }
            return hpc
        }
    }
    var homeURL : URL {
        get {
            guard let hpc = he3PanelController else { return URL.init(string: UserSettings.HomePageURL.value)! }
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
            if let hpc = he3PanelController, let webView = hpc.webView
            {
                return webView.url
            }
            else
            {
                return homeURL
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
        let item = PlayItem.init()
        item.name = self.displayName
        if let fileURL = self.fileURL { item.link = fileURL }
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
            if let window = self.windowControllers.first?.window {
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
            if let hpc = he3PanelController, let webView = hpc.webView {
                webView.customUserAgent = agent
            }
        }
        self.updateChangeCount(.changeDone)
    }
    
    func update(to url: URL) {
        self.fileURL = url
        
        if let dict = defaults.dictionary(forKey: url.absoluteString) {
            let item = PlayItem.init(with: dict)
            
            if item.rect != NSZeroRect {
                self.settings.rect.value = item.rect
                self.updateChangeCount(.changeDone)
             }
        }
        if url.isFileURL { _displayImage = nil }
    }
    func update(with item: PlayItem) {
        self.restoreSettings(with: item.dictionary())
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
				return NSImage.init(named: k.docIcon)!

            default:
                guard _displayImage == nil else { return _displayImage! }
                
                guard let url = self.fileURL, url.isFileURL else { return NSImage.init(named: k.docIcon)! }
				let asIcon = true /// we want typical icon decor
				let dict = [
					kQLThumbnailOptionIconModeKey: NSNumber(booleanLiteral: asIcon)
				] as CFDictionary
				let size = NSSize.init(width: 32.0, height: 32.0)
                    
                let ref = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL , size, dict)
                if let cgImage = ref?.takeUnretainedValue() {
                    _displayImage = NSImage(cgImage: cgImage, size: size)
					ref?.release()
                    return _displayImage!
				}
				else
				if let fileURL = self.fileURL
				{
					// If we couldn't get a Quick Look preview, fall back on the file's Finder icon.
					let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
					
					return icon
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
				return [k.AppLogo,super.displayName][docGroup.rawValue]
			}
            if fileURL.isFileURL
            {
                return fileURL.deletingPathExtension().lastPathComponent
            }
            else
            if k.caches == fileURL.scheme {
                let paths = fileURL.pathComponents
                let cache = paths[1]
                let stamp = paths[2]

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
            self.updateChangeCount(.changeDone)
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
            try self.init(contentsOf: url, ofType: url.pathExtension == k.hpl ? k.Playlist : k.Helium)
        }
    }
    
    convenience init(contentsOf url: URL, ofType typeName: String) throws {
        //  Record url and type, caller will load via notification
        do {
            self.init()

            fileURL = url
            fileType = typeName
        }
    }
    
    override func data(ofType typeName: String) throws -> Data {
        var array = [PlayList]()

        switch docGroup {
        case .playlist:
            //  Write playlists, history and searches
              
            // Save playlists - no maximum
            array += items
            
            // Save histories - no maximum
            array.append(PlayList.init(name: UserSettings.HistoryList.keyPath , list: appDelegate.histories))

            //  Save searches - no maximum
            array.append(PlayList.init(name: UserSettings.SearchNames.keyPath, list: appDelegate.webSearches))
 
        default:
            array.append(PlayList.init(name: displayName, list: [playitem()]))
        }

        return KeyedArchiver.archivedData(withRootObject: array)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        
        do {
			let pdata = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [PlayList.self,PlayItem.self], from: data)
            guard let plists : [PlayList] = pdata as? [PlayList] else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
            }
            
            //  files are [playlist] extractions, presented as a sheet or window
            items.append(contentsOf: plists)

            switch docGroup {
            case .playlist:
                 break
                
            default:
                for (i,item) in items.enumerated() {
                    switch i {
                    case 0:
                        restoreSettings(with: item.dictionary())
                        fileURL = item.list.first?.link
                        
                    default:
                        Swift.print("\(i) -> \(item.description)")
                    }
                }
            }
        }
        catch let error {
            Swift.print("\(error.localizedDescription)")
        }
    }

    override func read(from url: URL, ofType typeName: String) throws {
        
        if let dict = defaults.dictionary(forKey: url.absoluteString) {
            restoreSettings(with: dict)
        }
        
        switch docGroup {
        case .playlist:
            try super.read(from: url, ofType: typeName)

        default:
            if url.isFileURL, [k.hpi].contains(url.pathExtension) {
                try super.read(from: url, ofType: typeName)
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
            return
        }

        //  non-file revert handling, either defaults or an asset
        switch docGroup {
        case .playlist:
            let pvc : PlaylistViewController = windowControllers.first!.contentViewController as! PlaylistViewController

            //  Since we're reverting, use the stored version
            pvc.playlists = appDelegate.restorePlaylists()
            pvc.playlistArrayController.content = pvc.playlists
            
        default:
            break
        }
    }
    
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {

        //  Defer custom setups until we have a webView
        if [k.Custom].contains(typeName) { return }

        //  revert() should call read(data) then restore controller later
        
        switch docGroup {

        case .playlist:
            let pvc : PlaylistViewController = windowControllers.first!.contentViewController as! PlaylistViewController
            
            if let dict = defaults.dictionary(forKey: url.absoluteString) {
                restoreSettings(with: dict)
            }
            
            try super.revert(toContentsOf: url, ofType: typeName)
            pvc.playlistArrayController.content = pvc.playlists
            
        default:
            try read(from: url, ofType: typeName)
        }
    }
    
    @objc @IBAction override func save(_ sender: (Any)?) {
        
        if let url = url, url.isFileURL, [k.hpi,k.hpl].contains(url.pathExtension) {
            super.save(sender)
        }
        else
        {
            do {
                switch docGroup {
                case .playlist:
                    appDelegate.savePlaylists(self)
                    
                default:
                    if let url = fileURL, let type = fileType {
                        try self.write(to: url, ofType: type)
                    }
                    else
                    {
                        cacheSettings(fileURL ?? homeURL)
                    }
                }
                updateChangeCount(.changeCleared)
            } catch let error {
                NSApp.presentError(error)
            }
        }
    }
    
    @objc @IBAction override func saveAs(_ sender: Any?) {
        if let window = windowControllers.first?.window {
            let savePanel = NSSavePanel()
            let fileType = self.fileType!
            savePanel.allowedFileTypes = [self.fileNameExtension(forType: fileType, saveOperation: .saveAsOperation)!]
            
            savePanel.beginSheetModal(for: window, completionHandler: { (result: NSApplication.ModalResponse) in
                if result == .OK {
                    do {
                        if let saveURL = savePanel.url {
                            try super.write(to: saveURL, ofType: fileType)
                            if saveURL.hideFileExtensionInPath() {
                                self.updateChangeCount(.changeCleared)
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
        guard url != homeURL else {
            cacheSettings(url)
            updateChangeCount(.changeCleared)
            return
        }

        if url.isFileURL, [k.hpi,k.hpl].contains(url.pathExtension) {
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
    
    override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        save(self)
    }
    
    func cacheSettings(_ url : URL) {
        guard url != homeURL else { return }
        //  soft update fileURL to cache if needed
        if self.url != url { self.fileURL = url }
        defaults.set(self.dictionary(), forKey: url.absoluteString)
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        switch docGroup {
        case .playlist:
            appDelegate.savePlaylists(self)
            
        default:
            cacheSettings(url)
            
            //  When a document is written, update its global play items
            UserDefaults.standard.synchronize()
        }
        self.updateChangeCount(.changeCleared)
    }
    
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        if url.isFileURL, [k.hpi,k.hpl].contains(url.pathExtension) {
            try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
        }
        else
        {
            try write(to: url, ofType: typeName)
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
            return docGroup == .playlist
        }
    }
    
    override func makeWindowControllers() {
        let group = [ k.Helium, k.Playlist ][docGroup.rawValue]
        let identifier = String(format: "%@Controller", group)
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        let controller = storyboard.instantiateController(withIdentifier: identifier) as! NSWindowController
        self.addWindowController(controller)
        docController.addDocument(self)
    }
}


