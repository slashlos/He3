//
//  WebViewController.swift
//  He3 (Helium)
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017-2020 CD M Santiago. All rights reserved.
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
//        Swift.print("web borderView drawing \(isHidden ? "NO" : "YES")....")

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
        Swift.print("we want to stop something...")
        
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
            dict[k.text] = NSString.string(fromAsset: ident)
            dict[k.mime] = "text/html"
            
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
            data = text.data(using: .utf8)!
            
        case k.html:
            data = text.dataFromHexString()!
            do {
                let atrs = try NSAttributedString.init(data: data, options: [:], documentAttributes: nil)
                text = String(format: "<html><body><pre>%@</pre></body></html>", atrs)

            } catch let error as NSError {
                Swift.print("attributedString <- data: \(error.code):\(error.localizedDescription): \(text)")
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

    override class func handlesURLScheme(_ urlScheme: String) -> Bool {
        Swift.print("handleURLScheme: \(urlScheme)")
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
            return URL.init(string: incognito ? UserSettings.HomeStrkURL.value : UserSettings.HomePageURL.default)!
        }
    }
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
    
    @objc internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            Swift.print("Menu \(menuItem.title) clicked")
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
        Swift.print("evaluateJavaScript \(javaScriptString)")
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
            Swift.print("Unable to create mutable request \(String(describing: original.url))")
            return super.load(original) }
        guard let url = original.url else { return super.load(original) }
        Swift.print("load(_:Request) <= \(request)")
        
        let urlDomain = url.host
        let requestIsSecure = url.scheme == "https"
        var cookies = [HTTPCookie]()

        //  Fetch legal, relevant, authorized cookies
        for cookie in HTTPCookieStorage.shared.cookies(for: url) ?? [] {
            if cookie.name.contains("'") { continue } // contains a "'"
            if !cookie.domain.hasSuffix(urlDomain!) { continue }
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
        if let original = url.resolvedFinderAlias() { return next(url: original) }

        if url.isFileURL
        {
            if appDelegate.isSandboxed != appDelegate.storeBookmark(url: url) {
                Swift.print("Yoink, unable to sandbox \(url)")
                return false
            }
            let baseURL = url///appDelegate.authenticateBaseURL(url)
			
			if ["hpl",k.hpl,"hpi",k.hpi].contains(url.pathExtension) {
				return appDelegate.openURLInNewWindow(url, context: self.window)
			}
			else
			{
				return self.loadFileURL(url, allowingReadAccessTo: baseURL) != nil
			}
        }
        else
        if self.load(URLRequest(url: url)) != nil {
            doc.fileURL = url
            doc.save(doc)
            return true
        }
        return false
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
        let options : NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        if let hpc = heliumPanelController {
            hpc.mouseIdle = false
        }
    }

    // MARK: Drag and Drop - Before Release
    func shouldAllowDrag(_ info: NSDraggingInfo) -> Bool {
        guard let doc = webViewController?.document, doc.docGroup != .playlist else { return false }
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
                Swift.print("item: \(item)")
            }
        }
        Swift.print("web shouldAllowDrag -> \(canAccept) \(items.count) item(s)")
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
        Swift.print("web draggingEntered -> \(dragOperation) \(items.count) item(s)")
        return dragOperation
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let allow = shouldAllowDrag(sender)
        sender.animatesToDestination = true
        Swift.print("web prepareForDragOperation -> \(allow)")
        return allow
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        Swift.print("web draggingExited")
        if uiDelegate != nil { isReceivingDrag = false }
    }
    
    var lastDragSequence : Int = 0
    override func draggingUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        appDelegate.newViewOptions = appDelegate.getViewOptions
        let sequence = info.draggingSequenceNumber
        if sequence != lastDragSequence {
            Swift.print("web draggingUpdated -> .copy")
            lastDragSequence = sequence
        }
        return .copy
    }
    
    // MARK: Drag and Drop - After Release
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        os_signpost(.begin, log: MyWebView.poi, name: "performDragOperation")
        defer { os_signpost(.end, log: MyWebView.poi, name: "performDragOperation") }
        
        var viewOptions = appDelegate.newViewOptions
        let options : [NSPasteboard.ReadingOptionKey: Any] =
            [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly : true,
             NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes : [
                kUTTypeImage, kUTTypeVideo, kUTTypeMovie, kUTTypeText],
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
                Swift.print("web type: \(type)")

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
                        Swift.print("\(type) text \(String(describing: text))")
                        handled += self.text(text) ? 1 : 0
                    }
                    else
                    if let prop = item.propertyList(forType: type) {
                        if let html = String.init(data: prop as! Data, encoding: .utf8)  {
                            handled += self.html(html) ? 1 : 0
                        }
                        else
                        {
                            Swift.print("\(type) prop \(String(describing: prop))")
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
                        Swift.print("\(type) text \(String(describing: text))")
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
                            Swift.print("\(type) prop \(String(describing: prop))")
                        }
                    }
/*
                case .filePromise:
                    Swift.print(".filePromise")
                    break

                case .promise:
                    Swift.print(".promise")
                    break
*/
                default:
                    Swift.print("unkn: \(type)")

///                    if let data = item.data(forType: type) {
///                        handled += self.data(data) ? 1 : 0
///                    }
                }
                if handled == items?.count { break }
            }
        }
        
        //  Either way signal we're done
        isReceivingDrag = false
        
        Swift.print("web performDragOperation -> \(handled == items?.count ? "true" : "false")")
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
					Swift.print("capture \(item.title) state: \(item.state) -> target:\(String(describing: item.target)) action:\(String(describing: item.action))")
                }
                else
                {
					pausePlayPressMenuItem = item.copy() as? NSMenuItem
					Swift.print("capture \(item.title) state: \(item.state) -> target:\(String(describing: item.target)) action:\(String(describing: item.action))")
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
                Swift.print("old: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
                if item.title.hasPrefix("Download") {
                    item.isHidden = true
                }
                else
                if item.title.hasSuffix("Enter Full Screen") {
                    item.target = appDelegate
                    item.action = #selector(appDelegate.toggleFullScreen(_:))
                    item.state = appDelegate.fullScreen != nil ? .on : .off
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
//                Swift.print("new: \(title) -> target:\(String(describing: item.target)) action:\(String(describing: item.action)) tag:\(item.tag)")
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
        
        item = NSMenuItem(title: "New Incognito", action: #selector(docController.altDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
		item.tag = ViewOptions.i_view.rawValue
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
        
        item = NSMenuItem(title: "All Spaces Disabled", action: #selector(hpc.floatOverAllSpacesPress), keyEquivalent: "")
        item.state = settings.floatAboveAllPreference.value.contains(.disabled) ? .on : .off
        item.target = hpc
        subFloat.addItem(item)

        item = NSMenuItem(title: "Full Screen", action: #selector(hpc.floatOverFullScreenAppsPress(_:)), keyEquivalent: "")
        item.state = settings.floatAboveAllPreference.value.contains(.screen) ? .on : .off
        item.target = hpc
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

        item = NSMenuItem(title: "Snapshot", action: #selector(webViewController?.snapshot(_:)), keyEquivalent: "")
        item.representedObject = self.window
        item.target = wvc
        menu.addItem(item)
        
        item = NSMenuItem(title: "Save", action: #selector(document.save(_:)) as Selector, keyEquivalent: "")
        item.representedObject = self.window
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

class WebViewController: NSViewController, WKScriptMessageHandler, NSMenuDelegate, NSTabViewDelegate, WKHTTPCookieStoreObserver, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        DispatchQueue.main.async {
            let waitGroup = DispatchGroup()
            guard let url = self.webView.url, let urlDomain = url.host else { return }
            cookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    if cookie.domain.hasSuffix(urlDomain) {
                        waitGroup.enter()
                        self.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: { waitGroup.leave() })
                    }
                }
            }
        }
    }

    var defaults = UserDefaults.standard
    var document : Document? {
        get {
            if let document : Document = self.view.window?.windowController?.document as? Document {
                return document
            }
            return nil
        }
    }
    var heliumPanelController : HeliumController? {
        get {
            guard let hpc : HeliumController = self.view.window?.windowController as? HeliumController else { return nil }
            return hpc
        }
    }

    var trackingTag: NSView.TrackingRectTag? {
        get {
            return (self.webView.window?.windowController as? HeliumController)?.viewTrackingTag
        }
        set (value) {
            (self.webView.window?.windowController as? HeliumController)?.viewTrackingTag = value
        }
    }

    // MARK: View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        //  Programmatically create a new web view
        //  with shared config, prefs, cookies(?).
        webView.frame = view.frame
        view.addSubview(webView)
        
        //  Wire in ourselves as its delegate
        webView.navigationDelegate = self
        webView.uiDelegate = self

        borderView.frame = view.frame
        view.addSubview(borderView)

        view.addSubview(loadingIndicator)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.loadURL(urlFileURL:)),
            name: NSNotification.Name(rawValue: "LoadURL"),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.loadURL(urlString:)),
            name: NSNotification.Name(rawValue: "LoadURLString"),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.snapshot(_:)),
            name: NSNotification.Name(rawValue: "SnapshotAll"),
            object: nil)
        
        //  Watch command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.commandKeyDown(_:)),
            name: NSNotification.Name(rawValue: "commandKeyDown"),
            object: nil)
        /*
        //  Watch option + command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.optionAndCommandKeysDown(_:)),
            name: NSNotification.Name(rawValue: "optionAndCommandKeysDown"),
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avPlayerView(_:)),
            name: NSNotification.Name(rawValue: "AVPlayerView"),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wkScrollView(_:)),
            name: NSNotification.Name(rawValue: "NSScrollView"),
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(wkFlippedView(_:)),
            name: NSNotification.Name(rawValue: "WKFlippedView"),
            object: nil)

        //  We want to be notified when a player is added
        let originalDidAddSubviewMethod = class_getInstanceMethod(NSView.self, #selector(NSView.didAddSubview(_:)))
        let originalDidAddSubviewImplementation = method_getImplementation(originalDidAddSubviewMethod!)
        
        typealias DidAddSubviewCFunction = @convention(c) (AnyObject, Selector, NSView) -> Void
        let castedOriginalDidAddSubviewImplementation = unsafeBitCast(originalDidAddSubviewImplementation, to: DidAddSubviewCFunction.self)
        
        let newDidAddSubviewImplementationBlock: @convention(block) (AnyObject?, NSView) -> Void = { (view: AnyObject!, subview: NSView) -> Void in
            castedOriginalDidAddSubviewImplementation(view, Selector(("didAddsubview:")), subview)
//            Swift.print("view: \(subview.className)")
            if subview.className == "AVPlayerView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AVPlayerView"), object: subview)
            }
            if subview.className == "NSScrollView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "NSScrollView"), object: subview)
            }
            if subview.className == "WKFlippedView" {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "WKFlippedView"), object: subview)
            }
        }
        
        let newDidAddSubviewImplementation = imp_implementationWithBlock(unsafeBitCast(newDidAddSubviewImplementationBlock, to: AnyObject.self))
        method_setImplementation(originalDidAddSubviewMethod!, newDidAddSubviewImplementation)*/
        
        // WebView KVO - load progress, title
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.loading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
    
        //  Intercept drags
        webView.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0)})
        webView.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        webView.registerForDraggedTypes(Array(webView.acceptableTypes))
        observing = true
        
        //  Watch javascript selection messages unless already done
        let controller = webView.configuration.userContentController
        guard controller.userScripts.count == 0 else { return }
        
        controller.add(self, name: "newWindowWithUrlDetected")
        controller.add(self, name: "newSelectionDetected")
        controller.add(self, name: "newUrlDetected")

        let js = NSString.string(fromAsset: "He3-js")
        let script = WKUserScript.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)
        
        //  make http: -> https: guarded by preference
        if UserSettings.PromoteHTTPS.value {
            //  https://developer.apple.com/videos/play/wwdc2017/220/ 14:05, 21:04
            let jsonString = """
                [{
                    "trigger" : { "url-filter" : ".*" },
                    "action" : { "type" : "make-https" }
                }]
            """
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "httpRuleList", encodedContentRuleList: jsonString, completionHandler: {(list, error) in
                guard let contentRuleList = list else { fatalError("emptyRulelist after compilation!") }
                controller.add(contentRuleList)
            })
        }
        
        // TODO: Watch click events
        // https://stackoverflow.com/questions/45062929/handling-javascript-events-in-wkwebview/45063303#45063303
        /*
        let source = "document.addEventListener('click', function(){ window.webkit.messageHandlers.clickMe.postMessage('clickMe clickMe!'); })"
        let clickMe = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        controller.addUserScript(clickMe)
        controller.add(self, name: "clickMe")
        */
        //  Dealing with cookie changes
        let cookieChangeScript = WKUserScript.init(source: "window.webkit.messageHandlers.updateCookies.postMessage(document.cookie);",
            injectionTime: .atDocumentStart, forMainFrameOnly: false)
        controller.addUserScript(cookieChangeScript)
        controller.add(self, name: "updateCookies")
    }
    /*
    @objc func avPlayerView(_ note: NSNotification) {
        print("AV Player \(String(describing: note.object)) will be opened now")
        guard let view = note.object as? NSView else { return }
        
        Swift.print("player is \(view.className)")
    }
    
    @objc func wkFlippedView(_ note: NSNotification) {
        print("A Player \(String(describing: note.object)) will be opened now")
        guard let view = note.object as? NSView, let scrollView = view.enclosingScrollView else { return }
        
        if scrollView.hasHorizontalScroller {
            scrollView.horizontalScroller?.isHidden = true
        }
        if scrollView.hasVerticalScroller {
            scrollView.verticalScroller?.isHidden = true
        }
    }
    
    @objc func wkScrollView(_ note: NSNotification) {
        print("WK Scroll View \(String(describing: note.object)) will be opened now")
        if let scrollView : NSScrollView = note.object as? NSScrollView {
            scrollView.autohidesScrollers = true
        }
    }*/
    
    override func viewWillLayout() {
        super.viewWillLayout()

        //  the autolayout is complete only when the view has appeared.
        if 0 == webView.constraints.count {
			webView.autoresizingMask = [.height,.width]
			webView.fit(view)
		}
        
        if 0 == borderView.constraints.count {
			borderView.autoresizingMask = [.height,.width]
			borderView.fit(view)
		}
        
        if 0 == loadingIndicator.constraints.count { loadingIndicator.center(view)
		}
    }

    override func viewWillAppear() {
        super.viewWillAppear()

		//	document.fileURL is recent, webView.url is current URL
        if let document = self.document, let url = document.fileURL {
			if url != webView.url {
				switch document.fileType {
				case k.Playitem:
					if let link = document.items.first?.list.first?.link {
						_ = loadURL(url: link)
					}
					
				case k.Playlist:
					break
					
				default:
					_ = loadURL(url: url)
				}
			}
			else
			{
				webView.needsDisplay = true
			}
		}
        else
        {
            clear()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        guard let doc = self.document, doc.docGroup != .playlist else { return }
        
        //  https://stackoverflow.com/questions/32056874/programmatically-wkwebview-inside-an-uiview-with-auto-layout
 
        //  the autolayout is complete only when the view has appeared.
        webView.autoresizingMask = [.height,.width]
        if 0 == webView.constraints.count { webView.fit(webView.superview!) }
        
        borderView.autoresizingMask = [.height,.width]
        if 0 == borderView.constraints.count { borderView.fit(borderView.superview!) }
        
        loadingIndicator.center(loadingIndicator.superview!)
        loadingIndicator.bind(NSBindingName(rawValue: "animate"), to: webView as Any, withKeyPath: "loading", options: nil)
        
        //  ditch loading indicator background
        loadingIndicator.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
    }
    
    @objc dynamic var observing : Bool = false
    
    func setupTrackingAreas(_ establish: Bool) {
        if let tag = trackingTag {
            view.removeTrackingRect(tag)
            trackingTag = nil
        }
        if establish {
            trackingTag = view.addTrackingRect(view.bounds, owner: self, userData: nil, assumeInside: false)
        }
        webView.updateTrackingAreas()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()

        //  TODO: ditch horizonatal scroll when not over
        if let scrollView = self.webView.enclosingScrollView {
            if scrollView.hasHorizontalScroller {
                scrollView.horizontalScroller?.isHidden = true
            }
            if scrollView.hasVerticalScroller {
                scrollView.verticalScroller?.isHidden = true
            }
        }

        setupTrackingAreas(true)
    }
    
    override func viewWillDisappear() {
        super .viewWillDisappear()
        
        guard let wc = self.view.window?.windowController, !wc.isKind(of: ReleasePanelController.self) else { return }
        if let navDelegate : NSObject = webView.navigationDelegate as? NSObject {
        
            webView.stopLoading()
            webView.uiDelegate = nil
            webView.navigationDelegate = nil

            // Wind down all observations
            if observing {
                webView.removeObserver(navDelegate, forKeyPath: "estimatedProgress")
                webView.removeObserver(navDelegate, forKeyPath: "loading")
                webView.removeObserver(navDelegate, forKeyPath: "title")
                observing = false
            }
        }
    }

    // MARK: Actions
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool{
        switch menuItem.title {
        case "Back":
            return webView.canGoBack
        case "Forward":
            return webView.canGoForward
        default:
            return true
        }
    }

    @objc @IBAction func backPress(_ sender: AnyObject) {
        webView.goBack()
    }
    
    @objc @IBAction func forwardPress(_ sender: AnyObject) {
        webView.goForward()
    }
    
    @objc internal func optionKeyDown(_ notification : Notification) {
        
    }
    
    @objc internal func cancel(_ sender: AnyObject)
    {
        webView.stopLoading()
    }
    
    @objc internal func commandKeyDown(_ notification : Notification) {
		//	Don't bother unless we're a first responder
		guard self.view.window == NSApp.keyWindow, [webView].contains(self.view.window?.firstResponder) else { return }

        let commandKeyDown : NSNumber = notification.object as! NSNumber
        if let window = self.view.window {
            window.isMovableByWindowBackground = commandKeyDown.boolValue
///            Swift.print(String(format: "CMND %@", commandKeyDown.boolValue ? "v" : "^"))
        }
    }
    /*
    @objc internal func optionAndCommandKeysDown(_ notification : Notification) {
        Swift.print("optionAndCommandKeysDown")
        snapshot(self)
    }
    */
	@objc @IBAction func saveDocument(_ sender: Any) {
		self.document?.save(sender)
	}
	
    fileprivate func zoomIn() {
        webView.magnification += 0.1
    }
    
    fileprivate func zoomOut() {
        webView.magnification -= 0.1
    }
    
    fileprivate func resetZoom() {
        webView.magnification = 1
    }

    @objc @IBAction func openFilePress(_ sender: AnyObject) {
        var viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window
        let open = NSOpenPanel()
        
        open.allowsMultipleSelection = true
        open.canChooseDirectories = false
        open.resolvesAliases = true
        open.canChooseFiles = true
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)

        open.worksWhenModal = true
        open.beginSheetModal(for: window!, completionHandler: { (response: NSApplication.ModalResponse) in
            if response == .OK {
                // MARK: TODO: load new files in distinct windows
                if self.webView.dirty { viewOptions.insert(.t_view) }

                let urls = open.urls
                var handled = 0

                for url in urls {
                    if viewOptions.contains(.t_view) {
                        handled += appDelegate.openURLInNewWindow(url, context: window) ? 1 : 0
                    }
                    else
                    if viewOptions.contains(.w_view) {
                        handled += appDelegate.openURLInNewWindow(url) ? 1 : 0
                    }
                    else
                    {
                        handled += self.webView.next(url: url) ? 1 : 0
                    }
                    
                    //  Multiple files implies new windows
                    viewOptions.insert(.w_view)
                }
            }
        })
    }
    
    @objc @IBAction func openLocationPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window
        var urlString = currentURLString
        
        if let rawString = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() {
            urlString = rawString
        }

        appDelegate.didRequestUserUrl(RequestUserStrings (
            currentURLString:   urlString,
            alertMessageText:   "URL to load",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.HomePageURL.value),
                                      onWindow: window as? Panel,
                                      title: "Enter URL",
                                      acceptHandler: { (urlString: String) in
                                        guard let newURL = URL.init(string: urlString) else { return }
                                        
                                        if viewOptions.contains(.t_view) {
                                            _ = appDelegate.openURLInNewWindow(newURL, context: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            _ = appDelegate.openURLInNewWindow(newURL)
                                        }
                                        else
                                        {
                                            _ = self.webView.next(url: newURL) ? 1 : 0
                                        }
        })
    }
    @objc @IBAction func openSearchPress(_ sender: AnyObject) {
        let viewOptions = ViewOptions(rawValue: sender.tag)
        let window = self.view.window

        let name = k.searchNames[ UserSettings.Search.value ]
        let info = k.searchInfos[ UserSettings.Search.value ]

        appDelegate.didRequestSearch(RequestUserStrings (
            currentURLString:   nil,
            alertMessageText:   "Search",
            alertButton1stText: name,         alertButton1stInfo: info,
            alertButton2ndText: "Cancel",     alertButton2ndInfo: nil,
            alertButton3rdText: "New Window", alertButton3rdInfo: "Results in new window"),
                                     onWindow: self.view.window as? Panel,
                                     title: "Web Search",
                                     acceptHandler: { (newWindow: Bool, searchURL: URL) in
                                        if viewOptions.contains(.t_view) {
                                            _ = appDelegate.openURLInNewWindow(searchURL, context: window)
                                        }
                                        else
                                        if viewOptions.contains(.w_view) {
                                            _ = appDelegate.openURLInNewWindow(searchURL)
                                        }
                                        else
                                        {
                                            _ = self.loadURL(url: searchURL)
                                        }
        })
    }

    @objc @IBAction fileprivate func reloadPress(_ sender: AnyObject) {
        requestedReload()
    }
    
    @objc @IBAction fileprivate func clearPress(_ sender: AnyObject) {
        clear()
    }
    
    @objc @IBAction fileprivate func resetZoomLevel(_ sender: AnyObject) {
        resetZoom()
    }
    
    @IBAction func snapshot(_ sender: Any) {
        guard let window = self.view.window, window.isVisible else { return }
        webView.takeSnapshot(with: nil) { image, error in
            if let image = image {
                self.webImageView.image = image
                DispatchQueue.main.async {
                    self.processSnapshotImage(image)
                }
            }
            else
            {
				self.userAlertMessage("Failed taking snapshot", info: error?.localizedDescription)
                self.webImageView.image = nil
            }
        }
    }
    
    func processSnapshotImage(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation else { NSSound(named: "Sosumi")?.play(); return }
         
        //  1st around authenticate and cache sandbox data if needed
        if appDelegate.isSandboxed, appDelegate.desktopData == nil {
            var desktop =
                UserSettings.SnapshotsURL.value.count == 0
                    ? appDelegate.getDesktopDirectory()
                    : URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value, isDirectory: true)
            
            let openPanel = NSOpenPanel()
            openPanel.message = "Authorize access to Snapshots"
            openPanel.prompt = "Authorize"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.directoryURL = desktop
            openPanel.begin() { (result) -> Void in
                if (result == .OK) {
                    desktop = openPanel.url!
                    _ = appDelegate.storeBookmark(url: desktop, options: appDelegate.rwOptions)
                    appDelegate.desktopData = appDelegate.bookmarks[desktop]
                    UserSettings.SnapshotsURL.value = desktop.absoluteString
                    if !appDelegate.saveBookmarks() {
                        Swift.print("Yoink, unable to save desktop booksmark(s)")
                    }
                }
            }
        }
        
        //  Form a filename: ~/"<app's name> View Shot <timestamp>"
        var name : String
        if let url = webView.url, url != webView.homeURL { name = url.lastPathComponent } else { name = appDelegate.AppName }
        let path = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value).appendingPathComponent(
            String(format: "%@ Shapshot at %@.png", name, String.prettyStamp()))
        
        let bitmapImageRep = NSBitmapImageRep(data: tiffData)
        
        //  With sandbox clearance to the desktop...
        do
        {
            try bitmapImageRep?.representation(using: .png, properties: [:])?.write(to: path)
            // https://developer.apple.com/library/archive/qa/qa1913/_index.html
            if let asset = NSDataAsset(name:"Grab") {

                do {
                    // Use NSDataAsset's data property to access the audio file stored in Sound.
                    let player = try AVAudioPlayer(data:asset.data, fileTypeHint:"caf")
                    // Play the above sound file.
                    player.play()
                } catch {
                    Swift.print("no sound for you")
                }
            }
            if path.hideFileExtensionInPath(), let name = path.lastPathComponent.removingPercentEncoding {
                Swift.print("Snaphot => \(name)")
            }
        } catch let error {
            NSApp.presentError(error)
            NSSound(named: "Sosumi")?.play()
        }
    }
    
    @objc @IBAction func userAgentPress(_ sender: AnyObject) {
        appDelegate.didRequestUserAgent(RequestUserStrings (
              currentURLString:   webView.customUserAgent,
              alertMessageText:   "Custom user agent",
            alertButton1stText:   "Set",      alertButton1stInfo: nil,
            alertButton2ndText:   "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText:   "Default",  alertButton3rdInfo: UserSettings.UserAgent.default),
                      onWindow:   self.view.window as? Panel,
                         title:   "Custom User Agent",
                 acceptHandler: { (newUserAgent: String) in
                                self.webView.customUserAgent = newUserAgent
        }
        )
    }

    @objc @IBAction fileprivate func zoomIn(_ sender: AnyObject) {
        zoomIn()
    }
    @objc @IBAction fileprivate func zoomOut(_ sender: AnyObject) {
        zoomOut()
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
            Swift.print("represented object \(String(describing: representedObject))")
        }
    }
    
    // MARK: Loading
    
    internal var currentURLString: String? {
        return webView.url?.absoluteString
    }

    internal func loadURL(text: String) -> Bool {
        let text = UrlHelpers.ensureScheme(text)
        if let url = URL(string: text) {
            return webView.load(URLRequest.init(url: url)) != nil
        }
        return false
    }

    internal func loadURL(url: URL) -> Bool {
        return webView.next(url: url)
    }

    @objc internal func loadURL(urlFileURL: Notification) -> Bool {
        if let fileURL = urlFileURL.object, let userInfo = urlFileURL.userInfo {
            if userInfo["hwc"] as? NSWindowController == self.view.window?.windowController {
                return loadURL(url: fileURL as! URL)
            }
            else
            {
                //  load new window with URL
                return loadURL(url: urlFileURL.object as! URL)
            }
        }
        return false
    }
    
    @objc func loadURL(urlString: Notification) -> Bool {
        if let userInfo = urlString.userInfo {
            if userInfo["hwc"] as? NSWindowController != self.view.window?.windowController {
                return false
            }
        }
        
        if let string = urlString.object as? String {
            return loadURL(text: string)
        }
        return false
    }
    
    func loadAttributes(dict: Dictionary<String,Any>) {
        Swift.print("loadAttributes: dict \(dict)")
    }
    
    func loadAttributes(item: PlayItem) {
        loadAttributes(dict: item.dictionary())
    }
    
    // TODO: For now just log what we would play once we figure out how to determine when an item finishes so we can start the next
    @objc func playerDidFinishPlaying(_ note: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: note.object)
        print("Video Finished")
    }
    
    fileprivate func requestedReload() {
        webView.reload()
    }
    
    // MARK: Javascript
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        ///Swift.print("UCC \(message.name) => \"\(message.body)\"")
        
        switch message.name {
        case "newWindowWithUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                ///Swift.print("new win -> \(url.absoluteString)")
            }
            
        case "newSelectionDetected":
            if let urlString : String = message.body as? String
            {
                webView.selectedText = urlString
                ///Swift.print("new str -> \(urlString)")
            }
            
        case "newUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                ///Swift.print("new url -> \(url.absoluteString)")
            }
            
        case "clickMe":
            ///Swift.print("message: \(message.body)")
            break
            
        case "updateCookies":
            guard appDelegate.shareWebCookies,appDelegate.storeWebCookies else { return }
            let updates = (message.body as! String).components(separatedBy: "; ")
            ///Swift.print("cookie(\(updates.count)) \(message.body)")

            for update in updates {
                let keyval = update.components(separatedBy: "=")
                if keyval.count < 2 { continue }
                
                if let url = webView.url, let cookies : [HTTPCookie] = HTTPCookieStorage.shared.cookies(for: url) {
                    let cookieStorage = HTTPCookieStorage.shared
                    var localCookie : HTTPCookie?

                    for cookie in cookies {
                        if cookie.name == keyval.first! { localCookie = cookie; break }
                    }
                    
                    if let cookie = localCookie {
                        var properties : Dictionary<HTTPCookiePropertyKey,Any> = (cookie.properties as AnyObject).mutableCopy() as! Dictionary<HTTPCookiePropertyKey, Any>
                        properties[HTTPCookiePropertyKey("HTTPCookieValue")] = keyval.last!
                        if let updated = HTTPCookie.init(properties: properties) {
                            cookieStorage.setCookie(updated)
                            ///Swift.print("+ cookie \(update)")
                        }
                    }
                }
            }
            
        default:
            userAlertMessage("Unhandled user controller message", info: message.name)
        }
    }

    // MARK: Webview functions
    // https://stackoverflow.com/a/56338070/564870
    class func clean() {
        guard #available(iOS 9.0, *) else {return}

        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                #if DEBUG
                    print("WKWebsiteDataStore record deleted:", record)
                #endif
            }
        }
    }
    
    func clear() {
        // Reload to home page (or default if no URL stored in UserDefaults)
        _ = webView.load(URLRequest.init(url: webView.homeURL))
    }

	var webView = MyWebView()
	var webImageView = NSImageView.init()
	var webSize = CGSize(width: 0,height: 0)
    
    var borderView : WebBorderView {
        get {
            return webView.borderView
        }
    }
    var loadingIndicator : ProgressIndicator {
        get {
            return webView.loadingIndicator
        }
    }
	
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let mwv = object as? MyWebView, mwv == self.webView else { return }

        //  We *must* have a key path
        guard let keyPath = keyPath else { return }
        
        switch keyPath {
        case "estimatedProgress":

            if let progress = change?[NSKeyValueChangeKey(rawValue: "new")] as? Float {
                let percent = progress * 100
                var title : String = String(format: "Loading... %.2f%%", percent)
                if percent == 100, let url = (self.webView.url) {

                    //  Initial recording for this url session
                    if UserSettings.HistorySaves.value, !webView.incognito {
                        let notif = Notification(name: Notification.Name(rawValue: "NewURL"), object: url, userInfo: [k.fini : false, k.view : self.webView as Any])
                        NotificationCenter.default.post(notif)
                    }
                    
                    // once loaded update window title,size with video name,dimension
                    if let toolTip = (mwv.url?.absoluteString) {
                        if url.isFileURL {
                            title = url.lastPathComponent
                        } else
                        if let doc = self.document {
                            title = doc.displayName
                        }
                        else
                        {
                            title = appDelegate.AppName
                        }
                        self.heliumPanelController?.hoverBar?.superview?.toolTip = toolTip.removingPercentEncoding

                        if let track = AVURLAsset(url: url, options: nil).tracks.first {

                            //    if it's a video file, get and set window content size to its dimentions
                            if track.mediaType == AVMediaType.video {
                                
                                webSize = track.naturalSize
                                
                                //  Try to adjust initial size if possible
                                let os = appDelegate.os
                                switch (os.majorVersion, os.minorVersion, os.patchVersion) {
                                case (10, 10, _), (10, 11, _), (10, 12, _):
                                    if let oldSize = mwv.window?.contentView?.bounds.size, oldSize != webSize, var origin = mwv.window?.frame.origin, let theme = self.view.window?.contentView?.superview {
                                        var iterator = theme.constraints.makeIterator()
                                        ///Swift.print(String(format:"view:%p webView:%p", mwv.superview!, mwv))
                                        while let constraint = iterator.next()
                                        {
                                            Swift.print("\(constraint.priority) \(constraint)")
                                        }
                                        
                                        origin.y += (oldSize.height - webSize.height)
                                        mwv.window?.setContentSize(webSize)
                                        mwv.window?.setFrameOrigin(origin)
                                        mwv.bounds.size = webSize
                                    }
                                    
                                default:
                                    //  Issue still to be resolved so leave as-is for now
                                    Swift.print("os \(os)")
                                    if webSize != webView.fittingSize {
                                        webView.bounds.size = webView.fittingSize
                                        webSize = webView.bounds.size
                                    }
                                }
                            }
                            
                            //  Wait for URL to finish
                            let videoPlayer = AVPlayer(url: url)
                            let item = videoPlayer.currentItem
                            NotificationCenter.default.addObserver(self, selector: #selector(WebViewController.playerDidFinishPlaying(_:)),
                                                                             name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)

                            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    Swift.print("restarting #1")
                                    videoPlayer.seek(to: CMTime.zero)
                                    videoPlayer.play()
                                }
                            })
                            
                            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    Swift.print("restarting #2")
                                    videoPlayer.seek(to: CMTime.zero)
                                    videoPlayer.play()
                                }
                            })
                        }
                    } else {
                        title = appDelegate.AppName
                    }
                    
					//	Once we're bookmarked, we cannot be used on another sandbo
					if appDelegate.isBookmarked(url) { webView.dirty = true }
					
                    // Remember for later restoration
                    NSApp.changeWindowsItem(self.view.window!, title: title, filename: false)
                }
            }
            
        case "loading":
            guard let loading = change?[NSKeyValueChangeKey(rawValue: "new")] as? Bool, loading == loadingIndicator.isHidden else { return }
            Swift.print("loading: \(loading ? "YES" : "NO")")
            
        case "title":
            if let newTitle = change?[NSKeyValueChangeKey(rawValue: "new")] as? String {
                if let window = self.view.window {
                    window.title = newTitle
                    NSApp.changeWindowsItem(window, title: newTitle, filename: false)
                }
            }
             
        case "url":///currently *not* KVO ?
            if let urlString = change?[NSKeyValueChangeKey(rawValue: "new")] as? String {
                guard let dict = defaults.dictionary(forKey: urlString) else { return }
                
                if let doc = self.document {
                    doc.restoreSettings(with: dict)
                }
            }

        default:
            Swift.print("Unknown observing keyPath \(String(describing: keyPath))")
        }
    }
    
    //Convert a YouTube video url that starts at a certian point to popup/embedded design
    // (i.e. ...?t=1m2s --> ?start=62)
    func makeCustomStartTimeURL(_ url: String) -> String {
        let startTime = "?t="
        let idx = url.indexOf(startTime)
        if idx == -1 {
            return url
        } else {
            let timeIdx = idx.advanced(by: 3)
            let hmsString = url[timeIdx...].replacingOccurrences(of: "h", with: ":").replacingOccurrences(of: "m", with: ":").replacingOccurrences(of: "s", with: ":")
            
            var returnURL = url
            var final = 0
            
            let hms = hmsString.components(separatedBy: ":")
            if hms.count > 2, let hrs = Int(hms[2]) {
                final += 3600 * hrs
            }
            if hms.count > 1, let mins = Int(hms[1]) {
                final += 60 * mins
            }
            if hms.count > 0, let secs = Int(hms[0]) {
                final += secs
            }
            
            returnURL.removeSubrange(returnURL.index(returnURL.startIndex, offsetBy: idx+1) ..< returnURL.endIndex)
            returnURL = "?start="

            returnURL = returnURL + String(final)
            
            return returnURL
        }
    }
    
    //Helper function to return the hash of the video for encoding a popout video that has a start time code.
    fileprivate func getVideoHash(_ url: String) -> String {
        let startOfHash = url.indexOf(".be/")
        let endOfHash = startOfHash.advanced(by: 4)
        let restOfUrl = url.indexOf("?t")
        let hash = url[url.index(url.startIndex, offsetBy: endOfHash) ..< (endOfHash == -1 ? url.endIndex : url.index(url.startIndex, offsetBy: restOfUrl))]
        return String(hash)
    }
    
	var quickLookURL : URL?
	var quickLookFilename: String?
	func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { return 1 }
	func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
		let url = quickLookURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(quickLookFilename!)
		return url as QLPreviewItem
	}

    //  MARK:- TabView Delegate
    
    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            Swift.print("tab willSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            Swift.print("tab didSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }

//  https://stackoverflow.com/a/56580009/564870

    func loadFileSync(_ sourceURL: URL, to targetURL: URL, completion: @escaping (String?, Error?) -> Void)
    {
        if FileManager().fileExists(atPath: targetURL.path)
        {
            print("File already exists [\(targetURL.path)]")
            completion(targetURL.path, nil)
        }
        else if let dataFromURL = NSData(contentsOf: sourceURL)
        {
            if dataFromURL.write(to: targetURL, atomically: true)
            {
                print("file saved [\(targetURL.path)]")
                completion(targetURL.path, nil)
            }
            else
            {
                print("error saving file")
                let error = NSError(domain:"Error saving file", code:1001, userInfo:nil)
                completion(targetURL.path, error)
            }
        }
        else
        {
            let error = NSError(domain:"Error downloading file", code:1002, userInfo:nil)
            completion(targetURL.path, error)
        }
    }

    func loadFileAsync(_ sourceURL: URL, to targetURL: URL, completion: @escaping (String?, Error?) -> Void)
    {
        if FileManager().fileExists(atPath: targetURL.path)
        {
            ///print("File already exists [\(targetURL.path)]")
            completion(targetURL.path, nil)
        }
        else
        {
            let session = URLSession(configuration: appDelegate.sessionConfiguration, delegate: nil, delegateQueue: nil)
            var request = URLRequest(url: sourceURL)
            request.httpMethod = "GET"
            let task = session.dataTask(with: request, completionHandler:
            {
                data, response, error in
                if error == nil
                {
                    if let response = response as? HTTPURLResponse
                    {
                        if response.statusCode == 200
                        {
                            if let data = data
                            {
                                if let _ = try? data.write(to: targetURL, options: Data.WritingOptions.atomic)
                                {
                                    completion(targetURL.path, error)
                                }
                                else
                                {
                                    completion(targetURL.path, error)
                                }
                            }
                            else
                            {
                                completion(targetURL.path, error)
                            }
                        }
                    }
                }
                else
                {
                    completion(targetURL.path, error)
                }
            })
            task.resume()
        }
    }
}

class ReleaseViewController : WebViewController {

}
