//
//  AppDelegate.swift
//  He3 (Helium)
//
//  Created by Jaden Geller on 4/9/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//  Copyright © 2017-2021 CD M Santiago. All rights reserved.
//
//  We have user IBAction centrally here, share by panel and webView controllers
//  The design is to centrally house the preferences and notify these interested
//  parties via notification.  In this way all menu state can be consistency for
//  statusItem, main menu, and webView contextual menu.
//
import Cocoa
import CoreLocation
import ServiceManagement
import OSLog
import AppKit
import WebKit
import AVKit
import AudioToolbox
import CoreAudioKit

struct RequestUserStrings {
    let currentURLString: String?
    let alertMessageText: String
    let alertButton1stText: String
    let alertButton1stInfo: String?
    let alertButton2ndText: String
    let alertButton2ndInfo: String?
    let alertButton3rdText: String?
    let alertButton3rdInfo: String?
}

fileprivate class SearchField : NSSearchField {
    var title : String?
    var borderColor : NSColor?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
    
    convenience init(withValue: String?, modalTitle: String?) {
        self.init()
        
        if let string = withValue {
            self.stringValue = string
        }
        if let title = modalTitle {
            self.title = title
        }
        else
        {
            self.title = (NSApp.delegate as! AppDelegate).title
        }
        if let cell : NSSearchFieldCell = self.cell as? NSSearchFieldCell {
            cell.searchMenuTemplate = searchMenu()
            cell.usesSingleLineMode = false
            cell.wraps = true
            cell.lineBreakMode = .byWordWrapping
            cell.formatter = nil
            cell.allowsEditingTextAttributes = false
        }
        (self.cell as! NSSearchFieldCell).searchMenuTemplate = searchMenu()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
 
        if let color = borderColor {
            ///self.layer?.borderColor = color.cgColor
            let path = NSBezierPath.init(rect: frame)
            path.lineWidth = 3
            color.setStroke()
            path.stroke()
            
            if self.window?.firstResponder == self.currentEditor() && NSApp.isActive {
                NSGraphicsContext.saveGraphicsState()
                NSFocusRingPlacement.only.set()
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
    
    fileprivate func searchMenu() -> NSMenu {
        let menu = NSMenu.init(title: "Search Menu")
        var item : NSMenuItem
        
        item = NSMenuItem.init(title: "Clear", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.clearRecentsMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.separator()
        item.tag = NSSearchField.recentsTitleMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.init(title: "Recent Searches", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsTitleMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.init(title: "Recent", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsTitleMenuItemTag
        menu.addItem(item)
        
        item = NSMenuItem.init(title: "Recent Searches", action: nil, keyEquivalent: "")
        item.tag = NSSearchField.recentsMenuItemTag
        menu.addItem(item)
        
        return menu
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let title = self.title {
            self.window?.title = title
        }
        
        // MARK: this gets us focus even when modal
        self.becomeFirstResponder()
    }
}

class URLField: NSTextField {
    var title : String?
    var borderColor: NSColor?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
    
    convenience init(withValue: String?, modalTitle: String?) {
        self.init()
        
        if let string = withValue {
            self.stringValue = string
        }
        if let title = modalTitle {
            self.title = title
        }
        else
        {
            let infoDictionary = (Bundle.main.infoDictionary)!
            
            //    Get the app name field
            let AppName = infoDictionary[kCFBundleExecutableKey as String] as? String ?? k.AppName
            
            //    Setup the version to one we constrict
            self.title = String(format:"%@ %@", AppName,
                               infoDictionary["CFBundleVersion"] as! CVarArg)
        }
        self.cell?.controlView?.wantsLayer = true
        self.cell?.controlView?.layer?.borderWidth = 1
        self.lineBreakMode = .byTruncatingHead
        self.usesSingleLineMode = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let color = borderColor {
            ///self.layer?.borderColor = color.cgColor
            let path = NSBezierPath.init(rect: frame)
            path.lineWidth = 3
            color.setStroke()
            path.stroke()
            
            if self.window?.firstResponder == self.currentEditor() && NSApp.isActive {
                NSGraphicsContext.saveGraphicsState()
                NSFocusRingPlacement.only.set()
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let title = self.title {
            self.window?.title = title
        }

        // MARK: this gets us focus even when modal
        self.becomeFirstResponder()
    }
}

struct ViewOptions : OptionSet {
    let rawValue: Int
    
    static let w_view            = ViewOptions(rawValue: 1 << 0)
    static let t_view            = ViewOptions(rawValue: 1 << 1)
	static let i_view			 = ViewOptions(rawValue: 1 << 2)
}
let sameWindow : ViewOptions = []

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, CLLocationManagerDelegate {
    static let poi = OSLog(subsystem: "com.slashlos.he3", category: .pointsOfInterest)

    //  who we are from 'about'
    var _AppName: String?
    var  AppName: String {
        get {
            if _AppName == nil {
                let infoDictionary = (Bundle.main.infoDictionary)!
                
                //    Get the app name field
                _AppName = infoDictionary[kCFBundleExecutableKey as String] as? String ?? k.AppName
				assert(_AppName == k.AppName, "AppName mistach in defaults vs Info.plist")
            }
            return _AppName!
        }
    }

    func getDesktopDirectory() -> URL {
        let homedir = FileManager.default.homeDirectoryForCurrentUser
        let desktop = homedir.appendingPathComponent(k.desktop, isDirectory: true)
        return desktop
    }
    
    //  return key state for external paths
    var newViewOptions : ViewOptions = sameWindow
    var getViewOptions : ViewOptions {
        get {
            var viewOptions = ViewOptions()
            if shiftKeyDown { viewOptions.insert(.w_view) }
            if optionKeyDown { viewOptions.insert(.t_view) }
            return viewOptions
        }
    }
	
	var docController : DocumentController {
		get {
			return NSDocumentController.shared as! DocumentController
		}
	}
	var fileManager : FileManager {
		get {
			return FileManager.default
		}
	}
	
	var os = ProcessInfo().operatingSystemVersion
	@objc @IBOutlet weak var magicURLMenu: NSMenuItem!

	//	MARK:- Audio Video Services
	internal func avStatus(for media: AVMediaType) -> AVAuthorizationStatus {
		let status = AVCaptureDevice.authorizationStatus(for: media)
		switch status {
			case .authorized: // The user has previously granted access to the microphone.
				return .authorized
			
			case .notDetermined: // The user has not yet been asked for microphone access.
				return .notDetermined
			
			case .denied: // The user has previously denied access.
				return .denied

			case .restricted: // The user can't grant access due to restrictions.
				return .restricted
			default:
				Swift.print("Unknown AV status \(status) for .audio")
				return status
		}
	}

	@objc @IBAction func audioVideoServicesPress(_ sender: AnyObject) {
		let service = sender.title.components(separatedBy: " ").last
		let media : AVMediaType = service == "Audio" ? .audio : .video
		let status = self.avStatus(for: media)
		
		guard ![.denied,.restricted].contains(status) else {
			sheetOKCancel("Access denied or restriced.",
						  info: "Launch Security & Privacy settings app?",
						  acceptHandler:
				{ (button) in
					//  Make them confirm first
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						if let PrivacyLocationServices = media == .audio
							? URL.PrivacyMicrophoneServices : URL.PrivaryCameraServices {
							NSWorkspace.shared.open(PrivacyLocationServices)
						}
					}
				})
			return
		}
		
		if status == .authorized {
			sheetOKCancel("Access can only be stopped in privacy app.",
						  info: "Launch Security & Privacy settings app?",
						  acceptHandler:
				{ (button) in
					//  Make them confirm first
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						if let PrivacyLocationServices = media == .audio
							? URL.PrivacyMicrophoneServices : URL.PrivaryCameraServices {
							NSWorkspace.shared.open(PrivacyLocationServices)
						}
					}
				})
		}
		else
		{
			AVCaptureDevice.requestAccess(for: media, completionHandler: { [self] granted in
				if !granted {
					sheetOKCancel("Access not granted.",
								  info: "Launch Security & Privacy settings app?",
								  acceptHandler:
						{ (button) in
							//  Make them confirm first
							if button == NSApplication.ModalResponse.alertFirstButtonReturn {
								if let PrivacyLocationServices = media == .audio
									? URL.PrivacyMicrophoneServices : URL.PrivaryCameraServices {
									NSWorkspace.shared.open(PrivacyLocationServices)
								}
							}
						}
				)}
			})
	    }
    }
	
	//	MARK: quickQuiet to affect system volume
	@objc func quickQuiet(_ note: Notification) {
		willChangeValue(forKey: "inQuickQuietMode")

		//	Infer muted state when current volume is 0
		let volume = systemAudioVolume
		
		if !inQuickQuietMode {
			self.systemAudioVolume = lastSystemAudioVolume
		}
		else
		{
			self.systemAudioVolume = 0.0
			lastSystemAudioVolume = volume
		}
		
		didChangeValue(forKey: "inQuickQuietMode")
	}

	//	https://stackoverflow.com/a/27291862/564870
	dynamic var inQuickQuietMode = false
	dynamic var lastSystemAudioVolume = Float(0.0)
	
	var defaultAudioDeviceID : AudioDeviceID {
		get {
			var defaultOutputDeviceID = AudioDeviceID(0)
			var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

			var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
				mSelector: kAudioHardwarePropertyDefaultOutputDevice,
				mScope: kAudioObjectPropertyScopeGlobal,
				mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

			let status1 = AudioObjectGetPropertyData(
				AudioObjectID(kAudioObjectSystemObject),
				&getDefaultOutputDevicePropertyAddress,
				0,
				nil,
				&defaultOutputDeviceIDSize,
				&defaultOutputDeviceID)
			
			guard (status1 == 0) else {
				Swift.print("Unable to obtain default system audio device ID: \(status1)")
				return AudioDeviceID(0)
			}
			return defaultOutputDeviceID
		}
	}
	
	var systemAudioVolume: Float {
		get {
			let defaultOutputDeviceID = self.defaultAudioDeviceID
			_ = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

			var volume = Float32(0.0)
			var volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

			var volumePropertyAddress = AudioObjectPropertyAddress(
				mSelector: kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
				mScope: kAudioDevicePropertyScopeOutput,
				mElement: kAudioObjectPropertyElementMaster)

			let status3 = AudioObjectGetPropertyData(
				defaultOutputDeviceID,
				&volumePropertyAddress,
				0,
				nil,
				&volumeSize,
				&volume)
			
			guard (status3 == 0) else {
				Swift.print("Unable to obtain system volumn level: \(status3)")
				return lastSystemAudioVolume
			}
			return volume
		}
		set (level) {
			let defaultOutputDeviceID = self.defaultAudioDeviceID
			
			var volume = level // 0.0 ... 1.0
			let volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

			var volumePropertyAddress = AudioObjectPropertyAddress(
				mSelector: kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
				mScope: kAudioDevicePropertyScopeOutput,
				mElement: kAudioObjectPropertyElementMaster)

			let status2 = AudioObjectSetPropertyData(
				defaultOutputDeviceID,
				&volumePropertyAddress,
				0,
				nil,
				volumeSize,
				&volume)
			
			guard (status2 == 0) else {
				Swift.print("Unable to set system volume level: \(status2)")
				return
			}
		}
	}
	
	//	MARK:- Location Services
    //  For those site that require your location while we're active
    var locationManager : CLLocationManager?
	var locationStatus : CLAuthorizationStatus {
		return CLLocationManager.authorizationStatus()
	}
    var isLocationEnabled : Bool {
        get {
			guard nil != locationManager else { return false }
            return [.authorized].contains(locationStatus)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		let status = CLLocationManager.authorizationStatus()
		
		let notif = Notification(name: .locationServiceChange, object: status)
		NotificationCenter.default.post(notif)
		
		self.didChangeValue(forKey: "isLocationEnabled")
    }
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		sheetOKCancel(error.localizedDescription,
					  info: "Launch Security & Privacy settings app?",
					  acceptHandler:
			{ (button) in
				//  Make them confirm first
				if button == NSApplication.ModalResponse.alertFirstButtonReturn {
					if let PrivacyLocationServices = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
						NSWorkspace.shared.open(PrivacyLocationServices)
					}
				}
			}
		)
	}
	

    // MARK:- Shared webView resources
    var _webProcessPool : WKProcessPool?
    var  webProcessPool : WKProcessPool {
        get {
            if  _webProcessPool == nil {
                _webProcessPool = WKProcessPool()
            }
            return _webProcessPool!
        }
    }
    
    var _sessionConfiguration : URLSessionConfiguration?
    var  sessionConfiguration : URLSessionConfiguration {
        get {
            if  _sessionConfiguration == nil {
				if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
					_sessionConfiguration = URLSessionConfiguration.default
				} else {
					_sessionConfiguration = URLSessionConfiguration()
				}
				
                _sessionConfiguration!.httpCookieAcceptPolicy = UserSettings.AcceptWebCookie.value ?.onlyFromMainDocumentDomain : .never
                _sessionConfiguration!.httpShouldSetCookies = UserSettings.StoreWebCookies.value
            }
            return _sessionConfiguration!
        }
    }
    var acceptWebCookie = UserSettings.AcceptWebCookie.value
    var shareWebCookies = UserSettings.ShareWebCookies.value
    var storeWebCookies = UserSettings.StoreWebCookies.value
    
    var _webConfiguration : WKWebViewConfiguration?
    var  webConfiguration : WKWebViewConfiguration {
        get {
            if  _webConfiguration == nil {
                _webConfiguration = WKWebViewConfiguration()
 
                //  Prime process pool among views using share
                _webConfiguration!.processPool = webProcessPool
                
                //  Prime our preferendes
                _webConfiguration!.preferences = webPreferences
                _webConfiguration!.suppressesIncrementalRendering = false

                //  Support our internal (local) schemes
                _webConfiguration!.setURLSchemeHandler(CacheSchemeHandler(), forURLScheme: k.scheme)
				_webConfiguration!.setURLSchemeHandler(CacheSchemeHandler(), forURLScheme: k.local)

                // Use nonPersistent() or default() depending on if you want cookies persisted to disk
                // and shared between WKWebViews of the same app (default), or not persisted and not shared
                // across WKWebViews in the same app.
                if shareWebCookies {
                    let cookies = HTTPCookieStorage.shared.cookies ?? [HTTPCookie]()
                    let dataStore = shareWebCookies ? WKWebsiteDataStore.default() : WKWebsiteDataStore.nonPersistent()
                    let waitGroup = DispatchGroup()
                    for cookie in cookies {
                        waitGroup.enter()
                        dataStore.httpCookieStore.setCookie(cookie) { waitGroup.leave() }
                    }
                    waitGroup.notify(queue: DispatchQueue.main, execute: {
                        self._webConfiguration?.websiteDataStore = dataStore
                    })
                 }
            }
            return _webConfiguration!
        }
    }
    var _webPreferences : WKPreferences?
    var  webPreferences : WKPreferences {
        get {
            if  _webPreferences == nil {
                _webPreferences = WKPreferences()
                
                // Allow plug-ins such as silverlight
				if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
				} else {
					_webPreferences!.plugInsEnabled = true
				}
				
                ///_webPreferences!.minimumFontSize = 14
                _webPreferences!.javaScriptCanOpenWindowsAutomatically = true;
                _webPreferences!.javaScriptEnabled = true
				if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
				} else {
					_webPreferences!.javaEnabled = true
				}
				
				//	Always enable inspector but guard its showing
				_webPreferences?.setValue(true, forKey: "developerExtrasEnabled")
            }
            return _webPreferences!
        }
    }
    
    //  MARK:- Global IBAction, but ship to keyWindow when able
    @objc @IBOutlet weak var appMenu: NSMenu!
	var appStatusItem:NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    fileprivate var searchField : SearchField = SearchField.init(withValue: k.AppName, modalTitle: "Search")

    @objc dynamic var _webSearches : [PlayItem]?
    @objc dynamic var  webSearches : [PlayItem] {
        get {
            if  _webSearches == nil {
                _webSearches = [PlayItem]()
                
                // Restore search name change
                if let searchesName = self.defaults.string(forKey: UserSettings.SearchNames.keyPath), searchesName != UserSettings.SearchNames.value {
                    UserSettings.SearchNames.value = searchesName
                }
                
                if let items = self.defaults.array(forKey: UserSettings.SearchNames.keyPath) {
                    
                    // Load histories from defaults up to their maximum
                    for playitem in items {
                        if let name : String = playitem as? String, let dict = defaults.dictionary(forKey: name) {
                            self._webSearches?.append(PlayItem(from: dict))
                        }
                        else
                        if let dict : Dictionary <String,AnyObject> = playitem as? Dictionary <String,AnyObject> {
                            self._webSearches?.append(PlayItem(from: dict))
                        }
                        else
                        {
                            print("unknown search \(playitem)")
                        }
                    }
                    print("\(self._webSearches!.count) search(es) restored")
                }
            }
            return _webSearches!
        }
        set (array) {
            _webSearches = array
        }
        
    }
    fileprivate func addWebSearcheURL(_ seaString: String, searchURL: URL) {
        let seaTime = Date.init().timeIntervalSinceReferenceDate
        let item = PlayItem(name: seaString, link: searchURL, time: seaTime, rank: 0)
        
        webSearches.append(item)
    }
    
    var recentSearches : Array<String> {
        get {
            var searches = Array<String>()
            for search in webSearches {
                searches.append(search.name.removingPercentEncoding!)
            }
            return searches
        }
    }
    
    var title : String {
        get {
            //    Setup the version to one we constrict
            let title = String(format:"%@ %@", AppName, Version)

            return title
        }
    }
	
	var Version : String {
		let infoDictionary = (Bundle.main.infoDictionary)!
		
		return infoDictionary["CFBundleVersion"] as! CVarArg as! String
	}
	
    @objc internal func menuClicked(_ sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            print("Menu '\(menuItem.title)' clicked")
        }
    }
    internal func syncAppMenuVisibility() {
        if UserSettings.HideAppMenu.value {
            NSStatusBar.system.removeStatusItem(appStatusItem)
        }
        else
        {
            appStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            appStatusItem.button?.image = NSImage.init(named: "statusIcon")
            let menu : NSMenu = appMenu.copy() as! NSMenu

            //  add quit to status menu only - already is in dock
            let item = NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "")
            item.target = NSApp
            menu.addItem(item)

            appStatusItem.menu = menu
        }
    }
	@objc @IBAction func hideAppStatusItem(_ sender: NSMenuItem) {
		UserSettings.HideAppMenu.value = (sender.state == .off)
        self.syncAppMenuVisibility()
	}
    @objc @IBAction func homePagePress(_ sender: AnyObject) {
        didRequestUserUrl(RequestUserStrings (
            currentURLString:   UserSettings.HomePageURL.value,
            alertMessageText:   "New home page",
            alertButton1stText: "Set",      alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Default",  alertButton3rdInfo: UserSettings.HomePageURL.default),
                          onWindow: NSApp.keyWindow as? Panel,
                          title: "Enter URL",
                          acceptHandler: { (newUrl: String) in
                            UserSettings.HomePageURL.value = newUrl
        }
        )
    }

    //  Restore operations are progress until open
    @objc dynamic var openForBusiness = false
    
	@objc @IBAction func archiveAllPress(_ sender: NSMenuItem) {
		registerSnaphotsURL(sender) { (snapshotURL) in
			//	If we have a return object just call them, else notify all
			if let wvc : WebViewController = sender.representedObject as? WebViewController {
				sender.representedObject = snapshotURL
				wvc.archive(sender)
			}
			else
			{
				sender.representedObject = snapshotURL
				let notif = Notification(name: .archiveAll, object: sender)
				NotificationCenter.default.post(notif)
			}
		}
	}
	
    //  By defaut we show document title bar
    @objc @IBAction func autoHideTitlePress(_ sender: NSMenuItem) {
        UserSettings.AutoHideTitle.value = (sender.state == .off)
		
		let notif = Notification(name: .autoHideTitleBar, object: sender)
		NotificationCenter.default.post(notif)
     }

	//	Cookies...
	@IBAction func acceptCookiePress(_ sender: NSMenuItem) {
		UserSettings.AcceptWebCookie.value = (sender.state == .off)
	}
	@IBAction func clearCookliesPress(_ sender: Any) {
		sheetOKCancel("Confirm clearing *all* cookies",
					  info: "This cannot be undone!",
					  acceptHandler:
			{ (button) in
				//  Make them confirm first, then clear lazily
				if button == NSApplication.ModalResponse.alertFirstButtonReturn {
					HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)
				}
			}
		)
	}
	@IBAction func shareCookiesPress(_ sender: NSMenuItem) {
		UserSettings.ShareWebCookies.value = (sender.state == .off)
	}
	@IBAction func storeCookiesPress(_ sender: NSMenuItem) {
		UserSettings.StoreWebCookies.value = (sender.state == .off)
	}
	
	//  By default we auto save any document changes
    @objc @IBOutlet weak var autoSaveDocsMenuItem: NSMenuItem!
    @objc @IBAction func autoSaveDocsPress(_ sender: NSMenuItem) {
        autoSaveDocs = (sender.state == .off)
	}
	var autoSaveDocs : Bool {
        get {
            return UserSettings.AutoSaveDocs.value
        }
        set (value) {
			autoSaveDocumentsSetup(value)

            UserSettings.AutoSaveDocs.value = value
        }
    }
    var autoSaveTimer : Timer?

	func autoSaveDocumentsSetup(_ state: Bool) {
		switch state {
		case false:
			if let timer = autoSaveTimer, timer.isValid {
				DispatchQueue.main.async {
					self.docController.saveAllDocuments(self.autoSaveDocsMenuItem)
				}
				timer.invalidate()
				autoSaveTimer = nil
			}
			
		case true:
			//	Save immediately, manually save at origin
			guard nil == autoSaveTimer else { return }
			for doc in docController.documents {
				DispatchQueue.main.async {
					doc.save(self.autoSaveDocsMenuItem)
				}
			}

			//  Startup our autosaving block; keeps SaveAs options too!
			let secs = UserSettings.AutoSaveTime.value
			self.autoSaveTimer = Timer.scheduledTimer(withTimeInterval: secs, repeats: true, block: { (timer) in
				if timer.isValid, UserSettings.AutoSaveDocs.value {
					for document in self.docController.documents {
						if document.isDocumentEdited {
							DispatchQueue.main.async {
								document.autosave(withImplicitCancellability: false, completionHandler: {(error) in
									document.updateChangeCount(.changeCleared)
								})
							}
						}
					}
				}
			})
			if let timer = self.autoSaveTimer { RunLoop.current.add(timer, forMode: .common) }
		}
	}
	
	@IBAction func clearHistoryPress(_ sender: Any) {
        
        let message = "Confirm clearing URL and search history"
        let infoMsg = String(format: "%ld history(s), %ld search(es)", _histories?.count ?? 0,
                             recentSearches.count)
        
        sheetOKCancel(message, info: infoMsg,
                                acceptHandler: { (button) in

                                    //  Make them confirm first, then clear lazily
                                    if button == NSApplication.ModalResponse.alertFirstButtonReturn {
                                        self._histories = [PlayItem]()
                                        let forget = Array<Any>()
                                        self.defaults.set(forget, forKey: UserSettings.HistoryList.keyPath)
                                        let forgot = Array<PlayItem>()
                                        self.defaults.set(forgot, forKey: UserSettings.SearchNames.keyPath)
                                    }
        })
	}
	
	@IBAction func keepHistoryPress(_ sender: NSMenuItem) {
        UserSettings.HistorySaves.value = (sender.state == .off)
	}
	
	@objc @IBAction func developerExtrasEnabledPress(_ sender: NSMenuItem) {
        UserSettings.DeveloperExtrasEnabled.value = (sender.state == .off)
    }
    
    var fullScreen : NSRect? = nil
    @objc @IBAction func toggleFullScreen(_ sender: NSMenuItem) {
        if let keyWindow : Panel = NSApp.keyWindow as? Panel {
            keyWindow.heliumPanelController.floatOverSpacesPress(sender)
        }
    }

    @objc @IBAction func magicURLRedirectPress(_ sender: NSMenuItem) {
        UserSettings.DisabledMagicURLs.value = (sender.state == .on)
    }
    
	func doOpenFile(fileURL: URL, fromWindow: NSWindow? = nil) -> Bool {
        if isSandboxed != storeBookmark(url: fileURL) {
            print("Yoink, unable to sandbox \(fileURL)")
            return false
        }
        
        if let thisWindow = fromWindow != nil ? fromWindow : NSApp.keyWindow {
            guard openForBusiness || (thisWindow.contentViewController?.isKind(of: PlaylistViewController.self))! else {
                if let wvc = thisWindow.contentViewController as? WebViewController {
                    return wvc.webView.next(url: fileURL)
                }
                else
                {
                    return false
                }
            }
        }
        
        //  This could be anything so add/if a doc and initialize
        do {
			var typeName : String = k.Helium
			if fileURL.isFileURL {
				typeName = try docController.typeForContents(of: fileURL)
			}
            let doc = try docController.makeDocument(withContentsOf: fileURL, ofType: typeName)
            docController.noteNewRecentDocumentURL(fileURL)
			doc.showWindows()
            return true
        } catch let error {
            print("*** Error open file: \(error.localizedDescription)")
            return false
        }
    }
    
	@objc @IBOutlet var launchWindow: NSWindow?
	@IBAction func launchAutoLoginPress(_ sender: NSMenuItem) {
		guard nil == launchWindow else { launchWindow?.makeKeyAndOrderFront(sender); return }
        let storyboard = NSStoryboard(name: "Main", bundle: nil)

		let autoLogin = storyboard.instantiateController(withIdentifier: "AutoLaunchController") as! LaunchController
		if let window = autoLogin.window {
			launchWindow = window
			window.makeKeyAndOrderFront(sender)
		}
	}
	
	@objc @IBAction func locationServicesPress(_ sender: Any) {
        if isLocationEnabled {
            locationManager?.stopMonitoringSignificantLocationChanges()
            locationManager?.stopUpdatingLocation()
            locationManager = nil
        }
        else
        {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.startUpdatingLocation()
        }
		
		let notif = Notification(name: .locationServiceChange, object: self.locationStatus)
		NotificationCenter.default.post(notif)
    }
    
	@objc @IBAction func openFilePress(_ sender: AnyObject) {
        var viewOptions = ViewOptions(rawValue: sender.tag)
        
        let open = NSOpenPanel()
        open.allowsMultipleSelection = true
        open.canChooseDirectories = false
        open.resolvesAliases = true
        open.canChooseFiles = true
        
        //  No window, so load panel modally
        NSApp.activate(ignoringOtherApps: true)
        
        if open.runModal() == .OK {
            open.orderOut(sender)
            let urls = open.urls
            for url in urls {
                if viewOptions.contains(.t_view) {
                    _ = openFileInNewWindow(url, context: sender.representedObject as? NSWindow)
                }
                else
                if viewOptions.contains(.w_view) {
                    _ = openFileInNewWindow(url)
                }
                else
                {
                    _ = self.doOpenFile(fileURL: url)
                }
            }
            //  Multiple files implies new windows
            viewOptions.insert(.w_view)
        }
        return
    }
    
    internal func openFileInNewWindow(_ url: URL, context parentWindow: NSWindow? = nil) -> Bool {
        os_signpost(.begin, log: MyWebView.poi, name: "openFileInNewWindow")
        defer { os_signpost(.end, log: AppDelegate.poi, name: "openURLInNewWindow") }

        if url.isFileURL, isSandboxed != storeBookmark(url: url) {
            print("Yoink, unable to sandbox \(url)")
            return false
        }
        
        return openURLInNewWindow(url, context: parentWindow)
    }
    
	func preflight(_ url: URL) -> Bool {
		if url.isFileURL {
			
			guard fileManager.fileExists(atPath: url.path) else {
				self.userAlertMessage("File not found.",
									  info: url.absoluteString.removingPercentEncoding)
				return false
			}
		
			guard isSandboxed == storeBookmark(url: url) else { return false }
		}
		
		return [k.file,k.http,k.https,k.scheme,k.local].contains(url.scheme)
	}
	
    func openURLInNewWindow(_ url: URL, context otherWindow : NSWindow? = nil) -> Bool {
        os_signpost(.begin, log: MyWebView.poi, name: "openURLInNewWindow")
        defer { os_signpost(.end, log: AppDelegate.poi, name: "openURLInNewWindow") }

		guard preflight(url) else { return false }
		
        do {
			let fileType = try docController.typeForContents(of: url)
            let doc = try docController.makeDocument(withContentsOf: url, ofType: fileType)
            if doc.windowControllers.count == 0 { doc.makeWindowControllers() }
            guard let wc = doc.windowControllers.first else { return false }
            
            if let window = wc.window, let other = otherWindow {
                other.addTabbedWindow(window, ordered: .above)
            }
			doc.showWindows()
            return true
            
        } catch let error {
            NSApp.presentError(error)
        }
        return false
    }
        
    @objc @IBAction func openVideoInNewWindowPress(_ sender: NSMenuItem) {
        if let newURL = sender.representedObject {
            _ = self.openURLInNewWindow(newURL as! URL, context: sender.representedObject as? NSWindow)
        }
    }
    
    @objc @IBAction func openLocationPress(_ sender: AnyObject) {
        let window = (sender as? NSMenuItem)?.representedObject
        let viewOptions = ViewOptions(rawValue: sender.tag)
        var urlString = UserSettings.HomePageURL.value
        
        //  No window, so load alert modally
        if let rawString = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string), rawString.isValidURL() {
            urlString = rawString
        }
        didRequestUserUrl(RequestUserStrings (
            currentURLString:   urlString,
            alertMessageText:   "URL to load",
            alertButton1stText: "Load",     alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Home",     alertButton3rdInfo: UserSettings.HomePageURL.value),
                          onWindow: window as? Panel,
                          title: "Enter URL",
                          acceptHandler: { (urlString: String) in
                            guard let newURL = URL.init(string: urlString) else { return }
                            
                            if viewOptions.contains(.t_view), let parent = sender.representedObject {
                                _ = self.openURLInNewWindow(newURL, context: parent as? NSWindow)
                            }
                            else
                            {
                                _ = self.openURLInNewWindow(newURL)
                            }
        })
    }

    @objc @IBAction func openSearchPress(_ sender: AnyObject) {
        let name = k.searchNames[ UserSettings.Search.value ]
        let info = k.searchInfos[ UserSettings.Search.value ]

        //  No window?, so load alert modally
            
        didRequestSearch(RequestUserStrings (
            currentURLString:   nil,
            alertMessageText:   "Search",
            alertButton1stText: name,         alertButton1stInfo: info,
            alertButton2ndText: "Cancel",     alertButton2ndInfo: nil,
            alertButton3rdText: nil,          alertButton3rdInfo: nil),
                         onWindow: nil,
                         title: "Web Search",
                         acceptHandler: { (newWindow,searchURL: URL) in
                            _ = self.openURLInNewWindow(searchURL, context: sender.representedObject as? NSWindow)
        })
    }
    
    @objc @IBAction func pickSearchPress(_ sender: NSMenuItem) {
        //  This needs to match validateMenuItem below
		let group = sender.tag / 100
		let index = (sender.tag - (group * 100)) % 3
		let key = String(format: "search%d", group)

		defaults.set(index as Any, forKey: key)
//        print("\(key) -> \(index)")
	}
	
	@objc @IBOutlet var prefsWindow: NSWindow?
	@IBAction func prefsPanelPress(_ sender: NSMenuItem) {
		guard nil == prefsWindow else { prefsWindow?.makeKeyAndOrderFront(sender); return }
        let storyboard = NSStoryboard(name: "Main", bundle: nil)

		let prefsController = storyboard.instantiateController(withIdentifier: "PrefsPanelController") as! PrefsPanelController
		if let window = prefsController.window {
			prefsWindow = window
			window.makeKeyAndOrderFront(sender)
		}
	}
	
    @objc @IBAction func presentPlaylistSheet(_ sender: Any) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        //  If we have a window, present a sheet with playlists, otherwise ...
        guard let item: NSMenuItem = sender as? NSMenuItem, let window: NSWindow = item.representedObject as? NSWindow else {
            //  No contextual window, load panel and its playlist controller

            do {
				let doc = try docController.makeDocument(withContentsOf: k.PlaylistsURL, ofType: k.PlayType)
                if 0 == doc.windowControllers.count { doc.makeWindowControllers() }
				doc.showWindows()
            }
            catch let error {
                NSApp.presentError(error)
            }
            return
        }
        
        if let wvc = window.windowController?.contentViewController {

            //  We're already here so exit
            if wvc.isKind(of: PlaylistViewController.self) { return }
            
            //  If a web view controller, fetch and present playlist here
            if let wvc: WebViewController = wvc as? WebViewController {
                if wvc.presentedViewControllers?.count == 0 {
                    let pvc = storyboard.instantiateController(withIdentifier: "PlaylistViewController") as! PlaylistViewController
                    pvc.webViewController = wvc
                    wvc.presentAsSheet(pvc)
                }
                return
            }
            print("who are we? \(String(describing: window.contentViewController))")
        }
    }
	
    @objc @IBAction func promoteHTTPSPress(_ sender: NSMenuItem) {
        UserSettings.PromoteHTTPS.value = (sender.state == .on ? false : true)
	}
    
    @objc @IBAction func restoreDocAttrsPress(_ sender: NSMenuItem) {
        UserSettings.RestoreDocAttrs.value = (sender.state == .on ? false : true)
	}
	
    @objc @IBAction func restoreWebURLsPress(_ sender: NSMenuItem) {
        UserSettings.RestoreWebURLs.value = (sender.state == .on ? false : true)
    }
    
    @objc @IBAction func showReleaseInfo(_ sender: Any) {
        do
        {
			let doc = try docController.makeDocument(withContentsOf: k.ReleaseURL, ofType: k.ItemType)
			doc.showWindows()
        }
        catch let error {
            NSApp.presentError(error)
        }
	}
	
	func registerSnaphotsURL(_ sender: NSMenuItem, handler: @escaping (URL) -> Void) {
		var targetURL : URL

		//  1st around authenticate and cache sandbox data if needed
		if isSandboxed, desktopData == nil {
			targetURL =
				UserSettings.SnapshotsURL.value.count == 0
					? getDesktopDirectory()
					: URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value, isDirectory: true)
			
			let openPanel = NSOpenPanel()
			openPanel.message = "Authorize access to "
			openPanel.prompt = "Authorize"
			openPanel.canChooseFiles = false
			openPanel.canChooseDirectories = true
			openPanel.canCreateDirectories = true
			openPanel.directoryURL = targetURL
			openPanel.begin() { (result) -> Void in
				if (result == .OK) {
					targetURL = openPanel.url!
					
					//	Since we do not have data, clear any bookmark
					
					if self.storeBookmark(url: targetURL, options: self.rwOptions) {
						self.desktopData = self.bookmarks[targetURL]
						UserSettings.SnapshotsURL.value = targetURL.absoluteString
						if !self.saveBookmarks() {
							print("Yoink, unable to save snapshot bookmark")
						}

						self.desktopData = self.bookmarks[targetURL]
						handler(targetURL)
					}
				}
				else
				{
					return
				}
			}
		}
		else
		{
			targetURL =
				UserSettings.SnapshotsURL.value.count == 0
					? getDesktopDirectory()
					: URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value, isDirectory: true)
			handler(targetURL)
		}
	}
	
    @objc @IBAction func snapshotAllPress(_ sender: NSMenuItem) {
		registerSnaphotsURL(sender) { (snapshotURL) in
			//	If we have a return object just call them, else notify all
			if let wvc : WebViewController = sender.representedObject as? WebViewController {
				sender.representedObject = snapshotURL
				wvc.snapshot(sender)
			}
			else
			{
				sender.representedObject = snapshotURL
				let notif = Notification(name: .snapshotAll, object: sender)
				NotificationCenter.default.post(notif)
			}
		}
    }

	var canRedo : Bool {
        if let redo = NSApp.keyWindow?.undoManager  {
            return redo.canRedo
        }
        else
        {
            return false
        }
    }
    @objc @IBAction func redo(_ sender: Any) {
		if let window = NSApp.keyWindow, let undo = window.undoManager, undo.canRedo {
            print("redo:");
		}
	}
    
    var canUndo : Bool {
        if let undo = NSApp.keyWindow?.undoManager  {
            return undo.canUndo
        }
        else
        {
            return false
        }
    }

    @objc @IBAction func undo(_ sender: Any) {
        if let window = NSApp.keyWindow, let undo = window.undoManager, undo.canUndo {
            print("undo:");
        }
	}
    
    @objc @IBAction func userAgentPress(_ sender: AnyObject) {
        didRequestUserAgent(RequestUserStrings (
            currentURLString:   UserSettings.UserAgent.value,
            alertMessageText:   "Default user agent",
            alertButton1stText: "Set",      alertButton1stInfo: nil,
            alertButton2ndText: "Cancel",   alertButton2ndInfo: nil,
            alertButton3rdText: "Default",  alertButton3rdInfo: UserSettings.UserAgent.default),
                          onWindow: NSApp.keyWindow as? Panel,
                          title: "Default User Agent",
                          acceptHandler: { (newUserAgent: String) in
                            UserSettings.UserAgent.value = newUserAgent
        }
        )
    }
    
    func sheetOKCancel(_ message: String, info: String?,
                       acceptHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                acceptHandler(response)
            })
        }
        else
        {
            acceptHandler(alert.runModal())
        }
        alert.buttons.first!.becomeFirstResponder()
    }
    
    func userAlertMessage(_ message: String, info: String?) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        if info != nil {
            alert.informativeText = info!
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: { response in
                return
            })
        }
        else
        {
            alert.runModal()
            return
        }
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
        {
            switch menuItem.title {
            case k.bingName, k.googleName, k.yahooName:
                let group = menuItem.tag / 100
                let index = (menuItem.tag - (group * 100)) % 3
                
                menuItem.state = UserSettings.Search.value == index ? .on : .off
 
            case "Preferences":
                break
            case "Auto-hide Title Bar":
                menuItem.state = UserSettings.AutoHideTitle.value ? .on : .off
                break
            case "Auto save documents":
                menuItem.state = UserSettings.AutoSaveDocs.value ? .on : .off
			case "Accept":
				menuItem.state = UserSettings.AcceptWebCookie.value ? .on : .off
			case "Share":
				menuItem.state = UserSettings.ShareWebCookies.value ? .on : .off
			case "Store":
				menuItem.state = UserSettings.StoreWebCookies.value ? .on : .off
			case "WebView Inspector":
				menuItem.state = UserSettings.DeveloperExtrasEnabled.value ? .on : .off
            case "Hide He3 in menu bar":
                menuItem.state = UserSettings.HideAppMenu.value ? .on : .off
            case "Keep history record":
                menuItem.state = UserSettings.HistorySaves.value ? .on : .off
            case "Home Page":
                break
			case "Audio":
				guard menuItem.menu?.title == "Entitlements…" else { return true }
				menuItem.isEnabled = ![.restricted,.denied].contains(avStatus(for: .audio))
				menuItem.state = [.authorized].contains(avStatus(for: .audio)) ? .on : .off
			case "Video":
				guard menuItem.menu?.title == "Entitlements…" else { return true }
				menuItem.isEnabled = ![.restricted,.denied].contains(avStatus(for: .video))
				menuItem.state = [.authorized].contains(avStatus(for: .video)) ? .on : .off
            case "Location":
				guard menuItem.menu?.title == "Entitlements…" else { return true }
				menuItem.isEnabled = ![.restricted,.denied].contains(locationStatus)
                menuItem.state = isLocationEnabled ? .on : .off
			case "Auto Launch At Login":
				menuItem.state = UserSettings.LoginAutoStartAtLaunch.value ? .on : .off
            case "Magic URL Redirects":
                menuItem.state = UserSettings.DisabledMagicURLs.value ? .off : .on
            case "Upgrade HTTP -> HTTPS Links":
                menuItem.state = UserSettings.PromoteHTTPS.value ? .on : .off
            case "Restore Doc Attributes":
                menuItem.state = UserSettings.RestoreDocAttrs.value ? .on : .off
            case "Restore Web URLs":
                menuItem.state = UserSettings.RestoreWebURLs.value ? .on : .off
            case "User Agent":
                break
 			case "Assets":
 				menuItem.state = UserSettings.UseLocalAssets.value ? .on : .off
            case "Quit":
                break

            default:
                break
            }
        }
        return true;
    }

    //  MARK:- Lifecyle
    @objc dynamic var documentsToRestore = false
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        //  Now we're open for business
        self.openForBusiness = true

        //  If we will restore then skip initial Untitled
        return !documentsToRestore && !disableDocumentReOpening
    }
    
    func resetDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        //  Wipe alll cookies and cache
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)

        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler:{ })
        
        //  Clear any snapshots etc URL sandbox resources
		print(eraseBookmarks() ? "All bookmark(s) were cleared" : "Yoink erasing bookmarks")
    }
    
    let toHMS = hmsTransformer()
    let rectToString = rectTransformer()
    var launchedAsLogInItem : Bool = false
    
    var desktopData: Data?
    let rwOptions:URL.BookmarkCreationOptions = [.withSecurityScope]

    func applicationWillFinishLaunching(_ notification: Notification) {
        //  We need our own to reopen our "document" urls
        _ = DocumentController.init()
        
		//	Prime our histories
		_ = histories
		
        let flags : NSEvent.ModifierFlags = NSEvent.ModifierFlags(rawValue: NSEvent.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue)
        let event = NSAppleEventDescriptor.currentProcess()

        //  We want automatic tab support
        NSPanel.allowsAutomaticWindowTabbing = true
        
        //  Wipe out defaults when OPTION+SHIFT is held down at startup
        if flags.contains([NSEvent.ModifierFlags.shift,NSEvent.ModifierFlags.option]) {
            print("shift+option at start")
            resetDefaults()
			NSSound.playIf(.purr)
        }
        else
        //  Don't reopen docs when OPTION is held down at startup
        if flags.contains(NSEvent.ModifierFlags.option) {
            print("option at start")
            disableDocumentReOpening = true
        }
        
        //  We were started as a login item startup save this
        launchedAsLogInItem = event.eventID == kAEOpenApplication &&
            event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(AppDelegate.handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

		//	Monitor to affect system sound volume
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(AppDelegate.quickQuiet(_:)),
			name: .quickQuiet,
			object: nil)

        //  So they can interact everywhere with us without focus
        appStatusItem.button?.image = NSImage.init(named: "statusIcon")
        appStatusItem.menu = appMenu

        //  Initialize our h:m:s transformer
        ValueTransformer.setValueTransformer(toHMS, forName: NSValueTransformerName(rawValue: "hmsTransformer"))
        
        //  Initialize our rect [point,size] transformer
        ValueTransformer.setValueTransformer(rectToString, forName: NSValueTransformerName(rawValue: "rectTransformer"))

        //  Maintain a history of titles
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(AppDelegate.haveNewTitle(_:)),
			name: .newTitle,
            object: nil)

        //  Load sandbox bookmark url when necessary
        if self.isSandboxed {
            if !self.loadBookmarks() {
                print("Yoink, unable to load bookmarks")
            }
            else
			if UserSettings.SnapshotsURL.value.count > 0
            {
                //  Try and restore snapshots/webarchive url data
				let url = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value, isDirectory: true)
				if let data = bookmarks[url], fetchBookmark((key: url, value: data)) {
					print ("snapshotURL \(url.absoluteString)")
					desktopData = data
				}
				else
				if let url = URL.init(string: String(format: "file:///Users/%@/Desktop/", NSUserName())), let data = bookmarks[url] {
					UserSettings.SnapshotsURL.value = url.absoluteString
					desktopData = data
				}
            }
        }
        
        //  For site that require location services
        if UserSettings.RestoreLocationSvcs.value {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
        }
    }

    var itemActions = Dictionary<String, Any>()

    //  Keep playlist names unique by Array entension checking name
    @objc dynamic var _playlists : [PlayList]?
    @objc dynamic var  playlists : [PlayList] {
        get {
            if  _playlists == nil {
                _playlists = restorePlaylists()
            }
            return _playlists!
        }
        set (array) {
            _playlists = array
        }
    }
    
	func restorePlaylists(_  keyPath: String = k.playlists) -> [PlayList] {
		assert(k.PlaylistsURL.deletingPathExtension().lastPathComponent == k.playlists, "k.playlists not in URL")
        var playlists = [PlayList]()
            
        //  read back playlists as [Dictionary] or [String] keys to each [PlayItem]
        if let plists = self.defaults.dictionary(forKey: keyPath) {
            for (name,plist) in plists {
                guard let items = plist as? [Dictionary<String,Any>] else {
                    let playlist = PlayList(name: name, list: [PlayItem]())
                    playlists.append(playlist)
                    continue
                }
                var list : [PlayItem] = [PlayItem]()
                for plist in items {
                    let item = PlayItem(from: plist)
                    list.append(item)
                }
                let playlist = PlayList(name: name, list: list)
                playlists.append(playlist)
            }
        }
        else
        if let dicts = self.defaults.array(forKey: keyPath) as? [Dictionary<String,Any>] {
            for dict in dicts {
				let playlist = PlayList(with: dict)
                playlists.append(playlist)
            }
        }
		else
        if let plists = self.defaults.array(forKey: keyPath) as? [String] {
            for name in plists {
                guard let plist = self.defaults.dictionary(forKey: name) else {
					var list = [PlayItem]()
					if let items = self.defaults.array(forKey: name) {
						for item in items {
							let playitem = PlayItem(from: (item as? Dictionary<String, Any>)!)
							list.append(playitem)
						}
					}
                    let playlist = PlayList(name: name, list: list)
                    playlists.append(playlist)
                    continue
                }
                let playlist = PlayList(with: plist)
                playlists.append(playlist)
            }
        }
        else
        {
            self.defaults.set([Dictionary<String,Any>](), forKey: keyPath)
        }
        return playlists
    }
    
    @objc @IBAction func savePlaylists(_ sender: Any) {
		assert(k.PlaylistsURL.deletingPathExtension().lastPathComponent == k.playlists, "k.playlists not in URL")
		playlists.saveToDefaults(k.playlists)
	}
	
    //  Histories restore deferred until requested
    @objc dynamic var _histories : [PlayItem]?
    @objc dynamic var  histories : [PlayItem] {
        get {
            if  _histories == nil {
                _histories = [PlayItem]()
                
                // Restore history name change
                if let historyName = self.defaults.string(forKey: UserSettings.HistoryName.keyPath), historyName != UserSettings.HistoryName.value {
                    UserSettings.HistoryName.value = historyName
                }
                
                if let items = self.defaults.array(forKey: UserSettings.HistoryList.keyPath) {
                    let keep = UserSettings.HistoryKeep.value
                    
                    // Load histories from defaults up to their maximum
                    for item in items.suffix(keep) {
						var playitem: PlayItem?
						
                        if let name : String = item as? String, let dict = defaults.dictionary(forKey: name) {
                            playitem = PlayItem(from: dict)
                        }
                        else
                        if let dict : Dictionary <String,AnyObject> = item as? Dictionary <String,AnyObject> {
                            playitem = PlayItem(from: dict)
                        }
						
						if let playitem = playitem
						{
							if let dict = defaults.dictionary(forKey: playitem.link.absoluteString) {
								playitem.update(with: dict)
							}
							self._histories?.append(playitem)
						}
                        else
                        {
                            print("unknown history \(item)")
                        }
                    }
                    print("\(self._histories!.count) history(s) restored")
                }
            }
            return _histories!
        }
        set (array) {
            _histories = array
        }
    }
	
	var _historyCache : PlayList?
	var  historyCache : PlayList {
		if  _historyCache == nil {
			_historyCache = PlayList(name: UserSettings.HistoryName.value,
									 list: histories)
		}
		return _historyCache!
	}
	
    var defaults = UserDefaults.standard
    var hiddenWindows = Dictionary<String, Any>()

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let docCount = docController.documents.count
        return docCount > 0
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let reopenMessage = disableDocumentReOpening ? "do not reopen doc(s)" : "reopen doc(s)"
        let hasVisibleDocs = flag ? "has doc(s)" : "no doc(s)"
        print("applicationShouldHandleReopen: \(reopenMessage) docs:\(hasVisibleDocs)")
		if !flag && nil == NSApp.keyWindow { return !applicationOpenUntitledFile(sender) }
        return !disableDocumentReOpening || flag
    }

    //  Local/global event monitor: CTRL+OPTION+COMMAND to toggle windows' alpha / audio values
    //  https://stackoverflow.com/questions/41927843/global-modifier-key-press-detection-in-swift/41929189#41929189
    var localKeyDownMonitor : Any? = nil
    var globalKeyDownMonitor : Any? = nil
    var shiftKeyDown : Bool = false {
        didSet {
			let notif = Notification(name: .shiftKeyDown,
									 object: NSNumber(booleanLiteral: shiftKeyDown));
            NotificationCenter.default.post(notif)
        }
    }
    var optionKeyDown : Bool = false {
        didSet {
			let notif = Notification(name: .optionKeyDown,
                                     object: NSNumber(booleanLiteral: optionKeyDown));
            NotificationCenter.default.post(notif)
        }
    }
    var commandKeyDown : Bool = false {
        didSet {
			let notif = Notification(name: .commandKeyDown,
                                     object: NSNumber(booleanLiteral: commandKeyDown))
            NotificationCenter.default.post(notif)
        }
    }

    func keyDownMonitor(event: NSEvent) -> Bool {
        switch event.modifierFlags.intersection(NSEvent.ModifierFlags.deviceIndependentFlagsMask) {
        case [NSEvent.ModifierFlags.control, NSEvent.ModifierFlags.option, NSEvent.ModifierFlags.command]:
			self.inQuickQuietMode = inQuickQuietMode ? false : true
			let notif = Notification(name: .quickQuiet, object: nil)
            NotificationCenter.default.post(notif)
			print("inQuickQuietMode = \(inQuickQuietMode ? "YES" : "NO")")
/*
            print("control-option-command keys are pressed")
            if self.hiddenWindows.count > 0 {
//                print("show all windows")
                for frame in self.hiddenWindows.keys {
                    let dict = self.hiddenWindows[frame] as! Dictionary<String,Any>
                    let alpha = dict["alpha"]
                    let win = dict["window"] as! NSWindow
//                    print("show \(frame) to \(String(describing: alpha))")
                    win.alphaValue = alpha as! CGFloat
                    if let path = dict["name"], let actions = itemActions[path as! String]
                    {
                        if let action = (actions as! Dictionary<String,Any>)["mute"] {
                            let item = (action as! Dictionary<String,Any>)["item"] as! NSMenuItem
                            print("action \(item)")
                        }
                        if let action = (actions as! Dictionary<String,Any>)["play"] {
                            let item = (action as! Dictionary<String,Any>)["item"] as! NSMenuItem
                            print("action \(item)")
                        }
                    }
                }
                self.hiddenWindows = Dictionary<String,Any>()
            }
            else
            {
//                print("hide all windows")
                for win in NSApp.windows {
                    let frame = NSStringFromRect(win.frame)
                    let alpha = win.alphaValue
                    var dict = Dictionary <String,Any>()
                    dict["alpha"] = alpha
                    dict["window"] = win
                    if let wvc = win.contentView?.subviews.first as? MyWebView, let url = wvc.url {
                        dict["name"] = url.absoluteString
                    }
                    self.hiddenWindows[frame] = dict
//                    print("hide \(frame) to \(String(describing: alpha))")
                    win.alphaValue = 0.01
                }
            }
*/
            return true
            
        case [NSEvent.ModifierFlags.option, NSEvent.ModifierFlags.command]:
			let notif = Notification(name: .optionAndCommandKeysDown,
                                     object: NSNumber(booleanLiteral: commandKeyDown))
            NotificationCenter.default.post(notif)
            return true
            
        case [NSEvent.ModifierFlags.shift]:
            self.shiftKeyDown = true
            return true
            
        case [NSEvent.ModifierFlags.option]:
            self.optionKeyDown = true
            return true
            
        case [NSEvent.ModifierFlags.command]:
            self.commandKeyDown = true
            return true
            
        default:
            //  Only clear when true
            if shiftKeyDown { self.shiftKeyDown = false }
            if optionKeyDown { self.optionKeyDown = false }
            if commandKeyDown { self.commandKeyDown = false }
            return false
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		//	Run down our launch if still around
        let launcherAppId = "com.slashlos.he3.Launcher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        SMLoginItemSetEnabled(launcherAppId as CFString, true)

        if isRunning {
            DistributedNotificationCenter.default().post(name: .killLauncher, object: Bundle.main.bundleIdentifier!)
        }

        // Local/Global Monitor
        _ /*accessEnabled*/ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { (event) -> Void in
            _ = self.keyDownMonitor(event: event)
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { (event) -> NSEvent? in
            return self.keyDownMonitor(event: event) ? nil : event
        }
        
        //  Synchronize our app menu visibility
        self.syncAppMenuVisibility()
        
        /* NYI  //  Register our URL protocol(s)
        URLProtocol.registerClass(He3URLProtocol.self) */
        
        //  If started via login item, launch the login items playlist
        if launchedAsLogInItem {
            print("We were launched as a startup item")
        }
        
        //  Developer extras off by default
        UserSettings.DeveloperExtrasEnabled.value = false
        
        //  Restore auto save settings
		self.autoSaveDocs = UserSettings.AutoSaveDocs.value

        //  Restore our web (non file://) document windows if any via
        guard !disableDocumentReOpening else { return }
        if let keep = defaults.array(forKey: UserSettings.KeepListName.value) {
            for item in keep {
                guard let urlString = (item as? String) else { continue }
                if urlString == UserSettings.HomePageURL.value { continue }
                guard let url = URL.init(string: urlString ) else { continue }
                _ = self.openURLInNewWindow(url)
                print("restore \(item)")
            }
        }
        
		//	Handle Cocoa Auto Layout mechanism exception - not automatically
		UserDefaults.standard.set(false, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
    }
	
    func applicationWillTerminate(_ aNotification: Notification) {
        
		//	Do one last autosave
		self.autoSaveDocs = false
		
        //  Forget key down monitoring
        NSEvent.removeMonitor(localKeyDownMonitor!)
        NSEvent.removeMonitor(globalKeyDownMonitor!)
        
        //  Forget location services
        if !UserSettings.RestoreLocationSvcs.value && isLocationEnabled {
            locationManager?.stopMonitoringSignificantLocationChanges()
            locationManager?.stopUpdatingLocation()
            locationManager = nil
        }
        
        //  Cease and Save sandbox bookmark urls when necessary
		if isSandboxed != ceaseBookmarks() {
			print("Yoink, unable to cease booksmarks")
		}
        if isSandboxed != saveBookmarks() {
            print("Yoink, unable to save booksmarks")
        }

        // Save play;sits to defaults - no maximum
        savePlaylists(self)
        
        // Save histories to defaults up to their maximum
		assert(k.histories == UserSettings.HistoryList.value, "k.histories not HistoryList")
        let keep = UserSettings.HistoryKeep.value
        var temp = Array<Any>()
        for item in histories.sorted(by: { (lhs, rhs) -> Bool in return lhs.rank < rhs.rank}).suffix(keep) {
            temp.append(item.dictionary())
        }
        defaults.set(temp, forKey: UserSettings.HistoryList.keyPath)

        //  Save searches to defaults up to their maximum
        temp = Array<Any>()
		for item in webSearches.suffix(UserSettings.SearchKeep.value) {
            temp.append(item.dictionary())
        }
        defaults.set(temp, forKey: UserSettings.SearchNames.keyPath)
        
        //  Save our web URLs (non file://) windows to our keep list
        if UserSettings.RestoreWebURLs.value {
            temp = Array<String>()
            for document in NSApp.orderedDocuments {
                guard let webURL = document.fileURL, !webURL.isFileURL else {
                    print("skip \(String(describing: document.fileURL?.absoluteString))")
                    continue
                }
                print("keep \(String(describing: document.fileURL?.absoluteString))")
				
				//	take a final reading on window and save
				if let url = document.fileURL, let window = document.windowControllers.first?.window {
					let doc = document as! Document
					doc.settings.rect.value = window.frame
					doc.cacheSettings(url)
				}
                temp.append(webURL.absoluteString)
            }
            defaults.set(temp, forKey: UserSettings.KeepListName.value)
        }
        
        defaults.synchronize()
        
        //  Run-down autosaving
        if let timer = autoSaveTimer { timer.invalidate() }
    }

    func applicationDockMenu(sender: NSApplication) -> NSMenu? {
        let menu = NSMenu(title: AppName)
        var item: NSMenuItem

        item = NSMenuItem(title: "Open", action: #selector(menuClicked(_:)), keyEquivalent: "")
        menu.addItem(item)
        let subOpen = NSMenu()
        item.submenu = subOpen
        
        item = NSMenuItem(title: "File…", action: #selector(AppDelegate.openFilePress(_:)), keyEquivalent: "")
        item.target = self
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "URL…", action: #selector(AppDelegate.openLocationPress(_:)), keyEquivalent: "")
        item.target = self
        subOpen.addItem(item)
        
        item = NSMenuItem(title: "Window", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "")
        item.isAlternate = true
        item.target = docController
        subOpen.addItem(item)

        item = NSMenuItem(title: "Tab", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "")
        item.keyEquivalentModifierMask = NSEvent.ModifierFlags.shift
        item.isAlternate = true
        item.target = self
        item.tag = 3
        subOpen.addItem(item)
        return menu
    }
    
    //MARK: - handleURLEvent(s)

    func metadataDictionaryForFileAt(_ fileName: String) -> Dictionary<NSObject,AnyObject>? {
        
        guard let item = MDItemCreate(kCFAllocatorDefault, fileName as CFString) else { return nil }
        
        guard let list = MDItemCopyAttributeNames(item) else { return nil }
        
        let resDict = MDItemCopyAttributes(item,list) as Dictionary
        return resDict
    }

    @objc fileprivate func haveNewTitle(_ notification: Notification) {
        guard UserSettings.HistorySaves.value else { return }
		guard let webView : MyWebView = notification.object as? MyWebView, !webView.incognito else { return }
		guard let info = notification.userInfo else { return }
		let item = webView.playitem
		let link = item.link
		
		guard link != webView.homeURL else { return }
		let fini = (info[k.fini] as AnyObject).boolValue == true
 
        //  If the title is already seen, update global and playlists
		if nil != defaults.dictionary(forKey: item.link.absoluteString) {
			//  publish tally across playlists
			for play in playlists {
				guard let seen = play.list.link(item.link.absoluteString) else { continue }
				seen.plays += fini ? 0 : 1
			}
        }

        //  if not finished bump plays for this item
        if fini {
            //  move to next item in playlist
            print("move to next item in playlist")
        }
        else
        {
			item.rank = histories.count + 1
			histories.append(item)
        }
        
        //  always synchronize this item to defaults - lazily
        defaults.set(item.dictionary(), forKey: item.link.absoluteString)
        
        //  tell any playlist controller we have updated history
		let notif = Notification(name: .playitem, object: item,
								 userInfo: [k.list : historyCache])
        NotificationCenter.default.post(notif)
    }
    
    /// Shows alert asking user to input user agent string
    /// Process response locally, validate, dispatch via supplied handler
    func didRequestUserAgent(_ strings: RequestUserStrings,
                             onWindow: Panel?,
                             title: String?,
                             acceptHandler: @escaping (String) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.icon = NSImage.init(named: k.AppName)
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = strings.alertMessageText
        
        // Create uaField
        let uaField = URLField(withValue: strings.currentURLString, modalTitle: title)
        uaField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        if let hpc = onWindow?.windowController as? HeliumController {
            uaField.borderColor = hpc.homeColor
        }
        
        // Add urlField and buttons to alert
        alert.accessoryView = uaField
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }

        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let urlWindow = onWindow {
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are accept, cancel, default
                if response == NSApplication.ModalResponse.alertThirdButtonReturn {
                    let newUA = (alert.accessoryView as! NSTextField).stringValue
                    if UAHelpers.isValidUA(uaString: newUA) {
                        acceptHandler(newUA)
                    }
                    else
                    {
                        self.userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                    }
                }
                else
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // swiftlint:disable:next force_cast
                    let newUA = (alert.accessoryView as! NSTextField).stringValue
                    if UAHelpers.isValidUA(uaString: newUA) {
                        acceptHandler(newUA)
                    }
                    else
                    {
                        self.userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                    }
                }
            })
        }
        else
        {
            switch alert.runModal() {
            case NSApplication.ModalResponse.alertThirdButtonReturn:
                let newUA = (alert.accessoryView as! NSTextField).stringValue
                if UAHelpers.isValidUA(uaString: newUA) {
                    acceptHandler(newUA)
                }
                else
                {
                    userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                }
                 
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                let newUA = (alert.accessoryView as! NSTextField).stringValue
                if UAHelpers.isValidUA(uaString: newUA) {
                    acceptHandler(newUA)
                }
                else
                {
                    userAlertMessage("This apppears to be an invalid User Agent", info: newUA)
                }

            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on uaField
        alert.accessoryView!.becomeFirstResponder()
    }
    
    func didRequestSearch(_ strings: RequestUserStrings,
                          onWindow: Panel?,
                          title: String?,
                          acceptHandler: @escaping (Bool,URL) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.icon = NSImage.init(named: k.AppName)
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = strings.alertMessageText
        
        // Create our search field with recent searches
        let search = SearchField(withValue: strings.currentURLString, modalTitle: title)
        search.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        if let hpc = onWindow?.windowController as? HeliumController {
            search.borderColor = hpc.homeColor
        }
        (search.cell as! NSSearchFieldCell).maximumRecents = 254
        search.recentSearches = recentSearches
        alert.accessoryView = search
        
        // Add urlField and buttons to alert
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let urlWindow = onWindow {
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are user-search-url, cancel, google-search
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn,NSApplication.ModalResponse.alertThirdButtonReturn:
                    let newUrlFormat = k.searchLinks[ UserSettings.Search.value ]
                    let rawString = (alert.accessoryView as! NSTextField).stringValue
                    let newUrlString = rawString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
                    var urlString = String(format: newUrlFormat, newUrlString!)
                    let newWindow = (response == NSApplication.ModalResponse.alertThirdButtonReturn)
                    
                    urlString = UrlHelpers.ensureScheme(urlString)
                    guard UrlHelpers.isValidURL(urlString: urlString), let searchURL = URL.init(string: urlString) else {
                        print("invalid: \(urlString)")
                        return
                    }

                    self.addWebSearcheURL(newUrlString!, searchURL: searchURL)
                    acceptHandler(newWindow,searchURL)
                    print("search \(rawString)")

                default:
                    return
                }
            })
        }
        else
        {
            let response = alert.runModal()
            switch response {
            case NSApplication.ModalResponse.alertFirstButtonReturn,NSApplication.ModalResponse.alertThirdButtonReturn:
                let newUrlFormat = k.searchLinks[ UserSettings.Search.value ]
                let rawString = (alert.accessoryView as! NSTextField).stringValue
                let newUrlString = rawString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
                var urlString = String(format: newUrlFormat, newUrlString!)
                let newWindow = (response == NSApplication.ModalResponse.alertThirdButtonReturn)

                urlString = UrlHelpers.ensureScheme(urlString)
                guard UrlHelpers.isValidURL(urlString: urlString), let searchURL = URL.init(string: urlString) else {
                    print("invalid: \(urlString)")
                    return
                }
                
                self.addWebSearcheURL(newUrlString!, searchURL: searchURL)
                acceptHandler(newWindow,searchURL)
                print("search \(rawString)")

            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on searchField
        alert.accessoryView!.becomeFirstResponder()
    }

    func didRequestUserUrl(_ strings: RequestUserStrings,
                           onWindow: Panel?,
                           title: String?,
                           acceptHandler: @escaping (String) -> Void) {
        
        // Create alert
        let alert = NSAlert()
        alert.icon = NSImage.init(named: k.AppName)
        alert.alertStyle = NSAlert.Style.informational
        alert.messageText = strings.alertMessageText
        
        // Create urlField
        let urlField = URLField(withValue: strings.currentURLString, modalTitle: title)
        urlField.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        if let hpc = onWindow?.windowController as? HeliumController {
            urlField.borderColor = hpc.homeColor
        }
        alert.accessoryView = urlField

        // Add urlField and buttons to alert
        let alert1stButton = alert.addButton(withTitle: strings.alertButton1stText)
        if let alert1stToolTip = strings.alertButton1stInfo {
            alert1stButton.toolTip = alert1stToolTip
        }
        let alert2ndButton = alert.addButton(withTitle: strings.alertButton2ndText)
        if let alert2ndtToolTip = strings.alertButton2ndInfo {
            alert2ndButton.toolTip = alert2ndtToolTip
        }
        if let alert3rdText = strings.alertButton3rdText {
            let alert3rdButton = alert.addButton(withTitle: alert3rdText)
            if let alert3rdtToolTip = strings.alertButton3rdInfo {
                alert3rdButton.toolTip = alert3rdtToolTip
            }
        }
        
        //  Have window, but make it active
        NSApp.activate(ignoringOtherApps: true)
        
        if let urlWindow = onWindow {
            if let hpc = urlWindow.windowController as? HeliumController {
                urlField.borderColor = hpc.homeColor
            }
            alert.beginSheetModal(for: urlWindow, completionHandler: { response in
                // buttons are accept, cancel, default
                if response == NSApplication.ModalResponse.alertThirdButtonReturn {
                    var newUrl = (alert.buttons[2] as NSButton).toolTip
                    newUrl = UrlHelpers.ensureScheme(newUrl!)
                    if UrlHelpers.isValidURL(urlString: newUrl!) {
                        acceptHandler(newUrl!)
                    }
                }
                else
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    // swiftlint:disable:next force_cast
                    var newUrl = (alert.accessoryView as! NSTextField).stringValue
                    newUrl = UrlHelpers.ensureScheme(newUrl)
                    if UrlHelpers.isValidURL(urlString: newUrl) {
                        acceptHandler(newUrl)
                    }
                }
            })
        }
        else
        {
            //  No window, so load panel modally
            NSApp.activate(ignoringOtherApps: true)

            switch alert.runModal() {
            case NSApplication.ModalResponse.alertThirdButtonReturn:
                var newUrl = (alert.buttons[2] as NSButton).toolTip
                newUrl = UrlHelpers.ensureScheme(newUrl!)
                if UrlHelpers.isValidURL(urlString: newUrl!) {
                    acceptHandler(newUrl!)
                }
                
            case NSApplication.ModalResponse.alertFirstButtonReturn:
                var newUrl = (alert.accessoryView as! NSTextField).stringValue
                newUrl = UrlHelpers.ensureScheme(newUrl)
                if UrlHelpers.isValidURL(urlString: newUrl) {
                    acceptHandler(newUrl)
                }
                
            default:// NSAlertSecondButtonReturn:
                return
            }
        }
        
        // Set focus on urlField
        alert.accessoryView!.becomeFirstResponder()
    }
    
	// MARK:- Application Events
    // Called when the App opened via URL.
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
		guard let keyDirectObject = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)),
            let rawString = keyDirectObject.stringValue,
			let rawURL = URL.init(string: rawString) else {
                return print("No valid URL to handle")
        }

        //  try for a local file first
		let fileURL = URL.init(fileURLWithPath: rawURL.path)
		if FileManager.default.fileExists(atPath: fileURL.path) {
			if openFileInNewWindow(fileURL) {
				return
			}
		}
		
		let components = NSURLComponents.init(string: rawString)
		components?.scheme = UserSettings.PromoteHTTPS.value ? k.https : k.http

		if let url = components?.url {
			if openURLInNewWindow(url) {
				return
			}
		}
		
		userAlertMessage("Unable to handleURLEvent", info: rawString)
    }

    @objc func handleURLPboard(_ pboard: NSPasteboard, userData: NSString, error: NSErrorPointer) {
        if let selection = pboard.string(forType: NSPasteboard.PasteboardType.string) {

            // Notice: string will contain whole selection, not just the urls
            // So this may (and will) fail. It should instead find url in whole
            // Text somehow
			NotificationCenter.default.post(name: .loadURLString, object: selection)
        }
    }
    
    dynamic var disableDocumentReOpening = false

	func application(_ sender: NSApplication, willPresentError: Error) -> Error {
		//MARK: TODO catalog application errors
		Swift.print("Error: \(willPresentError.localizedDescription)")
		return willPresentError
	}
	
    func application(_ sender: NSApplication, openFile path: String) -> Bool {
        // Create a FileManager instance
		do {
			let files = try fileManager.contentsOfDirectory(atPath: path)
			for file in files {
				guard self.application(sender, openFile: file) else { return false }
			}
			return true
		} catch { }

		guard let url = URL(string: path.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!) else {
			print("Yoink encoding URL\(path)")
			return false
		}

		guard preflight(url) else { return false }
		
		return openFileInNewWindow(url)
	}
    
    func application(_ sender: NSApplication, openFiles paths: [String]) {
        for path in paths {
			_ = self.application(sender, openFile: path) ? 1 : 0
        }
    }
    
    func application(_ application: NSApplication, openURL url: URL) -> Bool {
        guard url.scheme == k.oauth2 else {
			return url.scheme == k.file ? openFileInNewWindow(url) : openURLInNewWindow(url)
        }
        
        //  Catch OAuth2 authentications
        let bits = url.pathComponents
        print("bits\n\(bits)")
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        
        for url in urls {
            if !self.application(application, openURL: url) {
                print("Yoink unable to open \(url)")
            }
        }
    }
    
    // MARK:- Sandbox Support
    var bookmarks = [URL: Data]()

    func authenticateBaseURL(_ url: URL) -> URL {
        guard isSandboxed, url.hasHTMLContent() else { return url }
        
        let openPanel = NSOpenPanel()
        var baseURL = url
        
        openPanel.message = "Authorize base access to " + baseURL.lastPathComponent
        openPanel.prompt = "Authorize"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.directoryURL = baseURL.deletingLastPathComponent()
        
        openPanel.begin() { (result) -> Void in
            if (result == .OK) {
                if let authURL = openPanel.url {
                    if self.storeBookmark(url: authURL) {
                        baseURL = authURL
                    }
                    else
                    {
                        print("Yoink, unable to sandbox base \(authURL)")
                    }
                }
            }
        }
        return baseURL
    }
    
    var _isSandboxed : Bool?
    var  isSandboxed : Bool {
        get {
            if _isSandboxed == nil {
                let bundleURL = Bundle.main.bundleURL
                var staticCode:SecStaticCode?
                var isSandboxed:Bool = false
                let kSecCSDefaultFlags:SecCSFlags = SecCSFlags(rawValue: SecCSFlags.RawValue(0))
                
                if SecStaticCodeCreateWithPath(bundleURL as CFURL, kSecCSDefaultFlags, &staticCode) == errSecSuccess {
                    if SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), nil, nil) == errSecSuccess {
                        let appSandbox = "entitlement[\"com.apple.security.app-sandbox\"] exists"
                        var sandboxRequirement:SecRequirement?
                        
                        if SecRequirementCreateWithString(appSandbox as CFString, kSecCSDefaultFlags, &sandboxRequirement) == errSecSuccess {
                            let codeCheckResult:OSStatus  = SecStaticCodeCheckValidityWithErrors(staticCode!, SecCSFlags(rawValue: kSecCSBasicValidateOnly), sandboxRequirement, nil)
                            if (codeCheckResult == errSecSuccess) {
                                isSandboxed = true
                            }
                        }
                    }
                }
                _isSandboxed = isSandboxed
            }
            return _isSandboxed!
        }
    }
    
    func bookmarkURL() -> URL?
    {
        if var documentsPathURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsPathURL = documentsPathURL.appendingPathComponent("Bookmarks.dict")
            return documentsPathURL
        }
        else
        {
            return nil
        }
    }
    
	func ceaseBookmarks() -> Bool
	{
		var iterator = bookmarks.makeIterator()
		let tally = bookmarks.count
		var ceased = 0

		while let bookmark = iterator.next()
		{
			bookmark.key.stopAccessingSecurityScopedResource()
			print ("© \(bookmark.key)")
			ceased += 1
		}
		return ceased == tally
	}
	
    func eraseBookmarks() -> Bool
    {
        //  Ignore loading unless configured
        guard isSandboxed else { return false }

        let fm = FileManager.default
        
		guard let url = bookmarkURL(), fm.fileExists(atPath: url.path) else {
            return saveBookmarks()
        }
        
		do {
			let data = try Data.init(contentsOf: url)
			bookmarks = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [URL : Data]
		} catch let error {
			print("unarchiveObject(withFile:) \(error.localizedDescription)")
		}

        var iterator = bookmarks.makeIterator()
		let tally = bookmarks.count
        var erased = 0

		//	Explicitly call out and clear our desktop access area and reset
		let desktop = URL.init(fileURLWithPath: UserSettings.SnapshotsURL.value)
		desktop.stopAccessingSecurityScopedResource()
		bookmarks[desktop] = nil
		UserSettings.SnapshotsURL.value = UserSettings.SnapshotsURL.default

        while let bookmark = iterator.next()
		{
			bookmark.key.stopAccessingSecurityScopedResource()
			bookmarks.removeValue(forKey: bookmark.key)
            print ("† \(bookmark.key)")
			erased += 1
        }
		
		do {
			try fm.removeItem(atPath: url.path)
		} catch let error {
			print(error.localizedDescription)
			print(url.path)
		}
		
        return erased == tally
    }
    
    func loadBookmarks() -> Bool
    {
        //  Ignore loading unless configured
        guard isSandboxed else { return false }

        let fm = FileManager.default
        
		guard let url = bookmarkURL(), fm.fileExists(atPath: url.path) else {
            return saveBookmarks()
        }
        
        var restored = 0
		do {
			let data = try Data.init(contentsOf: url)
			bookmarks = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [URL : Data]
		} catch let error {
			print("unarchiveObject(withFile:) \(error.localizedDescription)")
			return false
		}
				
		var iterator = bookmarks.makeIterator()

        while let bookmark = iterator.next()
        {
            //  stale bookmarks get dropped
            if !fetchBookmark(bookmark) {
                bookmarks.removeValue(forKey: bookmark.key)
            }
            else
            {
                restored += 1
            }
        }
        return restored == bookmarks.count
    }
    
    func saveBookmarks() -> Bool
    {
        //  Ignore saving unless configured
        guard isSandboxed, let url = bookmarkURL() else { return false }
		
		do {
			let data = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: true)
			try data.write(to: url)
			return true
		}
		catch let error {
			print("NSKeyedArchiver: \(error.localizedDescription)")
			return false
		}
    }
    
    func storeBookmark(url: URL, options: URL.BookmarkCreationOptions = [.withSecurityScope,.securityScopeAllowOnlyReadAccess]) -> Bool
    {
        guard isSandboxed else { return false }
        
        //  Peek to see if we've seen this key before
        if let data = bookmarks[url] {
            if self.fetchBookmark((key: url, value: data)) {
                print ("= \(url.absoluteString)")
                return true
            }
        }
        do
        {
			let data = url.isFinderAlias() ?? false
				? try NSURL.bookmarkData(withContentsOf: url)
				: try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[url] = data
            return self.fetchBookmark((key: url, value: data))
        }
        catch let error
        {
			//	If stale bookmark, clear and try again
			if nil != bookmarks[url] {
				_ = ceaseBookmark(url)
				bookmarks[url] = nil
				return storeBookmark(url: url, options: options)
			}
			
			//	Unless we have a window don't bother; allows to
			//	silently fail until its use is attempted later.
			if nil != NSApp.keyWindow {
				DispatchQueue.main.async {
					///NSApp.presentError(error)
					self.userAlertMessage(error.localizedDescription,
										  info: String(format: "Please update stale, missing bookmark:\n%@",
													   url.absoluteString.removingPercentEncoding!))
				}
			}
            print ("Error storing bookmark: \(url)")
            return false
        }
    }
    
    func reloadBookmark(_ url: URL) -> Bool {
        guard isSandboxed else { return false }

        if let data = bookmarks[url] {
            if self.fetchBookmark((key: url, value: data)) {
                return fetchBookmark( (key: url, value: data))
            }
        }
        return false
    }

	func ceaseBookmark(_ url: URL) -> Bool {
        guard isSandboxed else { return false }

		if nil != bookmarks[url] {
			url.stopAccessingSecurityScopedResource()
			return true
		}
		return false
	}
	
	func eraseBookmark(_ url: URL) -> Bool {
		guard isSandboxed else { return false }

		if ceaseBookmark(url) {
			bookmarks.removeValue(forKey: url)
			return true
		}
		return false
	}
	
    func fetchBookmark(_ bookmark: (key: URL, value: Data)) -> Bool
    {
        guard isSandboxed else { return false }

        let restoredUrl: URL?

		var isStale = true
        var fetch = false

        do
        {
            restoredUrl = try URL.init(resolvingBookmarkData: bookmark.value, options: URL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
        catch let error
        {
            print("! \(bookmark.key) \n\(error.localizedDescription)")
            return false
        }
        
        guard let url = restoredUrl else {
            print ("? \(bookmark.key)")
            return false
        }
        
        if isStale {
            print ("≠ \(bookmark.key)")
			if url.startAccessingSecurityScopedResource() {
				do {
					let data = try url.bookmarkData(options: rwOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
					url.stopAccessingSecurityScopedResource()
					bookmarks[url] = data
					fetch = true
					Swift.print(" \(url) renewal")
				} catch let error {
					Swift.print("¿ \(url) renewal: \(error.localizedDescription)")
				}
			}
        }
        else
		{
			fetch = url.startAccessingSecurityScopedResource()
			print ("\(fetch ? "•" : "º") \(bookmark.key)")
		}
        return fetch
    }
	
	func isBookmarked(_ url: URL) -> Bool {
		guard isSandboxed else { return false }

		if let data = bookmarks[url] {
			if self.fetchBookmark((key: url, value: data)) {
                print ("ß \(url.absoluteString)")
				return true
			}
		}
		return false
	}
}



