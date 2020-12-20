//
//  WebView.swift
//  He3 (Helium)
//
//  Created by Carlos D. Santiago on 10/25/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//
//	Split from WebViewController.swift
//

import Cocoa
import WebKit
import AVFoundation
import Carbon.HIToolbox
import Quartz
import OSLog

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
fileprivate var docController : DocumentController {
    get {
        return NSDocumentController.shared as! DocumentController
    }
}

extension WKNavigationType {
    var name : String {
        get {
            let names = ["linkActivated","formSubmitted","backForward","reload","formResubmitted"]
            return names.indices.contains(self.rawValue) ? names[self.rawValue] : "other"
        }
    }
}
class WebBorderView : NSView {
    var isReceivingDrag = false {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        self.isHidden = !isReceivingDrag
//        print("web borderView drawing \(isHidden ? "NO" : "YES")....")

        if isReceivingDrag {
            NSColor.selectedKnobColor.set()
            
            let path = NSBezierPath(rect:bounds)
            path.lineWidth = 4
            path.stroke()
        }
    }
}

class ProgressIndicator : NSProgressIndicator {
    init() {
        super.init(frame: NSMakeRect(0, 0, 32, 32))

        isDisplayedWhenStopped = false
        isIndeterminate = true
        style = .spinning
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /*
    override func mouseDown(with event: NSEvent) {
        guard !isHidden else { return }
        print("we want to stop something...")
        
        if let webView : MyWebView = self.superview as? MyWebView, webView.isLoading {
            webView.stopLoading()
        }
    }*/
}

extension WKBackForwardListItem {
    var article : String {
        get {
            guard let title = self.title, title.count > 0 else { return url.absoluteString }
            return title
        }
    }
}

class CacheSchemeHandler : NSObject,WKURLSchemeHandler {
    var task: WKURLSchemeTask?
    
    func cachePicker(_ webView : WKWebView) {
        guard let task = task else { return }
        
        let url = task.request.url!
        let paths = url.pathComponents
        let group = paths[1]
        let ident = paths[2]
        var dict : Dictionary<String,String>
        
        //  group type 'asset' in our asset bundle, else defautls
        switch group {
        case k.asset:
            dict = Dictionary<String,String>()
			if url.pathExtension == k.html {
				dict[k.text] = NSString.string(fromAsset: ident)
				dict[k.mime] = "text/html"
			}
			else
			if ["jpg","png","tif"].contains(url.pathExtension)
			{
				dict[k.text] = (ident as NSString).deletingPathExtension
				dict[k.mime] = "image/" + url.pathExtension
			}
			else
			{
				return
			}

		case k.text, k.html:
            let cache = String(format: "%@/%@", group, ident)
            dict = defaults.dictionary(forKey: cache)! as! Dictionary<String, String>
			
		default:
            return
        }
        
        guard let mime = dict[k.mime], var text = dict[k.text] else { return }
        var data: Data

        //  paths *must* be [0]="/", [1]=type, [2]=cache-unique-name
        switch group {// type: asset,data,html,text
             
        case k.data:
            data = text.dataFromHexString()!
            
        case k.asset,k.text:
			if mime.hasPrefix(k.text)
			{
				data = text.data(using: .utf8)!
			}
			else
			{
				data = Data.data(fromAsset: dict[k.text]!)
			}

        case k.html:
            data = text.dataFromHexString()!
            do {
                let atrs = try NSAttributedString.init(data: data, options: [:], documentAttributes: nil)
                text = String(format: "<html><body><pre>%@</pre></body></html>", atrs)

            } catch let error as NSError {
                print("attributedString <- data: \(error.code):\(error.localizedDescription): \(text)")
            }
            
        default:
            fatalError("unknown cache: \(group)/\(ident)")
        }
        
        task.didReceive(URLResponse(url: url, mimeType:mime, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
     }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        task = urlSchemeTask
        
        cachePicker(webView)
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        task = nil
    }
}

class MyWebView : WKWebView {
    static let poi = OSLog(subsystem: "com.slashlos.he3", category: .pointsOfInterest)
    
    // MARK: TODO: load new files in distinct windows
    dynamic var dirty = false
    var docController : DocumentController {
        get {
            return NSDocumentController.shared as! DocumentController
        }
    }
	var hpc : HeliumController? {
		get {
			return self.window?.windowController as? HeliumController
		}
	}

    override class func handlesURLScheme(_ urlScheme: String) -> Bool {
        print("handleURLScheme: \(urlScheme)")
        return [k.scheme,k.caches].contains(urlScheme)
    }
    var selectedText : String?
    var selectedURL : URL?
    var chromeType: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "org.chromium.drag-dummy-type") }
    var finderNode: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "com.apple.finder.node") }
    var webarchive: NSPasteboard.PasteboardType { return NSPasteboard.PasteboardType.init(rawValue: "com.apple.webarchive") }
    var acceptableTypes: Set<NSPasteboard.PasteboardType> { return [.URL, .fileURL, .html, .pdf, .png, .rtf, .rtfd, .tiff, finderNode, webarchive] }
    var filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes:NSImage.imageTypes]
    
    var borderView = WebBorderView()
    var loadingIndicator = ProgressIndicator()
    var incognito = false
    var homeURL : URL {
        get {
			let url = UserSettings.UseLocalAssets.value
				?	URL.init(string: incognito ? UserSettings.LocalStrkURL.value : UserSettings.LocalPageURL.value)!
				:	URL.init(string: incognito ? UserSettings.HomeStrkURL.value  : UserSettings.HomePageURL.value)!
			return url
        }
    }
	
	var icon : NSImage?
	
    init() {
        super.init(frame: .zero, configuration: appDelegate.webConfiguration)
        
        // Custom user agent string for Netflix HTML5 support
        customUserAgent = UserSettings.UserAgent.value
        
        // Allow zooming
        allowsMagnification = true
        
        // Alow back and forth
        allowsBackForwardNavigationGestures = true
        
        // Allow look ahead views
        allowsLinkPreview = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
	
	
	var playitem: PlayItem {
		get {
			let item = PlayItem()
			item.link = self.url ?? homeURL
			let fuzz = (item.link as AnyObject).deletingPathExtension!!.lastPathComponent as NSString
			item.name = fuzz.removingPercentEncoding!
			let attr = appDelegate.metadataDictionaryForFileAt(item.link.path)
			item.time = attr?[kMDItemDurationSeconds] as? TimeInterval ?? 0
			item.rect = self.window?.frame ?? .zero
			if let doc = self.window?.windowController?.document {
				let settings = (doc as! Document).settings
				item.label = settings.autoHideTitlePreference.value.rawValue
				item.hover = settings.floatAboveAllPreference.value.rawValue
				item.alpha = settings.opacityPercentage.value
				item.trans = settings.translucencyPreference.value.rawValue
				item.agent = settings.customUserAgent.value
			}
			return item
		}
	}

    @objc internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            print("Menu \(menuItem.title) clicked")
        }
    }
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(incognito, forKey: "incognito")
    }
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        
        incognito = coder.decodeBool(forKey: "incognito")
    }
    /*
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        print("evaluateJavaScript \(javaScriptString)")
        super.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
    }
    */
    @objc open func jump(to item: NSMenuItem) -> WKNavigation? {
        if let nav = go(to: item.representedObject as! WKBackForwardListItem) {
            self.window?.title = item.title
            return nav
        }
        return  nil
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {

        //  Pick off javascript items we want to ignore or handle
        for title in ["Inspect Element", "Open Link", "Open Link in New Window", "Download Linked File"] {
            if let item = menu.item(withTitle: title) {
				if title == "Inspect Element" {
					item.isHidden = !UserSettings.DeveloperExtrasEnabled.value
				}
				else
                if title == "Download Linked File" {
                    if let url = selectedURL {
                        item.representedObject = url
                        item.action = #selector(MyWebView.downloadLinkedFile(_:))
                        item.target = self
                    }
                    else
                    {
                        item.isHidden = true
                    }
                }
                else
                if title == "Open Link"
                {
                    item.action = #selector(MyWebView.openLinkInWindow(_:))
                    item.target = self
                }
                else
                {
                    item.tag = ViewOptions.w_view.rawValue
                    item.action = #selector(MyWebView.openLinkInNewWindow(_:))
                    item.target = self
                }
            }
        }

        publishContextualMenu(menu);
    }
    
    @objc func openLinkInWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            _ = load(URLRequest.init(url: url))
        }
        else
        if let url = self.selectedURL {
            _ = load(URLRequest.init(url: url))
        }
    }
    
    @objc func openLinkInNewWindow(_ item: NSMenuItem) {
        if let urlString = self.selectedText, let url = URL.init(string: urlString) {
            _ = appDelegate.openURLInNewWindow(url, context: item.representedObject as? NSWindow)
        }
        else
        if let url = self.selectedURL {
            _ = appDelegate.openURLInNewWindow(url, context: item.representedObject as? NSWindow)
        }
    }
    var ui : WebViewController {
        get {
            return uiDelegate as! WebViewController
        }
    }
    @objc func downloadLinkedFile(_ item: NSMenuItem) {
        let downloadURL : URL = item.representedObject as! URL
        downloadURL.saveAs(responseHandler: { saveAsURL in
            if let saveAsURL = saveAsURL {
                self.ui.loadFileAsync(downloadURL, to: saveAsURL, completion: { (path, error) in
                    if let error = error {
                        NSApp.presentError(error)
                    }
                    else
                    {
                        if appDelegate.isSandboxed { _ = appDelegate.storeBookmark(url: saveAsURL, options: [.withSecurityScope]) }
                    }
                })
            }
        })
    }
    
    override var mouseDownCanMoveWindow: Bool {
        get {
            if let window = self.window {
                return window.isMovableByWindowBackground
            }
            else
            {
                return false
            }
        }
    }
    
    var heliumPanelController : HeliumController? {
        get {
            guard let hpc : HeliumController = self.window?.windowController as? HeliumController else { return nil }
            return hpc
        }
    }
    var webViewController : WebViewController? {
        get {
            guard let wvc : WebViewController = self.window?.contentViewController as? WebViewController else { return nil }
            return wvc
        }
    }

    fileprivate func load(_ request: URLRequest, with cookies: [HTTPCookie]) -> WKNavigation? {
        var request = request
        let headers = HTTPCookie.requestHeaderFields(with: cookies)
        for (name,value) in headers {
            request.addValue(value, forHTTPHeaderField: name)
        }
        return super.load(request)
    }
    
    override func load(_ original: URLRequest) -> WKNavigation? {
        guard let request = (original as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            print("Unable to create mutable request \(String(describing: original.url))")
            return super.load(original) }
        guard let url = original.url else { return super.load(original) }
        print("load(_:Request) <= \(request)")
        
        let requestIsSecure = url.scheme == "https"
        var cookies = [HTTPCookie]()

        //  Fetch legal, relevant, authorized cookies
        for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
            if cookie.name.contains("'") { continue } // contains a "'"
			if let urlDomain = url.host, !cookie.domain.hasSuffix(urlDomain) { continue }
            if cookie.isSecure && !requestIsSecure { continue }
            cookies.append(cookie)
        }
        
        //  Marshall cookies into header field(s)
        for (name,value) in HTTPCookie.requestHeaderFields(with: cookies) {
            request.addValue(value, forHTTPHeaderField: name)
        }

        //  And off you go...
        return super.load(request as URLRequest)
    }

    func next(url: URL) -> Bool {
        os_signpost(.begin, log: MyWebView.poi, name: "next")
        defer { os_signpost(.end, log: MyWebView.poi, name: "next") }

        guard let doc = self.webViewController?.document else { return false }

        //  Resolve alias before sandbox bookmarking
        if let webloc = url.webloc { return next(url: webloc) }

        if url.isFileURL
        {
			if !appDelegate.preflight(url) {
                print("Yoink, unable to sandbox \(url)")
                return false
            }
            let baseURL = appDelegate.authenticateBaseURL(url)
			
			return self.loadFileURL(url, allowingReadAccessTo: baseURL) != nil
        }
        else
		if url.absoluteString != k.blank, self.load(URLRequest(url: url)) != nil {
			doc.fileURL = url
			return true
		}
		else
		{
			(navigationDelegate as? WebViewController)?.clear()
			return true
        }
    }
    
    func data(_ data : Data) -> Bool {
        guard let url = URL.init(cache: data) else { return false }
        return next(url: url)
    }
    
    func html(_ html : String) -> Bool {
        guard let url = URL.init(cache: html) else { return false }
        return next(url: url)
    }
    
    func text(_ text : String) -> Bool {
		//	We have what appears to be a URL with a scheme so try it
		if let url = URL.init(string: text), nil != url.scheme { if next(url: url) { return true } }
        
		//	Just send along as text what we have
        guard let url = URL.init(cache: text, embed: true) else { return false }
        return next(url: url)
    }
    
    func text(_ text: NSAttributedString) -> Bool {
        guard let url = URL.init(cache: text, embed: true) else { return false }
        return next(url: url)
    }
    
    //  MARK: Mouse tracking idle
    var trackingArea : NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
		let options : NSTrackingArea.Options = [.activeAlways,.mouseEnteredAndExited, .mouseMoved]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

	let PasteboardFileURLPromise = NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFileURLPromise)
	let PasteboardFilePromiseContent = NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFilePromiseContent)
	let PasteboardFilePasteLocation = NSPasteboard.PasteboardType(rawValue: "com.apple.pastelocation")
	
	override func mouseDown(with event: NSEvent) {
		let startingPoint = event.locationInWindow
		let window = self.window!
		
		borderView.isReceivingDrag = true
		
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
						borderView.isReceivingDrag = true
						stop.pointee = true
						window.performDrag(with: event!)
					}
				
				default:
					break
			}
		}
				
		if (shouldCallSuper) {
			super.mouseDown(with: event)
			return
		}

		let pasteboardItem = NSPasteboardItem()
		
		//	Tell the pasteboard that we will be providing both file and content promises
		pasteboardItem.setDataProvider(self, forTypes: [PasteboardFileURLPromise,PasteboardFilePromiseContent])
		
		//	Create the dragging item for the drag operation
		let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
		let image = self.icon
		
		draggingItem.setDraggingFrame(self.bounds, contents: image)
	}
	
	override func mouseEntered(with event: NSEvent) {
		guard !appDelegate.inQuickQuietMode else { return }
		self.window?.windowController?.mouseEntered(with: event)
	}
	override func mouseExited(with event: NSEvent) {
		guard !appDelegate.inQuickQuietMode else { return }
		self.window?.windowController?.mouseExited(with: event)
	}
	override func mouseMoved(with event: NSEvent) {
		guard !appDelegate.inQuickQuietMode else { return }
		self.window?.windowController?.mouseMoved(with: event)
	}

    // MARK: Drag and Drop - Before Release
    func shouldAllowDrag(_ info: NSDraggingInfo) -> Bool {
		guard let doc = webViewController?.document, ![k.PlayType,k.PlayName].contains(doc.fileType) else { return false }
        let pboard = info.draggingPasteboard
        let items = pboard.pasteboardItems!
        var canAccept = false
        
        let readableClasses = [NSURL.self, NSString.self, NSAttributedString.self, NSPasteboardItem.self, PlayList.self, PlayItem.self]
        
        if pboard.canReadObject(forClasses: readableClasses, options: filteringOptions) {
            canAccept = true
        }
        else
        {
            for item in items {
                print("item: \(item)")
            }
        }
        print("web shouldAllowDrag -> \(canAccept) \(items.count) item(s)")
        return canAccept
    }
    
    var isReceivingDrag : Bool {
        get {
            return borderView.isReceivingDrag
        }
        set (value) {
            borderView.isReceivingDrag = value
        }
    }
    
    override func draggingEntered(_ info: NSDraggingInfo) -> NSDragOperation {
        let pboard = info.draggingPasteboard
        let items = pboard.pasteboardItems!
        let allow = shouldAllowDrag(info)
        if uiDelegate != nil { isReceivingDrag = allow }
        
        let dragOperation = allow ? .copy : NSDragOperation()
        print("web draggingEntered -> \(dragOperation) \(items.count) item(s)")
        return dragOperation
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let allow = shouldAllowDrag(sender)
        sender.animatesToDestination = true
        print("web prepareForDragOperation -> \(allow)")
        return allow
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("web draggingExited")
        if uiDelegate != nil { isReceivingDrag = false }
    }
    
    var lastDragSequence : Int = 0
    override func draggingUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        appDelegate.newViewOptions = appDelegate.getViewOptions
        let sequence = info.draggingSequenceNumber
        if sequence != lastDragSequence {
            print("web draggingUpdated -> .copy")
            lastDragSequence = sequence
        }
        return .copy
    }
    
	func addURL(_ url: URL, toKey: String) -> Bool {
		var urlAdded = false
		if var urls = defaults.array(forKey: toKey) {
			urls.append(url)
			defaults.setValue(urls, forKey: toKey)
			urlAdded = true
		}
		return urlAdded
	}
	
	func reportURLError(_ url: URL, error: Error) {
		let alert = NSAlert()
		alert.messageText = NSLocalizedString("ErrorTitle", comment: "")
		alert.informativeText = String(format: NSLocalizedString("ErrorMessage", comment: ""), url.lastPathComponent, error.localizedDescription)
		alert.addButton(withTitle: NSLocalizedString("OKTitle", comment: ""))
		alert.alertStyle = .warning
		alert.beginSheetModal(for: self.window!, completionHandler: nil)
	}

    // MARK: Drag and Drop - After Release
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        os_signpost(.begin, log: MyWebView.poi, name: "performDragOperation")
        defer { os_signpost(.end, log: MyWebView.poi, name: "performDragOperation") }
		let wvc : WebViewController = uiDelegate as! WebViewController
        
        var viewOptions = appDelegate.newViewOptions
        let options : [NSPasteboard.ReadingOptionKey: Any] =
            [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
             NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [
                kUTTypeImage, kUTTypeVideo, kUTTypeMovie, kUTTypeText, kUTTypePDF],
             NSPasteboard.ReadingOptionKey(rawValue: PlayList.className()) : true,
             NSPasteboard.ReadingOptionKey(rawValue: PlayItem.className()) : true]
        let pboard = sender.draggingPasteboard
        let items = pboard.pasteboardItems
        let window = self.window!
        var handled = 0
        
		//  Use current window, as key re: new creations
		NSApp.activate(ignoringOtherApps: true)

        for item in items! {
            if handled == items!.count { break }
            
			if let urlString = item.string(forType: NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String)), urlString.count > 0 {
                handled += self.next(url: URL(string: urlString)!) ? 1 : 0
                continue
            }

            for type in pboard.types! {
                print("web type: \(type)")

                switch type {
                case .URL, .fileURL:
                    if let urlString = item.string(forType: type), let url = URL.init(string: urlString) {
                        // MARK: TODO: load new files in distinct windows when dirty
						if dirty || url.isFileURL { viewOptions.insert(.t_view) }
                        
                        if viewOptions.contains(.t_view) {
                            handled += appDelegate.openURLInNewWindow(url, context: window) ? 1 : 0
                        }
                        else
                        if viewOptions.contains(.w_view) {
                            handled += appDelegate.openURLInNewWindow(url) ? 1 : 0
                        }
                        else
                        {
                            handled += self.next(url: url) ? 1 : 0
                        }
                        //  Multiple files implies new windows
                        viewOptions.insert(.w_view)
                    }
                    else
                    if let data = item.data(forType: type), let url = KeyedUnarchiver.unarchiveObject(with: data) {
                        if viewOptions.contains(.t_view) {
                            handled += appDelegate.openURLInNewWindow(url as! URL , context: window) ? 1 : 0
                        }
                        else
                        if viewOptions.contains(.w_view) {
                            handled += appDelegate.openURLInNewWindow(url as! URL) ? 1 : 0
                        }
                        else
                        {
                            handled += self.next(url: url as! URL) ? 1 : 0
                        }
                        //  Multiple files implies new windows
                        viewOptions.insert(.w_view)
                    }
                    else
                    if let urls: Array<AnyObject> = pboard.readObjects(forClasses: [NSURL.classForCoder()], options: options) as Array<AnyObject>? {
                        for url in urls as! [URL] {
                            if viewOptions.contains(.t_view) {
                                handled += appDelegate.openURLInNewWindow(url, context: window) ? 1 : 0
                            }
                            else
                            if viewOptions.contains(.w_view) {
                                handled += appDelegate.openURLInNewWindow(url) ? 1 : 0
                            }
                            else
                            {
                                handled += load(URLRequest.init(url: url)) != nil ? 1 : 0
                            }

                            if let cvc : WebViewController = window.contentViewController as? WebViewController {
                                cvc.representedObject = url
                            }
                        }
                    }
                    
                case .rtf, .rtfd:
                    if let data = item.data(forType: type), let text = NSAttributedString(rtf: data, documentAttributes: nil) {
                        handled += self.text(text) ? 1 : 0
                    }
                    
                case .string, .tabularText:
                    if let text = item.string(forType: type) {
                        handled += self.text(text) ? 1 : 0
                    }

                case webarchive:
                    if let data = item.data(forType: type) {
                        let html = String(decoding: data, as: UTF8.self)
                        handled += self.html(html) ? 1 : 0
                    }
                    else
                    if let text = item.string(forType: type) {
                        print("\(type) text \(String(describing: text))")
                        handled += self.text(text) ? 1 : 0
                    }
                    else
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            handled += self.html(html) ? 1 : 0
                        }
                        else
                        {
                            print("\(type) prop \(String(describing: prop))")
                        }
                    }
 
                case chromeType:
                    if let data = item.data(forType: type) {
                        let html = String(decoding: data, as: UTF8.self)
                        if html.count > 0 {
                            handled += self.html(html) ? 1 : 0
                        }
                    }
                    if let text = item.string(forType: type) {
                        print("\(type) text \(String(describing: text))")
                        if text.count > 0 {
                            handled += self.text(text) ? 1 : 0
                        }
                    }
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            handled += self.html(html) ? 1 : 0
                        }
                        else
                        {
                            print("\(type) prop \(String(describing: prop))")
                        }
                    }

				case PasteboardFilePromiseContent,PasteboardFileURLPromise:
					Swift.print(String.init(data: item.data(forType: type)!, encoding: .utf8)! as String)

					if let promises = pboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) {
						guard 0 != promises.count else { continue }
						
						//	Just marshall URLs within a dynamic spot in defaults
						isReceivingDrag = true
						
						for promise in promises {
							if let promiseReceiver = promise as? NSFilePromiseReceiver {
								
								// Ask our file promise receiver to fulfull on their promise.
								promiseReceiver.receivePromisedFiles(atDestination: wvc.destinationURL,
																	 options: [:],
																	 operationQueue: wvc.filePromiseQueue) { (fileURL, error) in
									/** Finished copying the promised file.
										Back on the main thread, insert the newly created image file into the table view.
									*/
									OperationQueue.main.addOperation { [self] in
										if error != nil {
											self.reportURLError(fileURL, error: error!)
										} else {
											handled += self.next(url: fileURL) ? 1 : 0
										}
									}
								}
							}
						}
					}
					
				case PasteboardFilePasteLocation:
					Swift.print("\(type.rawValue) here")
/*
				case .rowDragType:
					if let data = item.data(forType: type) {
						handled += self.data(data) ? 1 : 0
					}
					
				case .playlist:
					if let data = item.data(forType: type) {
						var tally = 0
						do {
							let playlist = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [PlayList.self], from: data) as? PlayList
							for playitem in playlist!.list {
								Swift.print("item \(playitem.link.absoluteString)")
								tally += 1
							}
							handled += tally == playlist?.list.count ? 1 : 0
						} catch { }
					}

				case .playitem:
					if let data = item.data(forType: type) {
						do {
							let playitem = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [PlayItem.self], from: data) as? PlayItem
							if let link = playitem?.link {
								handled += self.next(url: link) ? 1 : 0
							}
						} catch { }
					}

				case .metaitem:
					if let data = item.data(forType: type) {
						handled += self.data(data) ? 1 : 0
					}
*/
                default:
                    print("unkn: \(type)")
					handled += super.performDragOperation(sender) ? 1 : 0 
///                    if let data = item.data(forType: type) {
///                        handled += self.data(data) ? 1 : 0
///                    }
                }
                if handled == items?.count { break }
            }
        }
        
        //  Either way signal we're done
        isReceivingDrag = false
        
        print("web performDragOperation -> \(handled == items?.count ? "true" : "false")")
        return handled == items?.count
    }
    
    //  MARK: Context Menu
    //
    //  Intercepted actions; capture state needed for avToggle()
	var pausePlayPressMenuItem : NSMenuItem?
    @objc @IBAction func pausePlayActionPress(_ sender: NSMenuItem) {
		if let item = pausePlayPressMenuItem {
			_ = item.target?.perform(item.action, with: item.representedObject)
			pausePlayPressMenuItem = nil
		}
    }
    
	var mutePressMenuItem : NSMenuItem?
    @objc @IBAction func muteActionPress(_ sender: NSMenuItem) {
		if let item = mutePressMenuItem {
			_ = item.target?.perform(item.action, with: item.representedObject)
			mutePressMenuItem = nil
		}
    }
    // MARK: TODO javascrit injection
    //	Capture Pause, Play, Mute action states
	func captureMenuItems(_ menu: NSMenu) {
        //  NOTE: cache original menu item so it does not disappear.c
        for title in ["Play", "Pause", "Mute"] {
            if let item = menu.item(withTitle: title) {
                if item.title == "Mute" {
					mutePressMenuItem = item.copy() as? NSMenuItem
					print("capture \(item.title) state: \(item.state) -> target:\(String(describing: item.target)) action:\(String(describing: item.action))")
                }
                else
                {
					pausePlayPressMenuItem = item.copy() as? NSMenuItem
					print("capture \(item.title) state: \(item.state) -> target:\(String(describing: item.target)) action:\(String(describing: item.action))")
				}
            }
        }
	}
	
    //  Actions used by contextual menu, or status item, or our app menu
    func publishContextualMenu(_ menu: NSMenu) {
        guard let window = self.window else { return }
        let wvc = window.contentViewController as! WebViewController
        let hpc = window.windowController as! HeliumController
        let document : Document = hpc.document as! Document
        let settings = (hpc.document as! Document).settings
        let autoHideTitle = hpc.autoHideTitlePreference
        let translucency = hpc.translucencyPreference
        
        //  Remove item(s) we cannot support
        for title in ["Enter Picture in Picture"] {
            if let item = menu.item(withTitle: title) {
                menu.removeItem(item)
            }
        }
        
        //  Alter item(s) we want to support
        for title in ["Download Video", "Enter Full Screen", "Open Video in New Window"] {
            if let item = menu.item(withTitle: title) {
                print("old: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
                if item.title.hasPrefix("Download") {
                    item.isHidden = true
                }
                else
                if item.title.hasSuffix("Enter Full Screen") {
                    item.target = appDelegate
                    item.action = #selector(appDelegate.toggleFullScreen(_:))
                    item.state = appDelegate.fullScreen != nil ? .on : .off
					item.tag = 2	/// .screen.rawVa;ue
                }
                else
                if self.url != nil {
                    item.representedObject = self.url
                    item.target = appDelegate
                    item.action = #selector(appDelegate.openVideoInNewWindowPress(_:))
                }
                else
                {
                    item.isEnabled = false
                }
//                print("new: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
            }
        }
        
        //  Intercept these actions so we can record them for later
		captureMenuItems(menu)
        var item: NSMenuItem

        item = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "")
        menu.addItem(item)
        item = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        menu.addItem(item)
        item = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "")
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())

        //  Add backForwardList navigation if any
        let back = backForwardList.backList
        let fore = backForwardList.forwardList
        if back.count > 0 || fore.count > 0 {
            item = NSMenuItem(title: "History", action: #selector(menuClicked(_:)), keyEquivalent: "")
            menu.addItem(item)
            let jump = NSMenu()
            item.submenu = jump

            for prev in back {
                item = NSMenuItem(title: prev.article, action: #selector(MyWebView.jump(to:)), keyEquivalent: "")
                item.toolTip = prev.url.absoluteString
                item.representedObject = prev
                jump.addItem(item)
            }
            if let curr = backForwardList.currentItem {
                item = NSMenuItem(title: curr.article, action: #selector(MyWebView.jump(to:)), keyEquivalent: "")
                item.toolTip = curr.url.absoluteString
                item.representedObject = curr
                item.state = .on
                jump.addItem(item)
            }
            for next in fore {
                item = NSMenuItem(title: next.article, action: #selector(MyWebView.jump(to:)), keyEquivalent: "")
                item.toolTip = next.url.absoluteString
                item.representedObject = next
                jump.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        //  Add tab support once present
        var tabItemUpdated = false
        if let tabs = self.window?.tabbedWindows, tabs.count > 0 {
            if tabs.count > 1 {
                item = NSMenuItem(title: "Tabs", action: #selector(menuClicked(_:)), keyEquivalent: "")
                menu.addItem(item)
                let jump = NSMenu()
                item.submenu = jump
                for tab in tabs {
                    item = NSMenuItem(title: tab.title, action: #selector(hpc.selectTabItem(_:)), keyEquivalent: "")
                    if tab == self.window { item.state = .on }
                    item.toolTip = tab.representedURL?.absoluteString
                    item.representedObject = tab
                    jump.addItem(item)
                }
            }
            item = NSMenuItem(title: "To New Window", action: #selector(window.moveTabToNewWindow(_:)), keyEquivalent: "")
            menu.addItem(item)
            item = NSMenuItem(title: "Show All Tabs", action: #selector(window.toggleTabOverview(_:)), keyEquivalent: "")
            menu.addItem(item)
            tabItemUpdated = true
        }
        if docController.documents.count > 1 {
            item = NSMenuItem(title: "Merge All Windows", action: #selector(window.mergeAllWindows(_:)), keyEquivalent: "")
            menu.addItem(item)
            tabItemUpdated = true
        }
        if tabItemUpdated { menu.addItem(NSMenuItem.separator()) }

        item = NSMenuItem(title: "New Window", action: #selector(docController.newDocument(_:)), keyEquivalent: "")
		item.tag = ViewOptions.w_view.rawValue
        item.target = docController
        menu.addItem(item)
        
        item = NSMenuItem(title: "New Playlist", action: #selector(docController.altDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.control
		item.tag = ViewOptions.i_view.rawValue
		item.representedObject = k.PlayType
        item.isAlternate = true
        item.target = docController
        menu.addItem(item)

		item = NSMenuItem(title: "New Incognito", action: #selector(docController.altDocument(_:)), keyEquivalent: "")
		item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
		item.tag = ViewOptions.i_view.rawValue
		item.representedObject = k.IcntType
		item.isAlternate = true
		item.target = docController
		menu.addItem(item)

		item = NSMenuItem(title: "New Tab", action: #selector(docController.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
		item.tag = ViewOptions.t_view.rawValue
        item.representedObject = self.window
        item.target = docController
        item.isAlternate = true
        menu.addItem(item)
        
        // MARK: TODO: Open/Load files in distinct windows
        let openLoad = url?.isFileURL ?? false
        item = NSMenuItem(title: openLoad ? "Open" : "Load", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subOpen = NSMenu()
        item.submenu = subOpen

        item = NSMenuItem(title: "File…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.toolTip = openLoad ? "… in new tab window" : "… in window"
        item.target = wvc
        subOpen.addItem(item)

        item = NSMenuItem(title: "File in new window…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
		item.tag = ViewOptions.w_view.rawValue
        item.isAlternate = true
        item.target = wvc
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "File in new tab…", action: #selector(WebViewController.openFilePress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
        item.representedObject = self.window
        item.isAlternate = true
        item.target = wvc
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "URL…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.target = wvc
        subOpen.addItem(item)

        item = NSMenuItem(title: "URL in new window…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
		item.tag = ViewOptions.w_view.rawValue
        item.representedObject = self.window
        item.isAlternate = true
        item.target = wvc
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "URL in new tab…", action: #selector(WebViewController.openLocationPress(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
		item.tag = ViewOptions.t_view.rawValue
        item.representedObject = self.window
        item.isAlternate = true
        item.target = wvc
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Playlists", action: #selector(AppDelegate.presentPlaylistSheet(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = appDelegate
        menu.addItem(item)

        item = NSMenuItem(title: "Preferences", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subPref = NSMenu()
        item.submenu = subPref

        item = NSMenuItem(title: "Auto-hide Title Bar", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subAuto = NSMenu()
        item.submenu = subAuto
        
        item = NSMenuItem(title: "Never", action: #selector(hpc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.tag = HeliumController.AutoHideTitlePreference.never.rawValue
        item.state = autoHideTitle == .never ? .on : .off
        item.target = hpc
        subAuto.addItem(item)
        item = NSMenuItem(title: "Outside", action: #selector(hpc.autoHideTitlePress(_:)), keyEquivalent: "")
        item.tag = HeliumController.AutoHideTitlePreference.outside.rawValue
        item.state = autoHideTitle == .outside ? .on : .off
        item.target = hpc
        subAuto.addItem(item)

        item = NSMenuItem(title: "Float Above", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subFloat = NSMenu()
        item.submenu = subFloat
        
        item = NSMenuItem(title: "All Spaces", action: #selector(hpc.floatOverSpacesPress), keyEquivalent: "")
        item.state = hpc.floatAboveAllPreference.contains(.oneSpace) ? .off : .on
        item.target = hpc
		item.tag = 0 /// .allSpace
        subFloat.addItem(item)

        item = NSMenuItem(title: "Single Space", action: #selector(hpc.floatOverSpacesPress), keyEquivalent: "")
        item.state = hpc.floatAboveAllPreference.contains(.oneSpace) ? .on : .off
        item.target = hpc
		item.tag = 1 /// .oneSpace
        subFloat.addItem(item)

        item = NSMenuItem(title: "Full Screen", action: #selector(hpc.floatOverSpacesPress(_:)), keyEquivalent: "")
        item.state = hpc.floatAboveAllPreference.contains(.screen) ? .on : .off
        item.target = hpc
		item.tag = 2 /// .screen
        subFloat.addItem(item)

        item = NSMenuItem(title: "User Agent", action: #selector(wvc.userAgentPress(_:)), keyEquivalent: "")
        item.target = wvc
        subPref.addItem(item)
        
        item = NSMenuItem(title: "Translucency", action: #selector(menuClicked(_:)), keyEquivalent: "")
        subPref.addItem(item)
        let subTranslucency = NSMenu()
        item.submenu = subTranslucency

        item = NSMenuItem(title: "Opacity", action: #selector(menuClicked(_:)), keyEquivalent: "")
        let opacity = settings.opacityPercentage.value
        subTranslucency.addItem(item)
        let subOpacity = NSMenu()
        item.submenu = subOpacity

        item = NSMenuItem(title: "10%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (10 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 10
        subOpacity.addItem(item)
        item = NSMenuItem(title: "20%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.isEnabled = translucency.rawValue > 0
        item.state = (20 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 20
        subOpacity.addItem(item)
        item = NSMenuItem(title: "30%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (30 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 30
        subOpacity.addItem(item)
        item = NSMenuItem(title: "40%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (40 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 40
        subOpacity.addItem(item)
        item = NSMenuItem(title: "50%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (50 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 50
        subOpacity.addItem(item)
        item = NSMenuItem(title: "60%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (60 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 60
        subOpacity.addItem(item)
        item = NSMenuItem(title: "70%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (70 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 70
        subOpacity.addItem(item)
        item = NSMenuItem(title: "80%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (80 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 80
        subOpacity.addItem(item)
        item = NSMenuItem(title: "90%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (90 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 90
        subOpacity.addItem(item)
        item = NSMenuItem(title: "100%", action: #selector(hpc.percentagePress(_:)), keyEquivalent: "")
        item.state = (100 == opacity ? .on : .off)
        item.target = hpc
        item.tag = 100
        subOpacity.addItem(item)

        item = NSMenuItem(title: "Never", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumController.TranslucencyPreference.never.rawValue
        item.state = translucency == .never ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Always", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumController.TranslucencyPreference.always.rawValue
        item.state = translucency == .always ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Over", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumController.TranslucencyPreference.mouseOver.rawValue
        item.state = translucency == .mouseOver ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)
        item = NSMenuItem(title: "Mouse Outside", action: #selector(hpc.translucencyPress(_:)), keyEquivalent: "")
        item.tag = HeliumController.TranslucencyPreference.mouseOutside.rawValue
        item.state = translucency == .mouseOutside ? .on : .off
        item.target = hpc
        subTranslucency.addItem(item)

		if let url = url, [k.http,k.https].contains(url.scheme) {
			item = NSMenuItem(title: "Archive", action: #selector(webViewController?.archivePress(_:)), keyEquivalent: "")
			item.representedObject = self.window
			item.target = wvc
			menu.addItem(item)
		}

        item = NSMenuItem(title: "Snapshot", action: #selector(webViewController?.snapshotPress(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Save", action: #selector(document.save(_:)) as Selector, keyEquivalent: "")
        item.representedObject = self.window
        item.target = document
        menu.addItem(item)
        
		item = NSMenuItem(title: "SaveAs", action: #selector(document.saveAs(_:)) as Selector, keyEquivalent: "")
		item.keyEquivalentModifierMask = NSEvent.ModifierFlags.option
		item.representedObject = self.window
		item.isAlternate = true
		item.target = document
		menu.addItem(item)

		item = NSMenuItem(title: "Search…", action: #selector(WebViewController.openSearchPress(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Close", action: #selector(Panel.performClose(_:)), keyEquivalent: "")
        item.target = hpc.window
        menu.addItem(item)
        
        menu.addItem(NSMenuItem.separator())
        
        item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
    }
    
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.title {
        default:
            return true
        }
    }
}

extension MyWebView : NSPasteboardItemDataProvider {
	func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
		if type == PasteboardFilePromiseContent {
			pasteboard?.setString("com.adobe.pdf", forType: type)
		}
		else
		if type == PasteboardFileURLPromise {
			guard let urlString = pasteboard?.string(forType: PasteboardFilePasteLocation),
				  let destinationFolderURL = URL(string: urlString) else { return }
		
			//	Build the fiel destination usign the receiver desination URL
			let destinationFileURL = destinationFolderURL.appendingPathComponent(self.url?.lastPathComponent ?? appDelegate.AppName + "." + k.hpi)
			let destDoc = Document.init()
			destDoc.fileURL = destinationFileURL
			destDoc.fileType = k.hpi
			do {
				try destDoc.write(to: destinationFileURL, ofType: k.hpi)
			} catch let error {
				NSApp.presentError(error)
				return
			}
			pasteboard?.setString(destinationFileURL.absoluteString, forType: type)
		}
	}
}
