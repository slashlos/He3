//
//  PanelController.swift
//  He3 (Helium)
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017-2020 CD M Santiago. All rights reserved.
//

import AppKit

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )
        self.init(red: components.R, green: components.G, blue: components.B, alpha: alpha)
    }
}

class HeliumController : NSWindowController,NSWindowDelegate,NSFilePromiseProviderDelegate,NSDraggingSource,NSPasteboardWriting {
    var webViewController: WebViewController {
        get {
            return self.window?.contentViewController as! WebViewController
        }
    }
    var webView: MyWebView? {
        get {
            return self.webViewController.webView
        }
    }
    fileprivate var panel: Panel! {
        get {
            return (self.window as! Panel)
        }
    }
    var incognito : Bool {
        get {
            guard let webView = webView else { return false }
            return webView.incognito
        }
    }
    var homeURL : URL {
        get {
 			let url = UserSettings.UseLocalAssets.value
 				?	URL.init(string: incognito ? UserSettings.LocalStrkURL.value : UserSettings.LocalPageURL.value)!
 				:	URL.init(string: incognito ? UserSettings.HomeStrkURL.value  : UserSettings.HomePageURL.value)!
 			return url
        }
    }
    var homeColor : NSColor {
        get {
            return  NSColor(hex: incognito ? 0x0000FF : 0x3399FF)
        }
    }

	var appDelegate : AppDelegate {
		get {
			return NSApp.delegate as! AppDelegate
		}
	}
	
    // MARK: Window lifecycle
	
    override func windowDidLoad() {
        super.windowDidLoad()
        
        //  Default to not dragging by content
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        
        //  We want to allow miniaturizations, at least
        self.panel.styleMask.formUnion(.miniaturizable)
		
		//	Make title text stand out?
		self.panel.appearance = NSAppearance(named: .vibrantDark)
		self.panel.titlebarAppearsTransparent = true
		self.panel.titleVisibility = .visible
		self.panel.backgroundColor = .white
		
		//	Setup our preferences accessory view and toolbar

		let rvc = storyboard!.instantiateController(withIdentifier: "RightSideAccesoryViewController") as! NSTitlebarAccessoryViewController
		rvc.layoutAttribute = .trailing
		rvc.isHidden = false
		self.panel.addTitlebarAccessoryViewController(rvc)
		preferencesViewController = rvc
		
		//	Initially do not show toolbar
		if let toolbar = self.panel.toolbar { toolbar.isVisible = showToolbar }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumController.didBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumController.willResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HeliumController.didUpdateURL(note:)),
            name: NSNotification.Name(rawValue: "DidUpdateURL"),
            object: nil)
		
        //  Quick Quiet notification
        NotificationCenter.default.addObserver(
            self,
			selector: #selector(HeliumController.quickQuiet(_:)),
            name: NSNotification.Name(rawValue: "quickQuiet"),
            object: nil)

        //  Monitor AutoHideTitle preference
        NotificationCenter.default.addObserver(
            self,
			selector: #selector(HeliumController.autoHideTitleBar(_:)),
            name: NSNotification.Name(rawValue: "autoHideTitleBar"),
            object: nil)
		
		//  We allow drag from title's document icon to self or Finder
        panel.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
		panel.registerForDraggedTypes([.rowDragType, .fileURL, .string])
        panel.windowController?.shouldCascadeWindows = true///offsetFromKeyWindow()

        // Remember for later restoration
        NSApp.changeWindowsItem(panel, title: panel.title, filename: false)
		
		installTitleHider(true)
    }

    override var document: AnyObject? {
        didSet {
            if let document = self.document, let webView = self.webView {
                webView.incognito = document.fileType == k.Incognito
                documentDidLoad()
            }
        }
    }
        
    func documentDidLoad() {
        // Moved later, called by view, when document is available
        mouseOver = false

        setFloatOverFullScreenApps()
        
        willUpdateTitleBar()
        
        willUpdateTranslucency()
        
        willUpdateAlpha()
		
		installTitleFader(true)
    }
    
    func windowDidMove(_ notification: Notification) {
        if let sender : NSWindow = notification.object as? NSWindow, sender == self.window {
			if let doc = self.doc {
				doc.settings.rect.value = sender.frame
			}
			else
			{
				self.settings.rect.value = sender.frame
			}
             
            if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
        }
    }
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if sender == self.window {
			if let doc = self.doc {
				doc.settings.rect.value = sender.frame
			}
			else
			{
				self.settings.rect.value = sender.frame
			}

            if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
        }
        return frameSize
    }
    
    func windowWillClose(_ notification: Notification) {
        self.webViewController.webView.stopLoading()
     }
	
	// MARK:- TOOO dock tile updating when minimized?
	var dockTileImageView = NSImageView.init()
	var dockTileUpdateTimer: Timer?
	func windowWillMiniaturize(_ notification: Notification) {
		guard let window = notification.object as? NSWindow else { return }
		
		if let timer = dockTileUpdateTimer, timer.isValid { timer.invalidate() }
		self.dockTileUpdateTimer = Timer.scheduledTimer(withTimeInterval: 6.49, repeats: true, block: { (timer) in
			if timer.isValid, let webView = self.webView, window.isMiniaturized, let tile = self.window?.dockTile.contentView  {
				DispatchQueue.main.async {
					if let image = window.contentView?.snapshot {
						self.dockTileImageView.image = image.resize(size: tile.bounds.size)
						window.dockTile.contentView = self.dockTileImageView
						print("miniUpdate: \(image.alignmentRect)")
					}
					else
					{
						webView.takeSnapshot(with: nil) { image, error in
							guard nil == error else {
								print("webvUpdate: \(String(describing: error?.localizedDescription))")
								return
							}
							if let image = image {
								self.dockTileImageView.image = image.resize(size: tile.bounds.size)
								window.dockTile.contentView = self.dockTileImageView
								print("webvUpdate: \(image.alignmentRect)")
							}
						}
					}
				}
			}
		})
        if let timer = self.dockTileUpdateTimer { RunLoop.current.add(timer, forMode: .common) }
	}
	func windowDidDeminiaturize(_ notification: Notification) {
		self.window?.dockTile.contentView = nil
		dockTileUpdateTimer?.invalidate()
		dockTileUpdateTimer = nil
	}
	
    // MARK:- Mouse events
	var closeButton : NSButton? {
		get {
			return self.window?.standardWindowButton(.closeButton)
		}
	}
	var miniaturizeButton : NSButton? {
		get {
			return self.window?.standardWindowButton(.miniaturizeButton)
		}
	}
	var zoomButton : NSButton? {
		get {
			return self.window?.standardWindowButton(.zoomButton)
		}
	}
	
	var titleView : NSView? {
		get {
			return self.window?.standardWindowButton(.closeButton)?.superview
		}
	}
	var contentView : NSView? {
		get {
			return self.window?.contentView
		}
	}

	var wholeTrackingTag: NSView.TrackingRectTag?
	var titleTrackingTag: NSView.TrackingRectTag?
	var fadeTimer : Timer? = nil
	var hideTimer : Timer? = nil
	
	dynamic var priorIdle: Bool = true
	dynamic var mouseIdle: Bool = false {
		willSet {
			priorIdle = mouseIdle
		}
		didSet {
			mouseStateChanged()
		}
	}
	dynamic var priorOver: Bool = false
	dynamic var mouseOver: Bool = false {
		willSet {
			priorOver = mouseOver
		}
		didSet {
			mouseIdle = false
			mouseStateChanged()
		}
	}
	
	fileprivate func monitoringMouseEvents() -> Bool {
		guard !self.isKind(of: ReleaseController.self) else { return false }

		return UserSettings.AutoHideTitle.value ||
			autoHideTitlePreference != .never || translucencyPreference != .never
	}
	
	fileprivate func installTitleFader(_ fadeNow: Bool = false) {
		guard !self.isKind(of: ReleaseController.self),
			autoHideTitlePreference != .never else {
			NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.5
				
				self.titleView?.animator().isHidden = false
				///self.window?.animator().titlebarAppearsTransparent = false
				self.window?.animator().titleVisibility = .visible
				self.window?.animator().toolbar?.isVisible = showToolbar
			})
			return
		}
		let fadeMe = !self.mouseOver || self.mouseIdle
		let fadeSecs = self.window?.toolbar?.isVisible ?? false ? 9.49 : 3.97

		if fadeNow {
			NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.5
				
				self.titleView?.animator().isHidden = fadeMe
				///self.window?.animator().titlebarAppearsTransparent = hideMe
				self.window?.animator().titleVisibility = !self.mouseOver || self.mouseIdle ? .hidden : .visible
				self.window?.animator().toolbar?.isVisible = !self.mouseOver || self.mouseIdle ? false : self.showToolbar
			})
		}
        docIconVisibility(autoHideTitlePreference == .never || translucencyPreference == .never)
		
		if let timer = fadeTimer, timer.isValid { timer.invalidate() }
		self.fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeSecs, repeats: false, block: { (timer) in
			if fadeNow || timer.isValid {
				self.mouseIdle = true
				timer.invalidate()

				NSAnimationContext.runAnimationGroup({ (context) in
					context.duration = fadeNow ? 0.5 : 1.0
					self.titleView?.animator().isHidden = true
					///self.window?.animator().titlebarAppearsTransparent = true
					self.window?.animator().titleVisibility = .hidden
					self.window?.animator().toolbar?.isVisible = self.showToolbar
				})
			}
		})
		if let timer = self.fadeTimer { RunLoop.current.add(timer, forMode: .common) }
	}
	
	fileprivate func installTitleHider(_ hideNow: Bool = false) {
		guard UserSettings.AutoHideTitle.value != (hideTimer != nil) else { return }
		guard let titleView = self.titleView else { return }
		let hideMe = !self.mouseOver || self.mouseIdle

		if hideNow {
			NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.5
				
				self.titleView?.animator().isHidden = hideMe
				///self.window?.animator().titlebarAppearsTransparent = hideMe
				self.window?.animator().titleVisibility = !self.mouseOver || self.mouseIdle ? .hidden : .visible
				self.window?.animator().toolbar?.isVisible = !self.mouseOver || self.mouseIdle ? false : showToolbar
			})
		}
        docIconVisibility(autoHideTitlePreference == .never || translucencyPreference == .never)
		
		if let timer = hideTimer, timer.isValid { timer.invalidate(); hideTimer = nil; print("±hider") }
		guard UserSettings.AutoHideTitle.value else { return }
		
		self.hideTimer = Timer.scheduledTimer(withTimeInterval: 3.97, repeats: true, block: { (timer) in
			if hideNow || timer.isValid, !titleView.isHidden {
				self.mouseIdle = true
				timer.invalidate()

				NSAnimationContext.runAnimationGroup({ (context) in
					context.duration = hideNow ? 0.5 : 1.0
					print(String(format: "-hider over:%@ idle:%@",
									   (self.mouseOver ? "Yes" : "No"),
									   (self.mouseIdle ? "Yes" : "No")))
					self.titleView?.animator().isHidden = true
					///self.window?.animator().titlebarAppearsTransparent = true
					self.window?.animator().titleVisibility = .hidden
					self.window?.animator().toolbar?.isVisible = self.showToolbar
				})
			}
		})
		if let timer = self.hideTimer { RunLoop.current.add(timer, forMode: .common); print("+hider") }
	}
	
    fileprivate func mouseStateChanged() {
        let stateChange = priorOver != mouseOver || priorIdle != mouseIdle
        
        updateTranslucency()
        
        //  view or title entered
        updateTitleBar(didChange: stateChange)
        
        if mouseOver && self.autoHideTitlePreference == .outside {
            installTitleFader()
        }
    }
	
	override func mouseEntered(with event: NSEvent) {
        if event.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
            NSApp.activate(ignoringOtherApps: true)
        }

		guard monitoringMouseEvents() else { return }

		self.mouseOver = true
		
		installTitleFader(true)
	}
	
	override func mouseExited(with event: NSEvent) {
		guard monitoringMouseEvents() else { return }

		self.mouseOver = false
		
		installTitleFader(true)
	}
	
	override func mouseMoved(with event: NSEvent) {
		guard !appDelegate.inQuickQuietMode else { return }
		guard monitoringMouseEvents() && mouseIdle else { return }

		guard mouseIdle else { return }
		self.mouseIdle = false
		
		installTitleFader(true)
	}

    // MARK:- Dragging
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingEntered(_ sender: NSDraggingInfo!) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly.rawValue]) {
            return .copy
        }
        return .copy
    }
    
    func performDragOperation(_ sender: NSDraggingInfo!) -> Bool {
        let options : [NSPasteboard.ReadingOptionKey: Any] =
            [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
             NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [
                kUTTypeImage, kUTTypeVideo, kUTTypeMovie]]
        let classes = [NSFilePromiseReceiver.self, NSURL.self]
        let pboard = sender.draggingPasteboard
        let items = pboard.pasteboardItems
        var handled = 0

        //  Handle promises first
        sender.enumerateDraggingItems(options: [], for: nil, classes: classes, searchOptions: options) {(draggingItem, _, _) in
            switch draggingItem.item {
            case let filePromiseReceiver as NSFilePromiseReceiver:
                filePromiseReceiver.receivePromisedFiles(atDestination: self.destinationURL, options: [:],
                                                         operationQueue: self.workQueue) { (fileURL, error) in
                    if let error = error {
                        self.handleError(error)
                    } else {
                        self.handleFile(at: fileURL)
                        handled += 1
                    }
                }
            case let fileURL as URL:
                self.handleFile(at: fileURL)
                handled += 1
            default: break
            }
        }
        return handled == items?.count ? true : false
    }

    func window(_ window: NSWindow, shouldDragDocumentWith event: NSEvent, from dragImageLocation: NSPoint, with pasteboard: NSPasteboard) -> Bool {
        if promiseURL.isFileURL { return true }
        pasteboard.clearContents()
        pasteboard.writeObjects([self.panel])
        let dragImage = doc?.displayImage ?? NSImage.init(named: k.AppName)
        window.drag(dragImage!.resize(w: 32, h: 32), at: dragImageLocation, offset: .zero, event: event, pasteboard: pasteboard, source: window, slideBack: true)
        ///window.standardWindowButton(.documentIconButton)?.dragPromisedFiles(ofTypes: ["fileloc","webloc"], from: dragImage!.alignmentRect, source: self, slideBack: true, event: event)

        return false
    }
    
    // MARK:- Promise Provider
    lazy var workQueue : OperationQueue = {
        let providerQueue = OperationQueue()
        providerQueue.qualityOfService = .userInitiated
        return providerQueue
    }()
    
    var promiseURL : URL {
        get {
            return window?.representedURL ?? homeURL
        }
    }
    
    // directory URL used for accepting file promises
    private lazy var destinationURL: URL = {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        return destinationURL
    }()

    // updates the canvas with a given image file
    private func handleFile(at url: URL) {
        ///let data = NSImageRep.init(contentsOf: url)
        let data = KeyedArchiver.archivedData(withRootObject: NSImage(contentsOf: url) as Any)
        OperationQueue.main.addOperation {
            self.webView?.load(data, mimeType: data.mimeType, characterEncodingName: "UTF16", baseURL: url)
        }
    }
        
    // displays an error
    private func handleError(_ error: Error) {
        OperationQueue.main.addOperation {
            if let window = self.window {
                self.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                self.presentError(error)
            }
        }
    }

    //  MARK: Promise Handling

    var promiseContents : String {
        let htmlString = String(format: """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
        <plist version=\"1.0\">
        <dict>
        <key>URL</key>
        <string>%@</string>
        </dict>
        </plist>
        """, promiseURL.absoluteString)
        return htmlString
    }
    var promiseFilename : String {
        get {
            let url = self.promiseURL
            
            return url.isFileURL ? url.lastPathComponent : url.absoluteString
        }
    }
    var promiseType : String {
        get {
            return ((promiseURL.isFileURL ? kUTTypeSymLink : kUTTypeHTML) as String)
        }
    }
    
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
        let fileName = String(format: "%@.webloc", promiseFilename)
        return [fileName]
    }
    /*
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        print("he3WO type: \(type.rawValue)")
        switch type {
        default:
            return .promised
        }
    }
     https://www.google.com/search?q=big%20kid%20deluxe%20muslin%20fleece%20blanket
    */
    func pasteboardWriter(forPanel panel: Panel) -> NSPasteboardWriting {
        return promiseFilename as NSString
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        print("ppl type: \(type.rawValue)")
        switch type {
        case .rowDragType:
            return KeyedArchiver.archivedData(withRootObject: promiseURL.absoluteString as NSString)
            
        case .fileURL:
            return KeyedArchiver.archivedData(withRootObject: self.promiseURL)
            
        case .string:
            return self.promiseURL.absoluteString
            
        default:
            print("unknown \(type)")
            return nil
        }
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		let types : [NSPasteboard.PasteboardType] = [.rowDragType, .fileURL, .URL, .string]

         return types
    }
    
    // MARK: - NSFilePromiseProviderDelegate
    public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let urlString = promiseFilename
        let fileName = String(format: "%@.%@", urlString, promiseURL.isFileURL ? "fileloc" : "webloc")
        return fileName
    }
    
    public func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                                    writePromiseTo url: URL,
                                    completionHandler: @escaping (Error?) -> Void) {
        let urlString = promiseContents
        print("WindowDelegate -filePromiseProvider\n \(urlString)")

        do {
            try urlString.write(to: url, atomically: true, encoding: .utf8)
            completionHandler(nil)
        } catch let error {
            completionHandler(error)
        }
    }
    
    public func promiseOperationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return self.workQueue
    }
    
    // MARK:- Floating
	@objc var floatAboveValue: Int {
		get {
			return floatAboveAllPreference.rawValue
		}
	}
    var floatAboveAllPreference: FloatAboveAllPreference {
        get {
            guard let doc : Document = self.doc else { return .allSpace }
            return doc.settings.floatAboveAllPreference.value
        }
        set (value) {
			self.willChangeValue(forKey: "floatAboveValue")
			if let doc = self.doc {
				doc.settings.floatAboveAllPreference.value = value
			}
			self.willChangeValue(forKey: "floatAboveValue")
        }
    }
    struct FloatAboveAllPreference: OptionSet {
        let rawValue: Int
        
        static var allSpace = FloatAboveAllPreference(rawValue: 0)
        static let oneSpace = FloatAboveAllPreference(rawValue: 1)
        static let screen   = FloatAboveAllPreference(rawValue: 2)
    }

    // MARK:- Titling
	@objc var autoHideValue: Int {
		get {
			return autoHideTitlePreference.rawValue
		}
	}
    var autoHideTitlePreference: AutoHideTitlePreference {
        get {
            guard let doc : Document = self.doc else { return .never }
            return doc.settings.autoHideTitlePreference.value
        }
        set (value) {
			self.willChangeValue(forKey: "autoHideValue")
            doc?.settings.autoHideTitlePreference.value = value
            updateTitleBar(didChange: true)
			self.didChangeValue(forKey: "autoHideValue")
        }
    }
    enum AutoHideTitlePreference: Int {
        case never = 0
        case outside = 1
    }

    fileprivate var alpha: CGFloat = 0.6 { //default
        didSet {
            updateTranslucency()
        }
    }
	@objc var alphaLevel: Int = 6
    enum NewViewLocation : Int {
        case same = 0
        case window = 1
        case tab = 2
    }
    
	@objc var transValue: Int {
		get {
			return translucencyPreference.rawValue
		}
	}
    var translucencyPreference: TranslucencyPreference {
        get {
            guard let doc : Document = self.doc else { return .never }
            return doc.settings.translucencyPreference.value
        }
        set (value) {
			self.willChangeValue(forKey: "transValue")
            doc?.settings.translucencyPreference.value = value
            updateTitleBar(didChange: true)
			self.didChangeValue(forKey: "transValue")
        }
    }
    
    enum TranslucencyPreference: Int {
        case never = 0
        case always = 1
        case mouseOver = 2
        case mouseOutside = 3
        case offOver = -2
        case offOutside = -3
    }

    @objc fileprivate func updateTranslucency() {
        currentlyTranslucent = shouldBeTranslucent()
    }
    
    fileprivate var currentlyTranslucent: Bool = false {
        didSet {
            if !NSApplication.shared.isActive {
                panel.ignoresMouseEvents = currentlyTranslucent
            }
            if currentlyTranslucent {
                panel.alphaValue = alpha
                panel.isOpaque = false
            } else {
                panel.isOpaque = true
                panel.alphaValue = 1
            }
        }
    }

    fileprivate func shouldBeTranslucent() -> Bool {
        /* Implicit Arguments
         * - mouseOver
         * - translucencyPreference
         */
        
        switch translucencyPreference {
        case .never, .offOver, .offOutside:
            return false
        case .always:
            return true
        case .mouseOver:
            return mouseOver
        case .mouseOutside:
            return !mouseOver
        }
    }
    fileprivate func canBeTranslucent() -> Bool {
        switch translucencyPreference {
        case .never, .offOver, .offOutside:
            return false
        case .always, .mouseOver, .mouseOutside:
            return true
        }
    }
    
    fileprivate func shouldBeVisible() -> Bool {
        /* Implicit Arguments
         * - mouseOver
         * - autoHideTitlePreference
         */

        switch autoHideTitlePreference {
        case .never:
            return true
        case .outside:
            return !mouseOver
        }
    }
    
    //MARK:- IBActions
    
    fileprivate var doc: Document? {
        get {
            return self.document as? Document
        }
    }
    fileprivate var settings: Settings {
        get {
            if let doc = self.doc {
                return doc.settings
            }
            else
            {
                return Settings()
            }
        }
    }
    fileprivate func cacheSettings() {
        if let doc = self.doc, let url = doc.fileURL {
            doc.cacheSettings(url)
        }
    }
    
    @objc @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        guard autoHideTitlePreference.rawValue != sender.tag else { return }
        
        autoHideTitlePreference = HeliumController.AutoHideTitlePreference(rawValue: sender.tag)!

        installTitleFader()

        updateTitleBar(didChange: true)
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
	}
	
    @objc @IBAction func floatOverSpacesPress(_ sender: NSMenuItem) {
		self.willChangeValue(forKey: "floatAboveValue")
		let now = FloatAboveAllPreference(rawValue: sender.tag)
		let was = floatAboveAllPreference
		
		guard now != was else { return }
		
		if was.contains(.screen) || now == .screen {
			if was .contains(.screen) {
				settings.floatAboveAllPreference.value.remove(.screen)
			}
			else
			{
				settings.floatAboveAllPreference.value.insert(.screen)
			}
		}
		else
		{
			if was == .oneSpace {
				settings.floatAboveAllPreference.value.remove(.oneSpace)
			}
			else
			{
				settings.floatAboveAllPreference.value.insert(.oneSpace)
			}
		}
		self.didChangeValue(forKey: "floatAboveValue")
		
        setFloatOverFullScreenApps()
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
    }
	
    @objc @IBAction func percentagePress(_ sender: NSMenuItem) {
        settings.opacityPercentage.value = sender.tag
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
        
        willUpdateAlpha()
    }
	@objc @IBAction func percentageLevelPress(_ sender: NSLevelIndicator) {
		settings.opacityPercentage.value = Int(sender.intValue) * 10
		
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
        
        willUpdateAlpha()
        print("alphaLevel \(alphaLevel) alpha\(alpha)")
    }
    @objc @IBAction func selectTabItem(_ sender: Any) {
        panel.selectTabItem(sender)
    }
    @objc @IBAction func selectFirstTab(_ sender: Any) {
        if let item : NSMenuItem = (sender as? NSMenuItem), let tabs = self.window?.tabbedWindows, let tab = tabs.first {
            item.representedObject = tab
            self.selectTabItem(item)
        }
    }
    @objc @IBAction func selectLastTab(_ sender: AnyObject) {
        if let item : NSMenuItem = (sender as? NSMenuItem), let tabs = self.window?.tabbedWindows, let tab = tabs.last {
            item.representedObject = tab
            self.selectTabItem(item)
        }
    }
    
    @objc @IBAction private func toggleTranslucencyPress(_ sender: NSMenuItem) {
        switch translucencyPreference {
        case .never:
            translucencyPreference = .always
        case .always:
            translucencyPreference = .never
        case .mouseOver:
            translucencyPreference = .offOver
        case .mouseOutside:
            translucencyPreference = .offOutside
        case .offOver:
            translucencyPreference = .mouseOver
        case .offOutside:
            translucencyPreference = .mouseOutside
        }
        
        if let doc = panel.windowController?.document {
            doc.updateChangeCount(.changeDone)
        }

        willUpdateTranslucency()
    }
	@objc var opacityPressEnabled : Bool = false
    @objc @IBAction func translucencyPress(_ sender: NSMenuItem) {
        translucencyPreference = HeliumController.TranslucencyPreference(rawValue: sender.tag)!
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }

		opacityPressEnabled = sender.tag != 0
		
        willUpdateTranslucency()
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let autoHideTitleBarMenu = menuItem.menu?.title == "Auto-hide Title Bar"
        let translucenceMenu = menuItem.menu?.title == "Translucency"
        
        switch menuItem.title {
        case "Preferences":
            break
        //Transluceny Menu
        case "Enabled":
            menuItem.state = canBeTranslucent() ? .on : .off
        //AutoHide / Transluceny Menu
        case "Never":
            if autoHideTitleBarMenu {
                menuItem.state = autoHideTitlePreference == .never ? .on : .off
            }
            else
            if translucenceMenu
            {
                menuItem.state = translucencyPreference == .never ? .on : .off
            }
        case "Outside":
            if autoHideTitleBarMenu {
                menuItem.state = autoHideTitlePreference == .outside ? .on : .off
            }
            else
            if translucenceMenu
            {
                menuItem.state = translucencyPreference == .always ? .on : .off
            }
        case "Mouse Over":
            menuItem.state = translucencyPreference == .offOver
                ? .mixed
                : translucencyPreference == .mouseOver ? .on : .off
        case "Mouse Outside":
            menuItem.state = translucencyPreference == .offOutside
                ? .mixed
                : translucencyPreference == .mouseOutside ? .on : .off
        case "All Spaces":
			menuItem.state = floatAboveAllPreference.contains(.oneSpace) ? .off : .on
		case "Single Space":
            menuItem.state = floatAboveAllPreference.contains(.oneSpace) ? .on : .off
        case "Full Screen":
            menuItem.state = floatAboveAllPreference.contains(.screen) ? .on : .off
        case "Hide He3 in menu bar":
            menuItem.state = UserSettings.HideAppMenu.value ? .on : .off
        case "Home Page":
            break
        case "Magic URL Redirects":
            menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
        case "Save":
            break

        default:
			if menuItem.title.hasSuffix(" Toolbar") {
				menuItem.title = (showToolbar ? "Hide" : "Show") + " Toolbar"
			}
			else
            // Opacity menu item have opacity as tag value
            if menuItem.tag >= 10 {
                menuItem.state = (menuItem.tag == settings.opacityPercentage.value ? .on : .off)
            }
        }
        return true;
    }

    //MARK:- Notifications
	@objc func autoHideTitleBar(_ notification: Notification) {
        installTitleHider(true)
    }

    @objc func willUpdateAlpha() {
        didUpdateAlpha(settings.opacityPercentage.value)
    }
    func willUpdateTitleBar() {
        //  synchronize prefs to document's panel state
        let nowState = autoHideTitlePreference
        let othState = autoHideTitlePreference == .never ? HeliumController.AutoHideTitlePreference.outside : .never
        self.autoHideTitlePreference = othState
        self.autoHideTitlePreference = nowState
    }
    @objc func willUpdateTranslucency() {
        translucencyPreference = settings.translucencyPreference.value
        updateTranslucency()
    }
    
    func windowDidResize(_ notification: Notification) {
        guard let vindow = notification.object as? NSWindow,
            let wpc = vindow.windowController as? HeliumController else { return }
        
        wpc.updateTranslucency()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let vindow = window,
            let wvc = vindow.contentViewController as? WebViewController else { return false }

        //  Stop whatever is going on by brute force
		DispatchQueue.main.async {
			if let url = self.doc?.fileURL, url.isFileURL {
				url.stopAccessingSecurityScopedResource()
			}
			wvc.webView.stopLoading(self)
			wvc.clear()
		}

        vindow.ignoresMouseEvents = true
        
        // Wind down all observations
        NotificationCenter.default.removeObserver(self)
        
        return true
    }
    
    //MARK:- Actual functionality
    
    @objc func didUpdateURL(note: Notification) {
        let webView = self.window?.contentView?.subviews.first as! MyWebView

        if note.object as? URL == webView.url {
            self.updateTitleBar(didChange: false)
        }
    }
    
    fileprivate func docIconVisibility(_ mouseWasOver: Bool) {
        if let docIconButton = panel.standardWindowButton(.documentIconButton) {
            //  initially keep doc & title vertically aligned
            if 0 == docIconButton.constraints.count, let titleView = self.titleView {
                docIconButton.vCenter(titleView)
            }
            
			docIconButton.isHidden = autoHideTitlePreference == .outside ? !mouseWasOver : false
			
			docIconButton.image = webView?.icon
        }
    }
	@objc func quickQuiet(_ note: Notification) {
		print("quickQuiet \(String(describing: webView?.url?.absoluteString))")
		if let window = self.window, let webView = window.contentView?.subviews.first as? MyWebView, let url = webView.url {
			if window.alphaValue > 0.01 {
				if url.isFileURL {
					DispatchQueue.main.async {
						webView.evaluateJavaScript("window.webview.pause()", completionHandler: nil)
					}
				}
				window.alphaValue = 0.01
			}
			else
			{
				let hpc = window.windowController as! HeliumController
				if hpc.settings.translucencyPreference.value != .never {
					window.alphaValue = 1.00
				}
				else
				{
					let alpha = CGFloat((window.windowController as! HeliumController).settings.opacityPercentage.value) / 100.0
					if url.isFileURL {
						DispatchQueue.main.async {
							webView.evaluateJavaScript("window.webview.play()", completionHandler: nil)
						}
					}
					window.alphaValue = alpha
				}
				hpc.updateTranslucency()
			}
		}
	}
	
    @objc func updateTitleBar(didChange: Bool) {
        let mouseSeen = mouseOver && !mouseIdle

        //  treat home URL specially
        if nil == document?.fileURL {
            NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.1
				///panel.animator().titlebarAppearsTransparent = !mouseOver
				panel.animator().titleVisibility = mouseOver ? .visible : .hidden
				panel.animator().toolbar?.isVisible = mouseOver ? showToolbar : false
             })
             return
         }

         if didChange {
            NSAnimationContext.runAnimationGroup({ (context) in
                context.duration = mouseIdle ? 1.0 : 0.2

                if autoHideTitlePreference == .outside {
					///panel.animator().titlebarAppearsTransparent = !mouseSeen
                    panel.animator().titleVisibility = mouseSeen ? .visible : .hidden
					panel.animator().toolbar?.isVisible = mouseSeen ? showToolbar : false
                }
                else
                {
					///panel.animator().titlebarAppearsTransparent = false
                    panel.animator().titleVisibility = .visible
					panel.animator().toolbar?.isVisible = showToolbar
                }

            })
        }
        docIconVisibility(autoHideTitlePreference == .never || translucencyPreference == .never)
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        guard let doc = self.doc else { return displayName }
        
		switch doc.fileType {
		case k.Playlist:
            return doc.displayName
            
        default:
            if let length = self.webView?.title?.count, length > 0 {
                return self.webView!.title!
            }
            return displayName
        }
    }
    @objc func setFloatOverFullScreenApps() {
        if floatAboveAllPreference.contains(.oneSpace) {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.moveToActiveSpace, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        }
        if floatAboveAllPreference.contains(.screen) {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        } else {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        }
    }
    
    @objc fileprivate func doPlaylistItem(_ notification: Notification) {
        if let playlist = notification.object {
            let playlistURL = playlist as! URL
            _ = self.webViewController.loadURL(url: playlistURL)
        }
    }

    @objc fileprivate func didBecomeActive() {
        panel.ignoresMouseEvents = false
    }
    
    @objc fileprivate func willResignActive() {
        if currentlyTranslucent {
            panel.ignoresMouseEvents = true
        }
    }
    
    func didUpdateAlpha(_ intAlpha: Int) {
		self.willChangeValue(forKey: "alphaLevel")

        alpha = CGFloat(intAlpha) / 100.0
		alphaLevel = intAlpha / 10
		
		self.didChangeValue(forKey: "alphaLevel")
    }
	
	@objc var showToolbar : Bool = false
	var preferencesViewController : NSTitlebarAccessoryViewController?
	@IBAction func togglePreferencesPress(_ sender: AnyObject) {
		print("show me preferences")
		if let rvc = preferencesViewController {
			NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.5
				
				showToolbar = showToolbar ? false : true
				panel.animator().toolbar!.isVisible = showToolbar
				rvc.view.animator().isHidden = showToolbar
			})
		}
	}
		
	@IBOutlet var autoHidePopup: NSPopUpButton!
	@IBOutlet var floatPopup: NSPopUpButton!
	@IBOutlet var transPopup: NSPopUpButton!
	@IBOutlet var opacityLevel: NSLevelIndicator!
}

class ReleaseController : HeliumController {

    override func windowDidLoad() {
        //  Default to not dragging by content
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.windowController?.shouldCascadeWindows = true///.offsetFromKeyWindow()

		///panel.appearance = NSAppearance(named: .vibrantDark)
		///panel.titlebarAppearsTransparent = true
		panel.animator().titleVisibility = .visible
		panel.backgroundColor = .white

        // Remember for later restoration
        NSApp.changeWindowsItem(panel, title: window?.title ?? k.ReleaseNotes, filename: false)
    }
}
