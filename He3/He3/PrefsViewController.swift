//
//  PrefsViewController.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 7/5/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
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
		
		//  We want to allow miniaturizations
		panel.styleMask.formUnion(.miniaturizable)
		panel.styleMask.remove(.resizable)

	}
}

class PrefsViewController : NSViewController {
	var appDelegate : AppDelegate {
		get {
			return NSApp.delegate as! AppDelegate
		}
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

	@IBOutlet var enableWebCheckbox: NSButton!
	@IBAction func enableWebPress(_ sender: NSButton) {
	}
	
	@IBOutlet var hideHe3MenuCheckbox: NSButton!
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

	@IBAction func resetDefaults(_ sender: Any) {
		
		if let label = tabView.selectedTabViewItem?.label {
			switch label {
			case "History":
				self.historyKeepField.window?.makeFirstResponder(nil)
				UserSettings.HistoryName.value = UserSettings.HistoryName.default
				UserSettings.HistoryKeep.value = UserSettings.HistoryKeep.default
				
			case "Home Page URL":
				UserSettings.HomePageURL.value = UserSettings.HomePageURL.default
				
			case "Search":
				self.searchKeepField.window?.makeFirstResponder(nil)
				UserSettings.Search.value = UserSettings.Search.default
				UserSettings.SearchKeep.value = UserSettings.SearchKeep.default
				
			case "User Agent String":
				UserSettings.UserAgent.value = UserSettings.UserAgent.default
				
			default:
				fatalError(String(format: "Preferences tabView label? '%@'", label))
			}
		}
	}
	
	//	MARK: Lifecycle
	
	override func viewDidLoad() {
		NotificationCenter.default.addObserver(
			 self,
			 selector: #selector(autoLaunchChange(_:)),
			 name: NSNotification.Name(rawValue: "autoLaunchChange"),
			 object: nil)

		NotificationCenter.default.addObserver(
			 self,
			 selector: #selector(locationServiceChange),
			 name: NSNotification.Name(rawValue: "locationServiceChange"),
			 object: nil)

		tabView.selectTabViewItem(at: 0)
	}
	
	override func viewWillAppear() {
		autoLaunchChange(nil)
		
		changeLocationServiceButton.state = isLocationEnabled ? .on : .off
		
		self.view.window?.title = appDelegate.AppName + " Preferences"
	}
	
	//	MARK: Notifications
	var keys = ["canChangeLocationStatus","isLocationEnabled","locationStatus","locationStatusState"]
	
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
		for key in keys { self.willChangeValue(forKey: key ) }

		appDelegate.userAlertMessage("Location Status Change", info: locationStatusState)
		changeLocationServiceButton.state = isLocationEnabled ? .on : .off

		for key in keys { self.didChangeValue(forKey: key ) }
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
						
						for key in self.keys { self.willChangeValue(forKey: key ) }
						self.launchPrivacyLocationServiceSettings(sender);
						for key in self.keys { self.didChangeValue(forKey: key ) }
					}
				}
			)
			return
		}

		switch sender.tag {
		case 0: // stop,start
			for key in keys { self.willChangeValue(forKey: key ) }
			appDelegate.locationServicesPress(sender)
			for key in keys { self.didChangeValue(forKey: key ) }

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
			let state = String(format: "State: %@:%@ %#:%@",
							   AVMediaType.audio as CVarArg, service(for: .audio),
							   AVMediaType.video as CVarArg, service(for: .video) )
			return state
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
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						for key in self.keys { self.willChangeValue(forKey: key ) }
						if media == .audio {
							self.launchPrivacyMicrophoneServiceSettings(self)
						}
						else
						{
							self.launchPrivacyCameraServiceSettings(self)
						}
						for key in self.keys { self.didChangeValue(forKey: key ) }
					}
				}
			)
			return
		}

		switch sender.tag {
		case 0: // stop,start
			for key in keys { self.willChangeValue(forKey: key ) }
			appDelegate.audioVideoServicesPress(sender)
			for key in keys { self.didChangeValue(forKey: key ) }

		default: // deny
			sheetOKCancel("Authorization required to access Privacy & Settings.",
						  info: nil,
						  acceptHandler:
				{ (button) in
					if button == NSApplication.ModalResponse.alertFirstButtonReturn {
						if media == .audio {
							self.launchPrivacyLocationServiceSettings(sender)
						}
						else
						{
							self.launchPrivacyLocationServiceSettings(sender)
						}
					}
				}
			)
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
}
