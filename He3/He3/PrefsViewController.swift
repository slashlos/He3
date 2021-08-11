//
//  PrefsViewController.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 7/5/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import Foundation
import AppKit
import CoreLocation
import AVKit

class PrefsPanelController : NSWindowController {
    fileprivate var panel: NSPanel! {
        get {
            return (self.window as! NSPanel)
        }
    }
	
	override func windowDidLoad() {
		//  Default to dragging by content
		panel.standardWindowButton(.zoomButton)?.isHidden = true
		panel.isMovableByWindowBackground = true
		panel.isFloatingPanel = true
		
		//  We want to allow miniaturizations and resize
		panel.styleMask.formUnion(.miniaturizable)
		panel.styleMask.formUnion(.resizable)

	}
}

class PrefsViewController : NSViewController, NSTabViewDelegate {
	var appDelegate : AppDelegate {
		get {
			return NSApp.delegate as! AppDelegate
		}
	}
	@objc var appVersion: String {
		get {
			let infoDictionary = (Bundle.main.infoDictionary)!

			return infoDictionary["CFBundleShortVersionString"] as! String
		}
	}

	func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
		self.willChangeValue(forKey: "resetDefaultsToolTip")
	}

	func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		self.didChangeValue(forKey: "resetDefaultsToolTip")
	}

	//	MARK: Actions
	@IBOutlet var autoHideCheckbox: NSButton!
	@IBAction func autoHidePress(_ sender: NSButton) {
	}
	
	@IBOutlet var autoLaunchCheckbox: NSButton!
	@IBAction func autoLaunchPress(_ sender: NSButton) {
		let storyboard = NSStoryboard(name: "Main", bundle: nil)

		let autoLogin = storyboard.instantiateController(withIdentifier: "LaunchViewController") as! LaunchViewController
		self.presentAsSheet(autoLogin)
	}
	
	@IBOutlet var autoSaveCheckbox: NSButton!
	@IBAction func autoSavePress(_ sender: NSButton) {
		appDelegate.autoSaveDocs = (sender.state == .on)
	}

	@IBAction func colorStatusIcon(_ sender: NSButton) {
		appDelegate.syncAppMenuVisibility()
	}
	
	@IBOutlet var enableWebCheckbox: NSButton!
	@IBAction func enableWebPress(_ sender: NSButton) {
	}
	
	@IBOutlet var showHe3MenuCheckbox: NSButton!
	@IBAction func hideHe3MenuPress(_ sender: Any) {
        appDelegate.syncAppMenuVisibility()
	}
	
	@IBOutlet var magicURLCheckbox: NSButton!
	@IBAction func magicURLPress(_ sender: NSButton) {
	}
	
	@IBOutlet var restoreDocAttrCheckbox: NSButton!
	@IBAction func restoreDocAttrPress(_ sender: NSButton) {
	}
	
	@IBOutlet var restoreWebURLsCheckbox: NSButton!
	@IBAction func restoreWebURLsPress(_ sender: NSButton) {
	}
	
	@IBOutlet var homePageURLView: NSTextView!
	
	@IBAction func clearCookiesPress(_ sender: Any) {
		appDelegate.clearCookliesPress(sender)
	}
	
	@IBOutlet var userAgentView: NSTextView!
	
	@IBOutlet var historyCollectCheckbox: NSButton!
	@IBAction func historyCollectPress(_ sender: NSButton) {
	}
	
	@IBOutlet var historySaveCheckbox: NSButton!
	@IBAction func historySavePress(_ sender: NSButton) {
	}
	
	@IBAction func historyClearPress(_ sender: NSButton) {
		appDelegate.clearHistoryPress(sender)
	}
		
	@IBOutlet var historyKeepField: NSTextField!
	@IBOutlet var searchKeepField: NSTextField!
	@objc var webSearchesCount : Int {
		get {
			return appDelegate.webSearches.count
		}
	}
	@objc var historiesCount : Int {
		get {
			return appDelegate.histories.count
		}
	}
	@IBOutlet var tabView: NSTabView!
	@IBOutlet var resetDefaultsButton: NSButton!
	@objc var resetDefaultsToolTip : String {
		get {
			if let identifier = tabView.selectedTabViewItem?.identifier {
			    let tabIndex = tabView.indexOfTabViewItem(withIdentifier: identifier)
				guard ![0,3].contains(tabIndex) else { return "launch Privacy and Settings App" }
			}
			return "reset tab contents to defaults"
		}
	}
	@IBAction func resetDefaults(_ sender: AnyObject) {
		
		if let identifier = tabView.selectedTabViewItem?.identifier,
		   let toolTip : String = sender.toolTip {
			let tabIndex = tabView.indexOfTabViewItem(withIdentifier: identifier)
			sheetOKCancel(toolTip.capitalized, info: tabIndex == 0 ? nil : "This cannot be undone.", acceptHandler: { (button) in
				if button == NSApplication.ModalResponse.alertFirstButtonReturn {
					switch tabIndex {
					case 0://AudioVideo
						self.launchPrivacyCameraServiceSettings(sender)

					case 1://"History":
						self.historyKeepField.window?.makeFirstResponder(nil)
						UserSettings.HistoryName.value = UserSettings.HistoryName.default
						UserSettings.HistoryKeep.value = UserSettings.HistoryKeep.default
						
					case 2://"Home Page URL":
						UserSettings.HomePageURL.value = UserSettings.HomePageURL.default
						
					case 3://"Location"
						self.launchPrivacyLocationServiceSettings(sender)
						
					case 4://"Search":
						self.searchKeepField.window?.makeFirstResponder(nil)
						UserSettings.Search.value = UserSettings.Search.default
						UserSettings.SearchKeep.value = UserSettings.SearchKeep.default
						
					case 5://"User Agent String":
						UserSettings.UserAgent.value = UserSettings.UserAgent.default
						
					default:
						fatalError(String(format: "Preferences tabView identifier? '%@'", identifier as! CVarArg))
					}
				}
			})
		}
	}
	
	//	MARK: Lifecycle
	
	override func viewDidLoad() {
		NotificationCenter.default.addObserver(
			 self,
			 selector: #selector(autoLaunchChange(_:)),
			 name: .autoLaunchChange,
			 object: nil)

		NotificationCenter.default.addObserver(
			 self,
			 selector: #selector(locationServiceChange),
			 name: .locationServiceChange,
			 object: nil)

		tabView.selectTabViewItem(at: 0)
	}
	
	override func viewWillAppear() {
		autoLaunchChange(nil)
		
		changeLocationServiceButton.state = isLocationEnabled ? .on : .off
		
		self.view.window?.title = appDelegate.AppName + " Preferences"
	}
	
	//	MARK: Notifications
	var locationKeys = ["canChangeLocationStatus","isLocationEnabled","locationStatus","locationStatusState"]
	
	@objc func autoLaunchChange(_ note: Notification?) {
		autoLaunchCheckbox.state = UserSettings.LoginAutoStartAtLaunch.value ? .on : .off
	}
	
	//	MARK:- Location Services
	
	@objc var locationState : Int {
		let status = locationStatus

		switch status {
		case .notDetermined:
			return 0
		case .authorized:
			return 1
		case .restricted,.denied:
			return 2
		default:
			return 0
		}
	}
	@objc var locationStatusState : String {
		get {
			let status = locationStatus
			var state : String?
			
			switch status {
			case .notDetermined:
				state = "location not determined"
				
			case .restricted:
				state = "location restricted"
				
			case .denied:
				state = "location denied"
				
			case .authorizedWhenInUse:
				state = "location authorized when in use"
				
			case .authorizedAlways:
				state = "location authorized always"
				
			default:
				state = "unknown"
			}
			return "State: " + state!
		}
	}
	@objc func locationServiceChange(_ note: Notification?) {
		for key in locationKeys { self.willChangeValue(forKey: key ) }

		appDelegate.userAlertMessage("Location Status Change", info: locationStatusState)
		changeLocationServiceButton.state = isLocationEnabled ? .on : .off

		for key in locationKeys { self.didChangeValue(forKey: key ) }
	}

	var locationStatus : CLAuthorizationStatus {
		get {
			return appDelegate.locationStatus
		}
	}
	var oldlocationStatus : CLAuthorizationStatus = CLLocationManager.authorizationStatus()
	@objc var canChangeLocationStatus : Bool {
		get {
			let status = self.locationStatus
			return ![.restricted,.denied].contains(status)
		}
	}

	@IBOutlet var changeLocationServiceButton: NSButton!
	@objc @IBAction func changeLocationService(_ sender: NSButton) {
		guard ![.restricted,.denied].contains(self.locationStatus) else {
			sheetOKCancel("Services are restricted or denied; reset?",
						  info: "Launch Security & Privacy settings app.",
						  acceptHandler:
				{ (button) in
					//  Make them confirm first
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						
						for key in self.locationKeys { self.willChangeValue(forKey: key ) }
						self.launchPrivacyLocationServiceSettings(sender);
						for key in self.locationKeys { self.didChangeValue(forKey: key ) }
					}
				}
			)
			return
		}

		switch sender.tag {
		case 0: // stop,start
			for key in locationKeys { self.willChangeValue(forKey: key ) }
			appDelegate.locationServicesPress(sender)
			for key in locationKeys { self.didChangeValue(forKey: key ) }

		default: // deny
			sheetOKCancel("Authorization required to access Privacy & Settings.",
						  info: nil,
						  acceptHandler:
				{ (button) in
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						self.launchPrivacyLocationServiceSettings(sender)
					}
				}
			)
		}
	}
	
	@objc var isLocationEnabled : Bool {
		get {
			return appDelegate.isLocationEnabled
		}
		set {
			appDelegate.locationServicesPress(self)
		}
	}

	//	MARK:- AudioVideo Services
	var avKeys = ["audioEnabled","audioState","audioDenyState",
				  "videoEnabled","videoState","videoDenyState"]

	internal func status(for media: AVMediaType) -> AVAuthorizationStatus {
		return appDelegate.avStatus(for: media)
	}
	internal func service(for media: AVMediaType) -> String {
		let status = self.status(for: media).rawValue
		let state = ["not determined","restricted","denied","authorized"][status]
		return state
	}
	internal func privacyURL(for media: AVMediaType) -> URL? {
		return media == .audio ? URL.PrivacyMicrophoneServices : URL.PrivaryCameraServices
	}
	
	@objc var audioVideoStatusState : String {
		get {
			let state = String(format: NSLocalizedString("SERVICE_MSG", comment: ""),
							   service(for: .audio).localizedLowercase,
							   service(for: .video).localizedLowercase )
			return state
		}
	}

	internal func deniedOrRestricted(for media: AVMediaType) -> Bool {
		let status = self.status(for: media)
		return [.restricted,.denied].contains(status)
	}
	internal func authorizedOrUndetermined(for media: AVMediaType) -> Bool {
		let status = self.status(for: media)
		return [.notDetermined,.authorized].contains(status)
	}
	
	@objc var audioEnabled : Bool {
		get {
			return !deniedOrRestricted(for: .audio)
		}
		set {
			
		}
	}
	@objc var audioState : Bool {
		get {
			return .authorized == self.status(for: .audio)
		}
		set {
			
		}
	}

	@objc var audioDenyState: Bool {
		get {
			return deniedOrRestricted(for: .audio)
		}
		set {
			
		}
	}
	
	@objc var videoEnabled : Bool {
		get {
			return !deniedOrRestricted(for: .video)
		}
		set {
			
		}
	}
	@objc var videoState : Bool {
		get {
			return .authorized == self.status(for: .video)
		}
		set {
			
		}
	}
	
	@objc var videoDenyState : Bool {
		get {
			return deniedOrRestricted(for: .video)
		}
		set {
			
		}
	}

	@IBOutlet var changeAudioServiceButton: NSButton!
	@IBOutlet var changeVideoServiceButton: NSButton!
	
	@objc @IBAction func changeAudioVideoService(_ sender: NSButton) {
		let service = sender.title.components(separatedBy: " ").last
		let media : AVMediaType = service == "Audio" ? .audio : .video
		guard ![.restricted,.denied].contains(self.status(for: media)) else {
			sheetOKCancel(String(format: "%@ Services are restricted or denied; reset?", media.rawValue as CVarArg),
						  info: "Launch Security & Privacy settings app.",
						  acceptHandler:
				{ (button) in
					//  Make them confirm first
					for key in self.avKeys { self.willChangeValue(forKey: key ) }
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						if media == .audio {
							self.launchPrivacyMicrophoneServiceSettings(self)
						}
						else
						{
							self.launchPrivacyCameraServiceSettings(self)
						}
					}
					for key in self.avKeys { self.didChangeValue(forKey: key ) }
				}
			)
			return
		}

		switch sender.tag {
		case 0: // stop,start
			for key in avKeys { self.willChangeValue(forKey: key ) }
			appDelegate.audioVideoServicesPress(sender)
			for key in avKeys { self.didChangeValue(forKey: key ) }

		default: // deny
			sheetOKCancel("Authorization required to access Privacy & Settings.",
						  info: nil,
						  acceptHandler:
				{ (button) in
					for key in self.avKeys { self.willChangeValue(forKey: key ) }
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						if media == .audio {
							self.launchPrivacyMicrophoneServiceSettings(sender)
						}
						else
						{
							self.launchPrivacyCameraServiceSettings(sender)
						}
					}
					for key in self.avKeys { self.didChangeValue(forKey: key ) }
				}
			)
		}
	}

	@IBAction func launchPrivaryServices(_ sender: Any) {
		if let PrivacyServices = URL.PrivacyServices {
			NSWorkspace.shared.open(PrivacyServices)
		}
	}
	@IBAction func launchPrivacyMicrophoneServiceSettings(_ sender: Any) {
		if let PrivacyMicrophoneServices = URL.PrivacyMicrophoneServices {
			NSWorkspace.shared.open(PrivacyMicrophoneServices)
		}
	}
	@IBAction func launchPrivacyCameraServiceSettings(_ sender: Any) {
		if let PrivacyCameraServices = URL.PrivaryCameraServices {
			NSWorkspace.shared.open(PrivacyCameraServices)
		}
	}
	@IBAction func launchPrivacyLocationServiceSettings(_ sender: Any) {
		if let PrivacyLocationServices = URL.PrivacyLocationServices {
			NSWorkspace.shared.open(PrivacyLocationServices)
		}
	}
	@IBAction func launchPrivacyAudioVideoServiceSettings(_ sender: AnyObject) {
		if sender.tag == 0 {
			self.launchPrivacyMicrophoneServiceSettings(sender)
		}
		else
		{
			self.launchPrivacyCameraServiceSettings(sender)
		}
	}
}
