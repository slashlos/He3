//
//  PrefsViewController.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 7/5/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
import AppKit

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

		tabView.selectTabViewItem(at: 0)
	}
	
	override func viewWillAppear() {
		autoLaunchChange(nil)
		
		self.view.window?.title = appDelegate.AppName + " Preferences"
	}
	
	//	MARK: Notifications
	
	@objc func autoLaunchChange(_ note: Notification?) {
		autoLaunchCheckbox.state = UserSettings.LoginAutoStartAtLaunch.value ? .on : .off
	}
}
