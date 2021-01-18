//
//  WebViewController.swift
//  He3 (Helium)
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017-2021 CD M Santiago. All rights reserved.
//

import Cocoa
import WebKit
import WebArchiver
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

extension Selector {
	static let archive = #selector(WebViewController.archive(_:))
	static let snapshot = #selector(WebViewController.snapshot(_:))
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
            return (self.webView.window?.windowController as? HeliumController)?.wholeTrackingTag
        }
        set (value) {
            (self.webView.window?.windowController as? HeliumController)?.wholeTrackingTag = value
        }
    }

	// Queue used for reading file (URL) promises.
	var filePromiseQueue: OperationQueue = {
		let queue = OperationQueue()
		return queue
	}()
	lazy var destinationURL: URL = {
		let dragKey = String(format: "%@://drag.%ld)", k.local, webView.lastDragSequence)
		let destinationURL = URL.init(string: dragKey)
		if nil == defaults.array(forKey: dragKey) {
			defaults.setValue([URL](), forKey: dragKey)
		}
		return destinationURL!
	}()

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
			selector: #selector(WebViewController.archiveAll(_:)),
			name: NSNotification.Name(rawValue: "ArchiveAll"),
			object: nil)
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
            selector: #selector(WebViewController.snapshotAll(_:)),
            name: NSNotification.Name(rawValue: "SnapshotAll"),
            object: nil)
        
        //  Watch command key changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WebViewController.commandKeyDown(_:)),
            name: .commandKeyDown,
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
//            print("view: \(subview.className)")
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
        
        // WebView KVO - load progress, title, url
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.loading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
		webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

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

		//	Our main / app wide injections
		for type in (["css","js"]) {
			let name = k.AppName + "." + type
			let asset = NSString.string(fromAsset: name)
			let script = WKUserScript.init(source: asset, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
			controller.addUserScript(script)
		}
		
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
		
		clear()
    }
    /*
    @objc func avPlayerView(_ note: NSNotification) {
        print("AV Player \(String(describing: note.object)) will be opened now")
        guard let view = note.object as? NSView else { return }
        
        print("player is \(view.className)")
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
    
	var viewLayoutDone = false
    override func viewWillLayout() {
		super.viewWillLayout()
		
		guard !viewLayoutDone else { return }
		
        //  the autolayout is complete only when the view has appeared.
		webView.autoresizingMask = [.height,.width]
		webView.fit(view)
        
        borderView.autoresizingMask = [.height,.width]
		borderView.fit(view)
        
		loadingIndicator.center(view)
		viewLayoutDone = true
    }

    override func viewWillAppear() {
        super.viewWillAppear()

		//	document.fileURL is recent, webView.url is current URL
		if let doc = self.document, let url = doc.fileURL, url.absoluteString != k.blank {
			if url != webView.url || [.playitem,.playlist].contains(doc.docGroup) {
				//	Initially, but after window restoration, restore saved frame
				if let window = self.view.window,
					!NSEqualRects(window.frame, doc.settings.rect.value),
					!NSEqualSizes(NSZeroSize, doc.settings.rect.value.size) {
					window.setFrame(doc.settings.rect.value, display: true)
				}
				
				if [.playitem].contains(doc.docGroup) {
					if ![k.hpi,k.h3i].contains(url.lastPathComponent) {
						_ = loadURL(url: url)
					}
					else
					if let link = doc.items.first?.list.first?.link {
						if link.absoluteString == k.blank {
							clear()
						}
						else
						{
							_ = loadURL(url: link)
						}
					}
				}
				else
				if [.playlist].contains(doc.docGroup) {
					// nothing to do here
				}
				else
				{
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
    
	var viewAppeared = false
    override func viewDidAppear() {
        super.viewDidAppear()
        
		guard let doc = self.document, ![k.PlayType,k.PlayName].contains(doc.fileType) else { return }
		guard !viewAppeared else { return }
		
        //  https://stackoverflow.com/questions/32056874/programmatically-wkwebview-inside-an-uiview-with-auto-layout
 
        //  the autolayout is complete only when the view has appeared.
        webView.autoresizingMask = [.height,.width]
        webView.fit(webView.superview!)
        
        borderView.autoresizingMask = [.height,.width]
		borderView.fit(borderView.superview!)
        
        loadingIndicator.center(loadingIndicator.superview!)
        loadingIndicator.bind(NSBindingName(rawValue: "animate"), to: webView as Any, withKeyPath: "loading", options: nil)
        
        //  ditch loading indicator background
        loadingIndicator.appearance = NSAppearance.init(named: NSAppearance.Name.aqua)
		viewAppeared = true
    }
    
    @objc dynamic var observing : Bool = false
	
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
    }

    override func viewWillDisappear() {
        super .viewWillDisappear()
        
        if let navDelegate : NSObject = webView.navigationDelegate as? NSObject {
        
            webView.stopLoading()
            webView.uiDelegate = nil
            webView.navigationDelegate = nil

            // Wind down all observations
            if observing {
				webView.removeObserver(navDelegate, forKeyPath: #keyPath(WKWebView.estimatedProgress))
				webView.removeObserver(navDelegate, forKeyPath: #keyPath(WKWebView.loading))
				webView.removeObserver(navDelegate, forKeyPath: #keyPath(WKWebView.title))
				webView.removeObserver(navDelegate, forKeyPath: #keyPath(WKWebView.url))/*
				webView.removeObserver(navDelegate, forKeyPath: "estimatedProgress")
                webView.removeObserver(navDelegate, forKeyPath: "loading")
                webView.removeObserver(navDelegate, forKeyPath: "title")
				webView.removeObserver(navDelegate, forKeyPath: "url")*/
                observing = false
            }
        }
    }

    // MARK: Actions
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
///            print(String(format: "CMND %@", commandKeyDown.boolValue ? "v" : "^"))
        }
    }
    /*
    @objc internal func optionAndCommandKeysDown(_ notification : Notification) {
        print("optionAndCommandKeysDown")
        snapshot(self)
    }
    */
	@objc @IBAction func archivePress(_ sender: NSMenuItem) {
		guard let url = webView.url, !url.isFileURL else { return }
		guard [k.http,k.https].contains(url.scheme) else { return }
		let window = self.view.window!
		
		let filename = webView.title ?? (url.lastPathComponent as NSString).deletingPathExtension
		let archiveURL = URL.init(fileURLWithPath: filename).appendingPathExtension(k.webarchive)

		let savePanel = NSSavePanel()
		savePanel.canCreateDirectories = true
		savePanel.allowedFileTypes = [k.webarchive]
		savePanel.showsTagField = false
		savePanel.nameFieldStringValue = archiveURL.lastPathComponent
		savePanel.beginSheetModal(for: window, completionHandler: { [self] (result: NSApplication.ModalResponse) in
			if result == .OK, let saveURL = savePanel.url {
				sender.representedObject = saveURL
				archive(sender)
			}
		})
	}
	
	@objc func archive(_ sender: NSMenuItem) {
		guard let url = self.webView.url, !url.isFileURL else { return }
		guard var archiveURL = sender.representedObject as? URL else { return }
		
		//	archiveALL URL has only destination, so add name and extension
		if sender.tag == 1 {
			let filename = webView.title ?? (url.lastPathComponent as NSString).deletingPathExtension
			archiveURL.appendPathComponent(filename)
			archiveURL = archiveURL.appendingPathExtension(k.webarchive)
		}
		
		webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
			self.webView.loadingIndicator.startAnimation(sender)
			
			WebArchiver.archive(url: url, cookies: cookies) { result in
				
				if let data = result.plistData {
					do {
						try data.write(to: archiveURL)
						if archiveURL.hideFileExtensionInPath(), let name = archiveURL.lastPathComponent.removingPercentEncoding {
							print("archive => \(name)")
						}
					} catch {
						appDelegate.userAlertMessage("Web page store failed", info: error.localizedDescription)
					}
				} else if let firstError = result.errors.first {
					appDelegate.userAlertMessage("Web page store failed", info: firstError.localizedDescription)
				}
				self.webView.loadingIndicator.stopAnimation(sender)
			}
		}
	}

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
                // FIXME: load new files in distinct windows
				if self.webView.dirty || appDelegate.isSandboxed { viewOptions.insert(.t_view) }

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
    
	@objc @IBAction func snapshotPress(_ sender: NSMenuItem) {
		guard let url = webView.url, url != webView.homeURL else { return }
		guard let snapshotURL = sender.representedObject as? URL else {
			//	Dispatch to app delegate to handle a singleton
			sender.representedObject = self
			appDelegate.snapshotAllPress(sender)
			return
		}
		
		sender.representedObject = snapshotURL
		snapshot(sender)
	}
	
    @objc func snapshot(_ sender: NSMenuItem) {
		guard let url = webView.url, url != webView.homeURL else { return }
		guard var snapshotURL = sender.representedObject as? URL else { return }
		
		//	URL has only destination, so add name and extension
		let filename = String(format: "%@ Shapshot at %@",
							  (url.lastPathComponent as NSString).deletingPathExtension,
							  String.prettyStamp())
		snapshotURL.appendPathComponent(filename)
		snapshotURL = snapshotURL.appendingPathExtension("png")
		
        webView.takeSnapshot(with: nil) { image, error in
            if let image = image {
                self.webImageView.image = image
                DispatchQueue.main.async {
					self.processSnapshotImage(image, to: snapshotURL)
                }
            }
            else
            {
				self.userAlertMessage("Failed taking snapshot", info: error?.localizedDescription)
                self.webImageView.image = nil
            }
        }
    }
    
    func processSnapshotImage(_ image: NSImage, to snapshotURL: URL) {
		guard let tiffData = image.tiffRepresentation else { NSSound.playIf(.sosumi); return }
        let bitmapImageRep = NSBitmapImageRep(data: tiffData)

        do
        {
            try bitmapImageRep?.representation(using: .png, properties: [:])?.write(to: snapshotURL)
            // https://developer.apple.com/library/archive/qa/qa1913/_index.html
			NSSound.playIf(.grab)
			
            if snapshotURL.hideFileExtensionInPath(), let name = snapshotURL.lastPathComponent.removingPercentEncoding {
                print("snapshot => \(name)")
            }
        } catch let error {
			appDelegate.userAlertMessage("Snapshot failed", info: error.localizedDescription)
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
	
	@objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.title {
		case "Back":
			return webView.canGoBack
		case "Forward":
			return webView.canGoForward
		case "Archive":
			if let url = webView.url {
				menuItem.isEnabled = !url.isFileURL
			}
			else
			{
				menuItem.isEnabled = false
			}
		default:
			return true
		}
		return true
	}
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
            print("represented object \(String(describing: representedObject))")
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
        print("loadAttributes: dict \(dict)")
    }
    
    func loadAttributes(item: PlayItem) {
        loadAttributes(dict: item.dictionary())
    }
    
	@objc func archiveAll(_ note: Notification) {
		archive(note.object as! NSMenuItem)
	}
	
	@objc func snapshotAll(_ note: Notification) {
		snapshot(note.object as! NSMenuItem)
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
        ///print("UCC \(message.name) => \"\(message.body)\"")
        
        switch message.name {
        case "newWindowWithUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                ///print("new win -> \(url.absoluteString)")
            }
            
        case "newSelectionDetected":
            if let urlString : String = message.body as? String
            {
                webView.selectedText = urlString
                ///print("new str -> \(urlString)")
            }
            
        case "newUrlDetected":
            if let url = URL.init(string: message.body as! String) {
                webView.selectedURL = url
                ///print("new url -> \(url.absoluteString)")
            }
            
        case "clickMe":
            ///print("message: \(message.body)")
            break
            
        case "updateCookies":
            guard appDelegate.shareWebCookies,appDelegate.storeWebCookies else { return }
            let updates = (message.body as! String).components(separatedBy: "; ")
            ///print("cookie(\(updates.count)) \(message.body)")

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
                            ///print("+ cookie \(update)")
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
						let notif = Notification(name: .newTitle, object: self.webView, userInfo: [k.fini : false])
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
						self.heliumPanelController?.titleView?.toolTip = toolTip.removingPercentEncoding

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
                                        ///print(String(format:"view:%p webView:%p", mwv.superview!, mwv))
                                        while let constraint = iterator.next()
                                        {
                                            print("\(constraint.priority) \(constraint)")
                                        }
                                        
                                        origin.y += (oldSize.height - webSize.height)
                                        mwv.window?.setContentSize(webSize)
                                        mwv.window?.setFrameOrigin(origin)
                                        mwv.bounds.size = webSize
                                    }
                                    
                                default:
                                    //  Issue still to be resolved so leave as-is for now
                                    print("os \(os)")
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
                                    print("restarting #1")
                                    videoPlayer.seek(to: CMTime.zero)
                                    videoPlayer.play()
                                }
                            })
                            
                            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item, queue: .main, using: { (_) in
                                DispatchQueue.main.async {
                                    print("restarting #2")
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
            print("loading: \(loading ? "YES" : "NO")")
            
        case "title":
            if let newTitle = change?[NSKeyValueChangeKey(rawValue: "new")] as? String {
                if let window = self.view.window {
                    window.title = newTitle
                    NSApp.changeWindowsItem(window, title: newTitle, filename: false)
                }
            }
             
        case "url","URL":/// #keyPath(WKWebView.url)
			///DispatchQueue.main.async { self.webView.icon = self.iconForURL() }
			
            if let urlString = change?[NSKeyValueChangeKey(rawValue: "new")] as? String {
				guard let doc = self.document else { return }
				if let dict = defaults.dictionary(forKey: urlString) {
                    doc.restoreSettings(with: dict)
                }
				
				doc.update(to: URL(string: urlString)!)
				if let hpc = heliumPanelController {
					hpc.updateTitleBar(didChange: true)
				}
            }

        default:
            print("Unknown observing keyPath \(String(describing: keyPath))")
        }
    }
	
	func iconForURL() -> NSImage {
		let webView = self.webView
		
		guard let url = webView.url, url.absoluteString != UserSettings.HomePageURL.value else {
			return NSApp.applicationIconImage }

		if [k.http,k.https].contains(url.scheme), let host = url.host {
			let urlString = String(format: "http://www.google.com/s2/favicons?%@", host)
			if let imageURL = URL(string: urlString) {
				do {
					let imageData = try Data(contentsOf: imageURL)
					if  let image = NSImage(data: imageData) {
						return image
					}
				} catch { }
			}
		}
		
		if k.file == url.scheme {
			return iconForFileURL(url)
		}
		
		return NSApp.applicationIconImage
	}
	
	func iconForFileURL(_ url : URL) -> NSImage {
		let size = NSSize(width: 12, height: 12)
		let ref = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL, size, nil)
		if let cgImage = ref?.takeUnretainedValue() {
			let thumbnailImage = NSImage(cgImage: cgImage, size: size)
			ref?.release()
			return thumbnailImage
		}
		return NSImage(named: k.docIcon)!
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
            print("tab willSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            print("tab didSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
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
