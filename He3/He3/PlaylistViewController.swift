//
//  PlaylistViewController.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 2/15/17.
//  Copyright © 2017-2021 CD M Santiago. All rights reserved.
//
//  Kudos to Nate Thompson: Using Drag and Drop with NSTableview
//  https://www.natethompson.io/2019/03/23/nstableview-drag-and-drop.html

import Foundation
import AVFoundation
import AudioToolbox
import AppKit

extension NSPasteboard.PasteboardType {
    static let rowDragType = NSPasteboard.PasteboardType("com.slashlos.he3.rowDragDrop")
}

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}
fileprivate var docController : DocumentController {
    get {
        return NSDocumentController.shared as! DocumentController
    }
}

class PlayTableView : NSTableView {
	var _dragImage : NSImage?
	var  dragImage : NSImage {
		get {
			if  _dragImage == nil {
				_dragImage = NSImage.init(named: [k.listIcon,k.itemIcon][tag])!
			}
			return _dragImage!
		}
	}
	var pathExtension : String {
		get {
			return [k.hpl,k.hpi][tag]
		}
	}
	
	@objc @IBAction func delete(_ sender: Any?) {
		let delegate: PlaylistViewController = self.delegate as! PlaylistViewController
		
		delegate.removePlaylist(self)
	}
    /*
    override func mouseDragged(with event: NSEvent) {
        let delegate = self.delegate as! PlaylistViewController
        let arrayController = [delegate.playlistArrayController,delegate.playitemArrayController][self.tag]!
        let objects = arrayController.arrangedObjects as! [NSPasteboardWriting]
        let indexSet = self.selectedRowIndexes
        var items = [NSDraggingItem]()
        
        for index in indexSet {
            let object : AnyObject = (arrayController.arrangedObjects as! [AnyObject])[index]
            let item = NSDraggingItem.init(pasteboardWriter: objects[index])
            let dragImage = object.thumbnailImage.resize(w: 32, h: 32)
            item.setDraggingFrame(self.rect(ofRow: index), contents: dragImage)
            item.draggingFrame = self.rect(ofRow: index)
            items.append(item)
        }
        self.beginDraggingSession(with: items, event: event, source: self)
    }
    
    override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
		return context == .withinApplication ? .generic : .copy
    }

    override func dragImageForRows(with dragRows: IndexSet, tableColumns: [NSTableColumn], event dragEvent: NSEvent, offset dragImageOffset: NSPointPointer) -> NSImage {
        return dragImage.resize(w: 32, h: 32)
    }
    
    override func draggingEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard
        
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly.rawValue]) {
            return .copy
        }
        return .generic
    }
    */
    override func becomeFirstResponder() -> Bool {
        let notif = Notification(name: Notification.Name(rawValue: "NSTableViewSelectionDidChange"), object: self, userInfo: nil)
        (self.delegate as! PlaylistViewController).tableViewSelectionDidChange(notif)
        return true
    }
}

class PlayHeaderView : NSTableHeaderView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let action = #selector(PlaylistViewController.toggleColumnVisiblity(_ :))
        let target = self.tableView?.delegate
        let menu = NSMenu.init()
        var item: NSMenuItem
        
        //	We auto enable items as views present them
        menu.autoenablesItems = true
        
        //	TableView level column customizations
        for col in (self.tableView?.tableColumns)! {
            let title = col.headerCell.stringValue
            let state = col.isHidden
            
            item = NSMenuItem.init(title: title, action: action, keyEquivalent: "")
            item.image = NSImage.init(named: (state) ? "NSOnImage" : "NSOffImage")
            item.state = (state ? .off : .on)
            item.representedObject = col
            item.isEnabled = true
            item.target = target
            menu.addItem(item)
        }
        return menu
    }
}

class PlaylistViewController: NSViewController,NSTableViewDelegate,NSMenuDelegate,NSWindowDelegate {

    @objc @IBOutlet weak var playlistArrayController: NSArrayController!
    @objc @IBOutlet weak var playitemArrayController: NSArrayController!

    @objc @IBOutlet weak var playlistTableView: PlayTableView!
    @objc @IBOutlet weak var playitemTableView: PlayTableView!
    @objc @IBOutlet weak var playlistSplitView: NSSplitView!

    //  we are managing a local playlist, so include app delegate histories RONLY
	var ppc : PlaylistPanelController? {
		guard let wc = self.view.window?.windowController else { return nil }
		guard let ppc = wc as? PlaylistPanelController else { return nil }
		return ppc
	}
	
	var rvc : PlayItemAccessoryViewController {
		return self.view.window?.titlebarAccessoryViewControllers.first as! PlayItemAccessoryViewController
	}
	
	var isGlobalPlaylist : Bool {
		get {
			guard let doc = self.doc else { return false }
			return doc.isGlobalPlaylist
		}
	}

	var doc : Document? {
		get {
			guard let ppc = self.ppc else { return nil }
			if let doc = ppc.document as? Document {
				return doc
			}
			else
			{
				return nil
			}
		}
	}
	
    var progressIndicator: NSProgressIndicator!
	var dragSequenceNo = 0

    // Queue used for initially loading all the photos.
    var loaderQueue = OperationQueue()
    
    // Queue used for reading and writing file promises.
    var filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        return queue
    }()
    
    // The temporary directory URL used for accepting file promises.
    lazy var destinationURL: URL = {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        return destinationURL
    }()

    var shiftKeyDown : Bool {
        get {
			return (NSApp.delegate as! AppDelegate).shiftKeyDown
        }
    }
    
	@objc @IBAction func itemAction(_ sender: Any) {
		guard let playlist = playlistArrayController.selectedObjects.first as? PlayList else { return }
        // Renumber playlist items via array controller
        playitemTableView.beginUpdates()
        
        //  True - prune duplicates & publish, false resequence
        switch shiftKeyDown {
        case true:
			playlist.willChangeValue(forKey: k.tally)
            var seen = [String:PlayItem]()
            for (row,item) in (playitemArrayController.arrangedObjects as! [PlayItem]).enumerated().reversed() {
                if item.plays == 0 { item.plays = 1}
                if seen[item.name] == nil {
                    seen[item.name] = item
                }
                else
                {
                    //  always take first date of items
                    if let hist = seen[item.name] {
                        hist.date = min(hist.date,item.date)
                        hist.plays += item.plays
                    }
                    self.remove(item: item, atIndex: row)
                }
            }
            
            //  publish seen plays across playlists
            for  (name,hist) in seen {
                print("update '\(name)' -> \(hist)");
                for play in playlists {
                    if let item = play.list.link(hist.link.absoluteString), item.plays != hist.plays {
                        item.plays = hist.plays
                    }
                }
            }
			playlist.didChangeValue(forKey: k.tally)
            rvc.itemActionButton.needsDisplay = true

        case false:
            for (row,item) in (playitemArrayController.arrangedObjects as! [PlayItem]).enumerated() {
                if let undo = self.undoManager {
                    undo.registerUndo(withTarget: self, handler: { [oldValue = item.rank] (PlaylistViewController) -> () in
                        (item as AnyObject).setValue(oldValue, forKey: "rank")
                        if !undo.isUndoing {
                            undo.setActionName(String.init(format: "Reseq %@", "rank"))
                        }
                    })
                }
                item.rank = row + 1
            }
        }
        playitemTableView.endUpdates()
	}

	//  delegate keeps our parsing dict to keeps names unique
    //  PlayList.name.willSet will track changes in playdicts
    @objc dynamic var playlists = [PlayList]()
    @objc dynamic var playCache = [PlayList]()
    
    //  MARK:- Undo
    //  keys to watch for undo: PlayList and PlayItem
    var listIvars : [String] {
        get {
            return [k.name, k.list]
        }
    }
    var itemIvars : [String] {
        get {
			return [k.name, k.turl, k.date, k.time, k.rank, k.tRect, k.plays, k.label, k.hover, k.alpha, k.trans, k.agent]
        }
    }

    internal func observe(_ item: AnyObject, keyArray keys: [String], observing state: Bool) {
        switch state {
        case true:
            for keyPath in keys {
                item.addObserver(self, forKeyPath: keyPath, options: [.old,.new], context: nil)
            }
            
        case false:
            for keyPath in keys {
                item.removeObserver(self, forKeyPath: keyPath)
            }
        }
        //print(item, (state ? "YES" : "NO"))
    }
    
    //  Start or forget observing any changes
    var _observingState : Bool = false
    @objc dynamic var observing : Bool {
        get {
            return _observingState
        }
        set (state) {
            guard state != _observingState else { return }
            if state {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(optionKeyDown(_:)),
					name: .optionKeyDown,
                    object: nil)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(gotNewHistoryItem(_:)),
                    name: .playitem,
                    object: nil)
            }
            else
            {
                NotificationCenter.default.removeObserver(self)
            }

            self.observe(self, keyArray: [k.playlists], observing: state)
            for playlist in playlists {
                self.observe(playlist, keyArray: listIvars, observing: state)
                for item in playlist.list {
                    self.observe(item, keyArray: itemIvars, observing: state)
                }
            }
            
            _observingState = state
        }
    }
    
    @objc internal func optionKeyDown(_ note: Notification) {
		//	Don't bother unless we're a first responder
		guard self.view.window == NSApp.keyWindow, [playlistTableView,playitemTableView].contains(self.view.window?.firstResponder) else { return }

        let keyPaths = ["playToolTip"]
        for keyPath in (keyPaths)
        {
            self.willChangeValue(forKey: keyPath)
        }
        
        for keyPath in (keyPaths)
        {
            self.didChangeValue(forKey: keyPath)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let oldValue = change?[NSKeyValueChangeKey(rawValue: "old")]
        let newValue = change?[NSKeyValueChangeKey(rawValue: "new")]

        switch keyPath {
        
        case k.playlists?, k.list?:
            //  arrays handled by [add,remove]<List,Play> callback closure block

            if (newValue != nil) {
                print(String.init(format: "%p:%@ new %@", object! as! CVarArg, keyPath!, newValue as! CVarArg))
            }
            else
            if (oldValue != nil) {
                print(String.init(format: "%p:%@ old %@", object! as! CVarArg, keyPath!, oldValue as! CVarArg))
            }
            else
            {
                print(String.init(format: "%p:%@ unk %@", object! as! CVarArg, keyPath!, "*no* values?"))
            }
            
        default:

            if let undo = self.undoManager {
                
                //  scalars handled here with its matching closure block
                undo.registerUndo(withTarget: self, handler: { [oldValue] (PlaylistViewController) -> () in
                    
                    (object as AnyObject).setValue(oldValue, forKey: keyPath!)
                    if !undo.isUndoing {
                        undo.setActionName(String.init(format: "Edit %@", keyPath!))
                    }
                })
				
				// Save history info which might have changed
				if let play = (object as? PlayList), keyPath == k.name, play == historyCache {
					if UserSettings.HistoryName.value == oldValue as? String {
						UserSettings.HistoryName.value = newValue as! String
					}
				}
				print(String.init(format: "%@.%@ %@ -> %@", (object as AnyObject).name, keyPath!, oldValue as! CVarArg, newValue as! CVarArg))
            }
        }
        
        if let doc = self.view.window?.windowController?.document {
			print("doc changed")
			doc.updateChangeCount(.changeDone)
		}
    }
    
    var canRedo : Bool {
        if let redo = self.undoManager  {
            return redo.canRedo
        }
        else
        {
            return false
        }
    }
    @objc @IBAction func redo(_ sender: Any) {
        if let undo = self.undoManager, undo.canRedo {
            undo.redo()
            
            if let doc = self.view.window?.windowController?.document { doc.updateChangeCount(.changeRedone) }
            
            print("redo:");
        }
    }
    
    var canUndo : Bool {
        if let undo = self.undoManager  {
            return undo.canUndo
        }
        else
        {
            return false
        }
    }
    
    @objc @IBAction func undo(_ sender: Any) {
        if let undo = self.undoManager, undo.canUndo {
            undo.undo()
            
            if let doc = self.view.window?.windowController?.document { doc.updateChangeCount(.changeUndone) }

            print("undo:");
        }
    }
    
    //  MARK:- View lifecycle
    fileprivate func setupHiddenColumns(_ tableView: NSTableView, hideit: [String]) {
        let table : String = tableView.identifier!.rawValue
        for col in tableView.tableColumns {
            let column = col.identifier.rawValue
            let pref = String(format: "hide.%@.%@", table, column)
            var isHidden = false
            
            //    If have a preference, honor it, else apply hidden default
            if defaults.value(forKey: pref) != nil
            {
                isHidden = defaults.bool(forKey: pref)
                hiddenColumns[pref] = String(isHidden)
            }
            else
            if hideit.contains(column)
            {
                isHidden = true
            }
            col.isHidden = isHidden
        }
    }
    
    func setupProgressIndicator() {
        // Create the progress indicator for asyncronous copies of promised files.
        progressIndicator = NSProgressIndicator(frame: NSRect())
        progressIndicator.controlSize = .regular
        progressIndicator.sizeToFit()
        progressIndicator.style = .spinning
        progressIndicator.isHidden = true
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        // Center it to this view controller.
        NSLayoutConstraint.activate([
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
	
    override func viewDidLoad() {
		super.viewDidLoad()
		
		//	Defer document based actions until viewWillAppear()
		
		setupProgressIndicator()
		
        playlistTableView.registerForDraggedTypes(
            NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
		playlistTableView.registerForDraggedTypes([.rowDragType,.playlist,.playitem,.fileURL,.URL])

		playitemTableView.registerForDraggedTypes(
            NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
		playitemTableView.registerForDraggedTypes([.rowDragType,.playlist,.playitem,.fileURL,.URL])

        // Determine the kind of source drag originating from this app.
        // Note, if you want to allow your app to drag items to the Finder's trash can, add ".delete".
        playlistTableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        playitemTableView.setDraggingSourceOperationMask(.copy, forLocal: false)

        playlistTableView.doubleAction = #selector(doubleAction(_:))
        playitemTableView.doubleAction = #selector(doubleAction(_:))
        
        //  Restore hidden columns in tableviews using defaults
        setupHiddenColumns(playlistTableView, hideit: ["date","tally"])
        setupHiddenColumns(playitemTableView, hideit: ["date","link","plays","rect","label","hover","alpha","trans"])
    }
	
	fileprivate var appDelegate : AppDelegate {
		get {
			return NSApp.delegate as! AppDelegate
		}
	}
	
	var historyCache: PlayList {
		get {
			return appDelegate.historyCache
		}
	}
    
    override func viewWillAppear() {
		//	Guard 1-time loading post viewDidLoad() when document available
		guard !observing else { return }
		
        //  Load document's URL or globals already in items
		if let doc = self.doc {
			//	Prime global playlists
			playlistArrayController.add(contentsOf: doc.items)
		}

		//  Leave non-global extractions contents intact (RONLY but visible
		if isGlobalPlaylist {
			//  Prune stale history entries
			playlists.removeAll{$0 == historyCache}
			playlistArrayController.addObject(historyCache)
		}
		else
		if let doc = self.doc, let url = doc.fileURL {
			//  Set window titleView with url as tooltip like .helium type
			if let titleView = self.view.window?.standardWindowButton(.closeButton)?.superview {
				titleView.toolTip = url.absoluteString.removingPercentEncoding
			}

			//  Start us of cleanly re: change count
			doc.updateChangeCount(.changeCleared)
			self.undoManager?.removeAllActions()
		}
        
        // cache our list before editing
        playCache = playlists
        
        //  Reset split view dimensions
        self.playlistSplitView.setPosition(120, ofDividerAt: 0)
        
        //  Start observing any changes
        self.observing = true
		
		//	load our thumbnails for all our items
		if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
			for playlist in playlists {
				let loadThumbnails = LoadThumbnailssOperationFor(playlist: playlist)
				
				loadThumbnails.completionBlock = {
					OperationQueue.main.addOperation {
						for playitem in playlist.list {
							// Set up ourselves to be notified when this item's thumbnail is ready.
							playitem.thumbnailDelegate = self
						}
					}
				}
				self.loaderQueue.addOperation( loadThumbnails )
			}
		}
    }
    
    override func viewDidAppear() {
        print(String(format: "sheet? %@", sheetPresent ? "YEA" : "NEA"))
        let window = self.view.window!
        
        // Remember for later restoration
        NSApp.changeWindowsItem(window, title: window.title, filename: false)
    }
    
    override func viewWillDisappear() {
        //  Stop observing any changes
        self.observing = false
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    //  MARK:- Play list/item Actions
    //
    //  internal are also used by undo manager callback and by IBActions
    //
    //  Since we do *not* undo movements, we remove object *not* by their index
    //  but use their index to update the controller scrolling only initially.

    //  "Play" items are individual PlayItem items, part of a playlist
    internal func add(item: PlayItem, atIndex p_index: Int) {
        var index = p_index
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.remove(item: oldVals["item"] as! PlayItem, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Add PlayItem")
                }
            })
        }
        observe(item, keyArray: itemIvars, observing: true)
        if index > 0 && index < (playitemArrayController.arrangedObjects as! [PlayItem]).count {
            playitemArrayController.insert(item, atArrangedObjectIndex: index)
        }
        else
        {
            playitemArrayController.addObject(item)
            playitemArrayController.rearrangeObjects()
            let row = playitemTableView.selectedRow
            if row >= 0 {
                index = row
            }
            else
            {
                index = (playitemArrayController.arrangedObjects as! [PlayItem]).count
            }
        }
        DispatchQueue.main.async {
            self.playitemTableView.scrollRowToVisible(index)
        }
    }
    internal func remove(item: PlayItem, atIndex p_index: Int) {
        var index = p_index
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.add(item: oldVals["item"] as! PlayItem, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Remove PlayItem")
                }
            })
        }
        observe(item, keyArray: itemIvars, observing: false)
        playitemArrayController.removeObject(item)

        let row = playitemTableView.selectedRow
        if row >= 0 {
            index = row
        }
        else
        {
            index = max(0,min(index,(playitemArrayController.arrangedObjects as! [PlayItem]).count))
        }
        DispatchQueue.main.async {
            self.playitemTableView.scrollRowToVisible(index)
        }
    }

    //  "List" items are PlayList objects
    internal func add(list item: PlayList, atIndex p_index: Int) {
        var index = p_index
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.remove(list: oldVals["item"] as! PlayList, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Add PlayList")
                }
            })
        }
        observe(item, keyArray: listIvars, observing: true)
        if index > 0 && index < (playlistArrayController.arrangedObjects as! [PlayItem]).count {
            playlistArrayController.insert(item, atArrangedObjectIndex: index)
        }
        else
        {
            playlistArrayController.addObject(item)
            playlistArrayController.rearrangeObjects()
            index = (playlistArrayController.arrangedObjects as! [PlayItem]).count - 1
        }
        DispatchQueue.main.async {
            self.playlistTableView.scrollRowToVisible(index)
        }
    }
    internal func remove(list item: PlayList, atIndex index: Int) {
        if let undo = self.undoManager {
            undo.registerUndo(withTarget: self, handler: {[oldVals = ["item": item, "index": index] as [String : Any]] (PlaylistViewController) -> () in
                self.add(list: oldVals["item"] as! PlayList, atIndex: oldVals["index"] as! Int)
                if !undo.isUndoing {
                    undo.setActionName("Remove PlayList")
                }
            })
        }
        observe(item, keyArray: listIvars, observing: false)
        playlistArrayController.removeObject(item)
        
        DispatchQueue.main.async {
            self.playlistTableView.scrollRowToVisible(index)
        }
    }

    //  published actions - first responder tells us who called
    @objc @IBAction func addPlaylist(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder
        
        //  We want to add to existing play item list
        if whoAmI == playlistTableView {
            let item = PlayList()
            
            self.add(list: item, atIndex: -1)
        }
        else
        if let selectedPlaylist = playlistArrayController.selectedObjects.first as? PlayList {
            let list: Array<PlayItem> = selectedPlaylist.list.sorted(by: { (lhs, rhs) -> Bool in
                return lhs.rank < rhs.rank
            })
            let item = PlayItem()
            item.rank = (list.count > 0) ? (list.last?.rank)! + 1 : 1

            self.add(item: item, atIndex: -1)
        }
        else
        {
            print("firstResponder: \(String(describing: whoAmI))")
        }
    }
    @objc @IBOutlet weak var addButtonToolTip : NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                return "Add playlist"
            }
            else
            {
                return "Add playitem"
            }
        }
        set (value) {
            
        }
	}

    @objc @IBAction func removePlaylist(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder

        if playlistTableView == whoAmI {
            for item in (playlistArrayController.selectedObjects as! [PlayList]).reversed() {
                let index = (playlistArrayController.arrangedObjects as! [PlayList]).firstIndex(of: item)
                self.remove(list: item, atIndex: index!)
            }
            return
        }
            
        if playitemTableView == whoAmI {
            for item in (playitemArrayController.selectedObjects as! [PlayItem]).reversed() {
                let index = (playitemArrayController.arrangedObjects as! [PlayItem]).firstIndex(of: item)
                self.remove(item: item, atIndex: index!)
            }
            return
        }
        
        if playitemArrayController.selectedObjects.count > 0 {
            for item in (playitemArrayController.selectedObjects as! [PlayItem]) {
                let index = (playitemArrayController.arrangedObjects as! [PlayItem]).firstIndex(of: item)
                self.remove(item: item, atIndex: index!)
            }
        }
        else
        if playlistArrayController.selectedObjects.count > 0 {
            for item in (playlistArrayController.selectedObjects as! [PlayList]) {
                let index = (playlistArrayController.arrangedObjects as! [PlayList]).firstIndex(of: item)
                self.remove(list: item, atIndex: index!)
            }
        }
        else
        {
            print("firstResponder: \(String(describing: whoAmI))")
			NSSound.playIf(.sosumi)
        }
    }
    @objc @IBOutlet weak var removeButtonToolTip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Remove all playlists"
                }
                else
                {
                    return "Remove selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Remove playitem playitem(s)"
                }
                else
                {
                    return "Remove selected playitem(s)"
                }
            }
        }
        set (value) {
            
        }
	}

    // Our playlist panel return point if any
    var webViewController: WebViewController? = nil
    
    internal func play(_ sender: AnyObject, items: Array<PlayItem>, maxSize: Int) {
		var viewOptions = appDelegate.newViewOptions
        var firstHere = viewOptions == sameWindow

        //  Try to restore item at its last known location
        for (i,item) in (items.enumerated()).prefix(maxSize) {
            if firstHere {
                if let first = NSApp.keyWindow {
                    if let wvc = first.contentViewController as? WebViewController {
                        firstHere = !wvc.webView.next(url: item.link)
                    }
                }
                if !firstHere { continue }
            }

            if appDelegate.openURLInNewWindow(item.link) {
                print(String(format: "%3d %3d %@", i, item.rank, item.name))
				
				//  2nd item and on get a new view window
				viewOptions.insert(.w_view)
            }
        }
    }
    
    //  MARK:- IBActions
	@objc @IBAction func doubleAction(_ sender: AnyObject) {
        //  first responder tells us who called so dispatch
		
		//	Guard against "fat finger" events
		guard let whoami = self.view.window?.firstResponder as? PlayTableView else { return }
		guard whoami.selectedRowIndexes.count > 0, whoami.clickedRow >= 0 && whoami.clickedColumn >= 0 else { return }
		
		playPlaylist(sender)
		
		//  Unless we're the standalone helium playlist window dismiss all
		guard let window = NSApp.keyWindow, !window.className.hasSuffix("AlertPanel") else { return }
		
		if !(self.view.window?.isKind(of: Panel.self))! {
			/// dismiss whatever got us here
			super.dismiss(sender)

			//  If we were run modally as a window, close it
			//  current window to be reused for the 1st item
			if sender.isKind(of: NSTableView.self),
				let ppc = self.view.window?.windowController, ppc.isKind(of: PlaylistPanelController.self) {
				NSApp.abortModal()
				ppc.window?.orderOut(sender)
			}
		}
	}
	
    @objc @IBAction func playPlaylist(_ sender: AnyObject) {
        appDelegate.newViewOptions = appDelegate.getViewOptions
        
        //  first responder tells us who called so dispatch
        let whoAmI = self.view.window?.firstResponder

        //  Quietly, do not exceed program / user specified throttle
        let throttle = UserSettings.PlaylistThrottle.value

        //  Our rank sorted list from which we'll take last 'throttle' to play
        var list = Array<PlayItem>()

        if playitemTableView == whoAmI {
            print("We are in playitemTableView")
            list.append(contentsOf: playitemArrayController.selectedObjects as! Array<PlayItem>)
        }
        else
        if playlistTableView == whoAmI {
            print("We are in playlistTableView")
            for selectedPlaylist in (playlistArrayController.selectedObjects as? [PlayList])! {
                list.append(contentsOf: selectedPlaylist.list )
            }
        }
        else
        {
            print("firstResponder: \(String(describing: whoAmI))")
			NSSound.playIf(.sosumi)
            return
        }
        
        //  Do not exceed program / user specified throttle
        guard list.count > 0 else { return }
        if list.count > throttle {
            let message = String(format: "Limiting playlist(s) %ld items to throttle?", list.count)
            let infoMsg = String(format: "User defaults: %@ = %ld",
                                 UserSettings.PlaylistThrottle.keyPath,
                                 throttle)
            
				sheetOKCancel(message, info: infoMsg,
										  acceptHandler: { (button) in
											if button == NSApplication.ModalResponse.alertFirstButtonReturn {
												self.appDelegate.newViewOptions = self.appDelegate.getViewOptions
												self.play(sender, items:list, maxSize: throttle)
											}
            })
        }
        else
        {
            play(sender, items:list, maxSize: list.count)
        }
    }
    @objc @IBOutlet weak var playButtonToolTip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Play all playlists"
                }
                else
                {
                    return "Play selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Play playlist playitem(s)"
                }
                else
                {
                    return "Play selected playitem(s)"
                }
            }
        }
        set (value) {
            
        }
	}

    // Return notification from webView controller
    @objc func gotNewHistoryItem(_ note: Notification) {
        guard let playlist = playlistArrayController.selectedObjects.first as? PlayList else { return }

        //  If history is current playlist, add to the history
        if historyCache == playlist {
            self.add(item: note.object as! PlayItem, atIndex: -1)
        }
    }

	@IBAction func labelMenuPress(_ sender: NSMenuItem) {
		print("labelMenuPress: \(sender.tag)")
	}
	
	@objc @IBOutlet weak var restoreButton: NSButton!
    @objc @IBOutlet weak var restoreButtonToolTip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder

            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Restore all playlists"
                }
                else
                {
                    return "Restore selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Restore playlist playitem(s)"
                }
                else
                {
                    return "Restore selected playitem(s)"
                }
            }
        }
        set (value) {
            
        }
	}
	
	@objc @IBAction func revertDocumentToSaved(_ sender: Any?) {
        let whoAmI = self.view.window?.firstResponder
		var docName = "Global Playlist"
		
		if !isGlobalPlaylist, let url = doc!.fileURL { docName = "\"" + url.simpleSpecifier + "\"" }
		
		let message = "Do you want to revert the to the last saved version?"
		let infoMsg = isGlobalPlaylist ? "Global Playlist" : docName
		
        let alert = NSAlert()
		
        alert.messageText = message
        alert.addButton(withTitle: "Revert")
        alert.addButton(withTitle: "Cancel")
        alert.informativeText = infoMsg
        
        if let window = NSApp.keyWindow {
			alert.beginSheetModal(for: window, completionHandler: { [self] response in
				if response == NSApplication.ModalResponse.alertFirstButtonReturn {
					doc?.revertToSaved(sender)
					doc?.updateChangeCount(.changeCleared)
					
					(whoAmI as! PlayTableView).reloadData()
					print("revert to saved")
				}
            })
        }
        else
        {
			if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
				doc?.revertToSaved(sender)
				doc?.updateChangeCount(.changeCleared)
				
				(whoAmI as! PlayTableView).reloadData()
				print("revert to saved")
			}
		}
	}
	
    @objc @IBAction func restorePlaylists(_ sender: NSButton?) {
        let whoAmI = self.view.window?.firstResponder
		var names = Array<String>()

        //  We want to restore to existing play item or list or global playlists
        if whoAmI == playlistTableView || whoAmI == nil {
            
            let restArray = playlistArrayController.selectedObjects as! [PlayList]
            
            //  If no playlist(s) selection restore from defaults
            if restArray.count == 0 {
                if let plists = defaults.dictionary(forKey: k.playlists) {
                    playlists = [PlayList]()
                    for (name,plist) in plists {
                        guard let items = plist as? [Dictionary<String,Any>] else {
                            let item = PlayItem(from: (plist as? Dictionary<String,Any>)!)
                            let playlist = PlayList()
                            playlist.list.append(item)
                            playlists.append(playlist)
                            continue
                        }
                        var list : [PlayItem] = [PlayItem]()
                        for plist in items {
                            let item = PlayItem(from: plist)
                            list.append(item)
                        }
                        let playlist = PlayList(name: name, list: list)
                        playlistArrayController.addObject(playlist)
						names.append(name)
                    }
                }
            }
            else
            {
                for playlist in restArray {
                    if let plists = defaults.dictionary(forKey: playlist.name as String) {
                        
                        //  First update matching playitems
                        playlist.update(with: plists)
                        
                        //  Second, using plist, add playitems not found in playlist
                        if let value = plists[k.list], let dicts = value as? [[String:Any]]  {
                            for dict in dicts {
                                if !playlist.list.has(dict[k.link] as! String) {
                                    let item = PlayItem(from: dict)
                                    self.add(item: item, atIndex: -1)
                                }
                            }
                            
                            //  Third remove playitems not found in plist
                            for playitem in playlist.list {
                                var found = false

                                for dict in dicts {
                                    if playitem.link.absoluteString == (dict[k.link] as? String) { found = true; break }
                                }

                                if !found {
                                    remove(item: playitem, atIndex: -1)
                                }
                            }
                        }
						names.append(playlist.name)
                    }
                }
            }
			userAlertMessage("Reverted playlist(\(names.count))", info: names.count > 9 ? nil : names.listing)
        }
        else
        {
            var itemArray = playitemArrayController.selectedObjects as! [PlayItem]
            
            if itemArray.count == 0 {
                itemArray = playitemArrayController.arrangedObjects as! [PlayItem]
            }
            
            for playitem in itemArray {
                if let dict = defaults.dictionary(forKey: playitem.link.absoluteString) {
                    playitem.update(with: dict)
					names.append(playitem.name)
                }
            }
			userAlertMessage("Reverted playitem(\(names.count))", info: names.count > 9 ? nil : names.listing)
        }
    }

    @objc @IBOutlet weak var saveButton: NSButton!
    @objc @IBOutlet weak var saveButtonToolTip: NSString! {
        get {
            let whoAmI = self.view.window?.firstResponder
            
            if whoAmI == playlistTableView || whoAmI == nil {
                if playlistArrayController.selectedObjects.count == 0 {
                    return "Save all playlists"
                }
                else
                {
                    return "Save selected playlist(s)"
                }
            }
            else
            {
                if playitemArrayController.selectedObjects.count == 0 {
                    return "Save playlist playitem(s)"
                }
                else
                {
                    return "Save selected playitem(s)"
                }
            }
        }
        set (value) {
            
        }
	}
    
    @objc @IBAction func savePlaylists(_ sender: AnyObject) {
        let whoAmI = self.view.window?.firstResponder
        
        //  We want to save to existing play item or list
        if whoAmI == playlistTableView {
            let saveArray = playlistArrayController.selectionIndexes.count == 0
                ? playlistArrayController.arrangedObjects as! [PlayList]
                : playlistArrayController.selectedObjects as! [PlayList]
            var names = Array<String>()
            
            for playlist in saveArray {
                defaults.set(playlist.dictionary(), forKey: playlist.name as String)
                names.append(playlist.name)
                
                //  propagate history to our delegate
                if playlist == historyCache { appDelegate.histories = historyCache.list }
            }
			userAlertMessage("Saved playlist(\(names.count))", info: names.count > 3 ? nil : names.listing)
        }
        else
        {
            var saveArray = playitemArrayController.selectedObjects as! [PlayItem]
            var names = Array<String>()

            if saveArray.count == 0 {
                saveArray = playitemArrayController.arrangedObjects as! [PlayItem]
            }

            for playitem in saveArray {
                defaults.set(playitem.dictionary(), forKey: playitem.link.absoluteString)
                names.append(playitem.name)
            }
            userAlertMessage("Saved playitem(\(names.count))", info: (names.count > 3) ? nil : names.listing)
        }

        defaults.synchronize()
    }
    
    @objc @IBAction override func dismiss(_ sender: Any?) {
        super.dismiss(sender)
        
        //  If we were run as a window, close it
        if let plw = self.view.window, plw.isKind(of: PlaylistsPanel.self) {
            plw.orderOut(sender)
        }
        
        //  Save or go
        switch (sender! as AnyObject).tag == 0 {
		case true:
			// Always prune history entry(s)
			playlists.removeAll{$0 == historyCache}

			// Save to the cache
			playCache = playlists
			
			// If local save that too
			if let doc = self.doc { doc.items = playlists; doc.save(sender) }
		
		case false:
			// Restore NON-HISTORY playlist(s) from cache
			playCache.removeAll{$0 == historyCache}
			
			playlists = playCache
        }
    }

    @objc dynamic var hiddenColumns = Dictionary<String, Any>()
    @objc @IBAction func toggleColumnVisiblity(_ sender: NSMenuItem) {
        let col = sender.representedObject as! NSTableColumn
        let table : String = (col.tableView?.identifier)!.rawValue
        let column = col.identifier.rawValue
        let pref = String(format: "hide.%@.%@", table, column)
        let isHidden = !col.isHidden
        
        hiddenColumns.updateValue(String(isHidden), forKey: pref)
        defaults.set(isHidden, forKey: pref)
        col.isHidden = isHidden
    }
	
	@IBAction func itemHoverChange(_ sender: NSSegmentedControl) {
		let item = playitemArrayController.selectedObjects.first as! PlayItem
		
		item.hover = sender.selectedTag()
	}
	
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.title.hasPrefix("Redo") {
            menuItem.isEnabled = self.canRedo
        }
        else
        if menuItem.title.hasPrefix("Undo") {
            menuItem.isEnabled = self.canUndo
        }
        else
        if (menuItem.representedObject as AnyObject).isKind(of: NSTableColumn.self)
        {
            return true
        }
        else
        {
            switch menuItem.title {
			case "Revert To Saved…":
				if isGlobalPlaylist {
					menuItem.isEnabled = true
				}
				else
				if let document = self.view.window?.windowController?.document {
					menuItem.isEnabled = document.hasUnautosavedChanges
				}
				break
				
            default:
				print("pl \(menuItem.title)")
                menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
            }
        }
        return true;
    }

    //  MARK:- Delegate
    //  when on a sheet, cannot alter histories
    var sheetPresent : Bool {
        get {
            return self.view.window?.sheetParent != nil
        }
    }
	
	private func tableViewColumnDidResize(notification: NSNotification ) {
        // Pay attention to column resizes and aggressively force the tableview's cornerview to redraw.
		rvc.view.needsDisplay = true
    }
    
    func tableView(_ tableView: NSTableView, dataCellFor tableColumn: NSTableColumn?, row: Int) -> NSCell? {
        guard let column = tableColumn else { return nil }

        let item : AnyObject = ([playlistArrayController,playitemArrayController][tableView.tag]?.arrangedObjects as! [AnyObject])[row]
        let data : NSCell = column.dataCell(forRow: row) as! NSCell
        guard let cell = data as? NSTextFieldCell else { return data }
        
        cell.font = .systemFont(ofSize: -1)

        //  if we have a url show histories in italics
        if tableView.tag == 1 {
            let list : AnyObject = (playlistArrayController.arrangedObjects as! [AnyObject])[playlistArrayController.selectionIndex]
            if !isGlobalPlaylist, list.name == UserSettings.HistoryName.value {
                cell.font = NSFont.init(name: "Helvetica Oblique", size: -1)
            }
        }
        
        guard tableView.tag == 0, !isGlobalPlaylist, item.name == UserSettings.HistoryName.value else { return cell }

        cell.font = NSFont.init(name: "Helvetica Oblique", size: -1)
        
        return cell
    }
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let tag = tableView.tag
		
		if let column = tableColumn {
			let view = tableView.makeView(withIdentifier: column.identifier, owner: self)
			let item = ([playlistArrayController,playitemArrayController][tag]?.arrangedObjects as! [AnyObject])[row]
			let textView : NSTableCellView? = view as? NSTableCellView
			
			//	Default font for text field
			if let field = textView?.textField {
				field.font = .systemFont(ofSize: -1)
				field.isEditable = true
			}
			
			switch tag {
			case 0:
				if isGlobalPlaylist, item as! NSObject == historyCache {
					if let field = textView?.textField {
						field.font = NSFont.init(name: "Helvetica Oblique", size: -1)
						field.isEditable = false
					}
				}

			case 1:
				let list : AnyObject = playlistArrayController.selectedObjects.first as AnyObject
				if isGlobalPlaylist, list as! NSObject == historyCache {
					if let field = textView?.textField {
						field.font = NSFont.init(name: "Helvetica Oblique", size: -1)
						field.isEditable = false
					}
				}
				
				if [.rank,.name].contains(column.identifier) {
					view?.toolTip = item.turl
				}

			default:
				break
			}
			
			return view
		}
		return nil
	}
	
    //  We cannot alter a playitem once plays is non-zero; set to zero to alter
	@objc func textFieldShouldBecomeEditable(_ textField: PlayTableTextField) -> Bool {
		let tableView = textField.superview?.superview?.superview as! PlayTableView
		let item = (textField.superview as! PlayTableCellView).objectValue
		let tableColumn = textField.tableColumn!
		
		if tableView == playlistTableView, let playlist : PlayList = item as? PlayList {
			guard playlist != historyCache else { return false }
			return tableColumn.identifier == .name
		}
		else
		if tableView == playitemTableView, let playitem : PlayItem = item as? PlayItem {
			let virgin = playitem.plays == 0

			///guard playitem.name != UserSettings.HistoryName.value else { return false }
			
			switch tableColumn.identifier {
			case .link:
				return !virgin && !appDelegate.isSandboxed && !appDelegate.isBookmarked(playitem.link)
				
			case .plays:
				return true
				
			default:
				return virgin || ![.link,.plays].contains(tableColumn.identifier)
			}
		}
		else
		{
			return false
		}
	}
	
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
		guard let column = tableColumn else { return false }
        if tableView == playlistTableView {
            let list : AnyObject = (playlistArrayController.arrangedObjects as! [AnyObject])[playlistArrayController.selectionIndex]
            
			guard list.name != UserSettings.HistoryName.value else { return false }
            return column.identifier == .name
        }
        else
        if tableView == playitemTableView {
            let item : AnyObject = (playitemArrayController.arrangedObjects as! [AnyObject])[row]
			let virgin = (item as! PlayItem).plays == 0

            guard item.name != UserSettings.HistoryName.value else { return false }
			
			switch column.identifier {
			case .link:
				return !virgin && !appDelegate.isSandboxed
				
			case .plays:
				return true
				
			default:
				return virgin || ![.link,.plays].contains(tableColumn?.identifier)
			}
        }
        else
        {
            return false
        }
    }
	
	@IBAction func OnEnterInTextField(_ sender: Any) {
		let whoAmI = self.view.window?.firstResponder
		
		if whoAmI == playlistTableView {
			print("playlist")
		}
		else
		{
			print("playitem")
		}
		
		if let textField = sender as? NSTextField {
			let row = self.playitemTableView.row(for: sender as! NSView)
			///let col = self.playitemTableView.column(for: sender as! NSView)
			let item = (playitemArrayController.arrangedObjects as! [PlayItem])[row]
			let data = textField.stringValue
			
			print("old \(item.link.absoluteString)")
			print("new \(data)")
		}
		else
		{
			let type = (sender as AnyObject).className
			print("sender \(String(describing: type))")
		}
	}
	
    func tableView(_ tableView: NSTableView, toolTipFor cell: NSCell, rect: NSRectPointer, tableColumn: NSTableColumn?, row: Int, mouseLocation: NSPoint) -> String {
        if tableView == playlistTableView
        {
            let play = (playlistArrayController.arrangedObjects as! [PlayList])[row]

            return play.tooltip as String
        }
        else
        if tableView == playitemTableView
        {
            let item = (playitemArrayController.arrangedObjects as! [PlayItem])[row]
            guard !shiftKeyDown else {
                return String(format: "%d play(s)", item.plays) }
            
			let temp = item.turl

            if item.name == "search", let args = temp.split(separator: "=").last?.removingPercentEncoding
            {
                return args
            }
            else
            if let temp = temp.removingPercentEncoding
            {
                return temp
            }
        }
        return "no tip for you"
    }
	
    func tableViewSelectionDidChange(_ notification: Notification) {
        //  Alert tooltip changes when selection does in tableView
        let buttons = [ "add", "remove", "play", "restore", "save"]
        let tableView : NSTableView = notification.object as! NSTableView
        let hpc = tableView.delegate as! PlaylistViewController
//        print("change tooltips \(buttons)")
        for button in buttons {
            hpc.willChangeValue(forKey: String(format: "%@ButtonToolTip", button))
        }
        ;
        for button in buttons {
            hpc.didChangeValue(forKey: String(format: "%@ButtonToolTip", button))
        }
    }
}

// MARK: - ThumbnailDelegate

extension PlaylistViewController: ThumbnailDelegate {
    
    func thumbnailDidFinish(_ playitem: PlayItem) {
        // Finished with generating thumbnail for this playitem.
		let objects : [PlayItem] = playitemArrayController?.arrangedObjects as! [PlayItem]
		
        // Find the row to update the thumbnail.
		if let itemRow = objects.firstIndex(of: playitem) {
            // Update the table row.
            playitemTableView.reloadData(forRowIndexes: IndexSet(integer: itemRow), columnIndexes: IndexSet(integer: 0))
        }
    }
}
