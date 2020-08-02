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

class TitleDragButton : NSButton {
/* https://developer.apple.com/library/archive/samplecode/PhotoEditor/Listings/
 *  Photo_Editor_WindowDraggableButton_swift.html#//
 *  apple_ref/doc/uid/TP40017384-Photo_Editor_WindowDraggableButton_swift-DontLinkElementID_22
 */
    //  once our controller appear, update
    var hpc : HeliumController? {
        get {
            return self.window?.windowController as? HeliumController
        }
    }
    var homeURL : URL {
        get {
            if let hpc = self.hpc {
                return hpc.homeURL
            }
            return URL.init(string: UserSettings.HomePageURL.value)!
        }
    }
    var homeColor : NSColor {
        get {
            if let hpc = self.hpc {
                return hpc.homeColor
            }
            return  NSColor(hex: 0x3399FF)
        }
    }
    var borderColor : NSColor {
        get {
            guard let window = self.window else { return NSColor.clear }
            if let url = window.representedURL, url != homeURL {
                return url.isFileURL ? NSColor.controlDarkShadowColor : homeColor
            }
            else
            {
                return homeColor
            }
        }
    }
    
    required override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.cell?.controlView?.wantsLayer = true
        self.layer?.borderWidth = 2
        self.layer?.borderColor = borderColor.cgColor
    }
      
    required init?(coder: NSCoder) {
        ///super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height))

        if let window = self.window, let url = window.representedURL, url.isFileURL {
            if !url.hasVideoContent() {
                self.layer?.backgroundColor = NSColor.controlDarkShadowColor.cgColor
            } else {
                self.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        else
        {
            self.layer?.backgroundColor = homeColor.cgColor
        }
        
        super.draw(dirtyRect)
        
        guard let hpc = self.hpc else { return }
        
        if hpc.autoHideTitlePreference == .never || hpc.mouseOver {
            let color = self.borderColor
            self.layer?.borderColor = color.cgColor
            color.setStroke(); color.setFill()
            path.stroke(); path.fill()
        }
    }
    
    override func mouseDown(with mouseDownEvent: NSEvent) {
        let window = self.window!
        let startingPoint = mouseDownEvent.locationInWindow
        
        highlight(true)
        
        // Track events until the mouse is up (in which we interpret as a click), or a drag starts (in which we pass off to the Window Server to perform the drag)
        var shouldCallSuper = false

        // trackEvents won't return until after the tracking all ends
        window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: NSEvent.foreverDuration, mode: RunLoop.Mode.default) { event, stop in
            switch event?.type {
                case .leftMouseUp:
                    // Stop on a mouse up; post it back into the queue and call super so it can handle it
                    shouldCallSuper = true
                    NSApp.postEvent(event!, atStart: false)
                    stop.pointee = true
                
                case .leftMouseDragged:
                    // track mouse drags, and if more than a few points are moved we start a drag
                    let currentPoint = event!.locationInWindow
                    if let window = self.window,
                        let docIconButton = window.standardWindowButton(.documentIconButton),
                        let iconBasePoint = docIconButton.superview?.superview?.frame.origin {
                        let docIconFrame = docIconButton.frame
                        let iconFrame = NSMakeRect(iconBasePoint.x + docIconFrame.origin.x,
                                                   iconBasePoint.y + docIconFrame.origin.y,
                                                   docIconFrame.size.width, docIconFrame.size.height)
                        //  If we're over the docIconButton send event to it
                        if iconFrame.contains(startingPoint), let hpc = hpc {
                            let dragItem = NSDraggingItem.init(pasteboardWriter: hpc)
                            dragItem.draggingFrame.size = NSMakeSize(32.0,32.0)
                            docIconButton.beginDraggingSession(with: [dragItem], event: event!, source: hpc)
                            break
                        }
                    }
                    
                    if (abs(currentPoint.x - startingPoint.x) >= 5 || abs(currentPoint.y - startingPoint.y) >= 5) {
                        self.highlight(false)
                        stop.pointee = true
                        window.performDrag(with: event!)
                    }
                
                default:
                    break
            }
        }
                
        if (shouldCallSuper) {
            super.mouseDown(with: mouseDownEvent)
        }
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
            return URL.init(string: incognito ? UserSettings.HomeStrkURL.value : UserSettings.HomePageURL.value)!
        }
    }
    var homeColor : NSColor {
        get {
            return  NSColor(hex: incognito ? 0x0000FF : 0x3399FF)
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
		///self.panel.appearance = NSAppearance(named: .vibrantDark)
		self.panel.titlebarAppearsTransparent = true
		self.panel.backgroundColor = homeColor
		
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

        //  We allow drag from title's document icon to self or Finder
        panel.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
		panel.registerForDraggedTypes([.rowDragType, .fileURL, .string])
        panel.windowController?.shouldCascadeWindows = true///offsetFromKeyWindow()

        // Remember for later restoration
        NSApp.changeWindowsItem(panel, title: panel.title, filename: false)
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
	
	dynamic var priorIdle: Bool = true
	dynamic var mouseIdle: Bool = false {
		willSet {
			priorIdle = mouseIdle
		}
	}
	dynamic var priorOver: Bool = false
	dynamic var mouseOver: Bool = false {
		willSet {
			priorOver = mouseOver
		}
		didSet {
			mouseIdle = false
		}
	}
	
	fileprivate func monitoringMouseEvents() -> Bool {
		return autoHideTitlePreference != .never || translucencyPreference != .never
	}
	
	fileprivate func installTitleFader(_ fadeNow: Bool = false) {
		guard autoHideTitlePreference != .never else {
			NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.01
				
				self.titleView?.animator().isHidden = false
				self.window?.animator().titlebarAppearsTransparent = false
				self.window?.animator().titleVisibility = .visible
			})
			return
		}
		let hideMe = !self.mouseOver || self.mouseIdle

		if fadeNow {
			NSAnimationContext.runAnimationGroup({ (context) in
				context.duration = 0.01
				
				self.titleView?.animator().isHidden = hideMe
				self.window?.animator().titlebarAppearsTransparent = hideMe
				self.window?.animator().titleVisibility = !self.mouseOver || self.mouseIdle ? .hidden : .visible
			})
		}
		//FIXME: do this less often
        docIconVisibility(autoHideTitlePreference == .never || translucencyPreference == .never)
		
		if let timer = fadeTimer, timer.isValid { timer.invalidate(); print("±timer") }
		self.fadeTimer = Timer.scheduledTimer(withTimeInterval: 3.97, repeats: false, block: { (timer) in
			if fadeNow || timer.isValid {
				self.mouseIdle = true
				timer.invalidate()

				NSAnimationContext.runAnimationGroup({ (context) in
					context.duration = fadeNow ? 0.02 : 1.0
					print(String(format: "-timer over:%@ idle:%@",
									   (self.mouseOver ? "Yes" : "No"),
									   (self.mouseIdle ? "Yes" : "No")))
					self.titleView?.animator().isHidden = true
					self.window?.animator().titlebarAppearsTransparent = true
					self.window?.animator().titleVisibility = .hidden
				})
			}
		})
		if let timer = self.fadeTimer { RunLoop.current.add(timer, forMode: .common); print("+timer") }
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
    var floatAboveAllPreference: FloatAboveAllPreference {
        get {
            guard let doc : Document = self.doc else { return .spaces }
            return doc.settings.floatAboveAllPreference.value
        }
        set (value) {
            doc?.settings.floatAboveAllPreference.value = value
        }
    }
    struct FloatAboveAllPreference: OptionSet {
        let rawValue: Int
        
        static var spaces   = FloatAboveAllPreference(rawValue: 0)
        static let disabled = FloatAboveAllPreference(rawValue: 1)
        static let screen   = FloatAboveAllPreference(rawValue: 2)
    }
    let floatAboveAllSpaces : FloatAboveAllPreference = []

    // MARK:- Titling
    var autoHideTitlePreference: AutoHideTitlePreference {
        get {
            guard let doc : Document = self.doc else { return .never }
            return doc.settings.autoHideTitlePreference.value
        }
        set (value) {
            doc?.settings.autoHideTitlePreference.value = value
            updateTitleBar(didChange: true)
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
    
    enum NewViewLocation : Int {
        case same = 0
        case window = 1
        case tab = 2
    }
    
    var translucencyPreference: TranslucencyPreference {
        get {
            guard let doc : Document = self.doc else { return .never }
            return doc.settings.translucencyPreference.value
        }
        set (value) {
            doc?.settings.translucencyPreference.value = value
            updateTitleBar(didChange: true)
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
    
    @objc @IBAction func floatOverAllSpacesPress(_ sender: NSMenuItem) {
        if sender.state == .on {
            settings.floatAboveAllPreference.value.remove(.disabled)
        }
        else
        {
            settings.floatAboveAllPreference.value.insert(.disabled)
        }
        setFloatOverFullScreenApps()
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
    }
    @objc @IBAction func floatOverFullScreenAppsPress(_ sender: NSMenuItem) {
        if sender.state == .on {
            settings.floatAboveAllPreference.value.remove(.screen)
        }
        else
        {
            settings.floatAboveAllPreference.value.insert(.screen)
        }
        setFloatOverFullScreenApps()
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
    }
    
    @objc @IBAction func percentagePress(_ sender: NSMenuItem) {
        settings.opacityPercentage.value = sender.tag
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }
        
        willUpdateAlpha()
    }
    
    @IBAction func snapshot(_ sender: Any) {
        guard let wvc = panel.contentViewController as? WebViewController else { return }
        wvc.snapshot(sender)
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

    @objc @IBAction func translucencyPress(_ sender: NSMenuItem) {
        translucencyPreference = HeliumController.TranslucencyPreference(rawValue: sender.tag)!
        
        if let doc = panel.windowController?.document { doc.updateChangeCount(.changeDone) }

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
        case "All Spaces Disabled":
            menuItem.state = settings.floatAboveAllPreference.value.contains(.disabled) ? .on : .off
        case "Full Screen":
            menuItem.state = settings.floatAboveAllPreference.value.contains(.screen) ? .on : .off
        case "Hide He3 in menu bar":
            menuItem.state = UserSettings.HideAppMenu.value ? .on : .off
        case "Home Page":
            break
        case "Magic URL Redirects":
            menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
        case "Snapshot":
            menuItem.isEnabled = panel.contentViewController?.isKind(of: WebViewController.self) ?? false
        case "Save":
            break

        default:
            // Opacity menu item have opacity as tag value
            if menuItem.tag >= 10 {
                menuItem.state = (menuItem.tag == settings.opacityPercentage.value ? .on : .off)
            }
        }
        return true;
    }

    //MARK:- Notifications
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
            
            if let url = self.webView?.url, !url.isFileURL {
                docIconButton.isHidden = true
            }
            else
            {
                if autoHideTitlePreference == .outside {
                    docIconButton.isHidden = !mouseWasOver
                }
                else
                {
                    docIconButton.isHidden = false
                }
                if !docIconButton.isHidden
                {
                    if let doc = self.doc {
                        docIconButton.image = doc.displayImage.resize(w: 12, h: 12)
                    }
                    else
                    {
                         docIconButton.image = NSApp.applicationIconImage.resize(w: 12, h: 12)
                    }

                    if let url = self.webView?.url, url.isFileURL {
                        self.synchronizeWindowTitleWithDocumentName()
                    }
                }
            }
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
                 panel.animator().titleVisibility = mouseOver ? .visible : .hidden
				 panel.animator().titlebarAppearsTransparent = !mouseOver
             })
             return
         }

         if didChange {
            NSAnimationContext.runAnimationGroup({ (context) in
                context.duration = mouseIdle ? 1.0 : 0.2

                if autoHideTitlePreference == .outside {
                    panel.animator().titleVisibility = mouseSeen ? .visible : .hidden
					panel.animator().titlebarAppearsTransparent = !mouseSeen

                }
                else
                {
                    panel.animator().titleVisibility = .visible
					panel.animator().titlebarAppearsTransparent = false
                }

            })
        }
        docIconVisibility(autoHideTitlePreference == .never || translucencyPreference == .never)
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        guard let doc = self.doc else { return displayName }
        
        switch self.doc!.docGroup {
        case .playlist:
            return doc.displayName
            
        default:
            if let length = self.webView?.title?.count, length > 0 {
                return self.webView!.title!
            }
            return displayName
        }
    }
    @objc func setFloatOverFullScreenApps() {
        if settings.floatAboveAllPreference.value.contains(.disabled) {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.moveToActiveSpace, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        } else {
            panel.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        }
        if settings.floatAboveAllPreference.value.contains(.screen) {
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
        alpha = CGFloat(intAlpha) / 100.0
    }
}

class ReleasePanelController : HeliumController {

    override func windowDidLoad() {
        //  Default to not dragging by content
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.windowController?.shouldCascadeWindows = true///.offsetFromKeyWindow()

		panel.appearance = NSAppearance(named: .vibrantDark)
		self.panel.titlebarAppearsTransparent = true
		self.panel.backgroundColor = .white

        // Remember for later restoration
        NSApp.changeWindowsItem(panel, title: window?.title ?? k.ReleaseNotes, filename: false)
    }
}
