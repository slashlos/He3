//
//  LaunchControllers.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/13/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import Foundation
import ServiceManagement
import Cocoa

fileprivate var appDelegate : AppDelegate {
    get {
        return NSApp.delegate as! AppDelegate
    }
}

class LaunchController: NSWindowController {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
		let notif = Notification(name: .autoLaunchChange, object: nil)
		NotificationCenter.default.post(notif)
		
		return true
	}
}

class LaunchViewController: NSViewController {
	@objc @IBOutlet var launchCheckbox: NSButton!
	
	@objc @IBAction func launchCancelPress(_ sender: NSButton) {
		if let window = sender.window {
			window.orderOut(sender)
		}
		
		let notif = Notification(name: .autoLaunchChange, object: nil)
		NotificationCenter.default.post(notif)
	}
	
	@objc @IBAction func launchSetPress(_ sender: NSButton) {
		let appBundleIdentifier = "com.slashlos.he3.Launcher"
		let autoLaunch = (launchCheckbox.state == .on)
		
		if SMLoginItemSetEnabled(appBundleIdentifier as CFString, autoLaunch) {
			if autoLaunch {
				NSLog("Successfully add login item.")
			} else {
				NSLog("Successfully remove login item.")
			}
			UserSettings.LoginAutoStartAtLaunch.value = autoLaunch
			UserDefaults.standard.synchronize()

			if let window = sender.window {
				window.orderOut(sender)
			}
		}
		else
		{
			userAlertMessage(String(format: "Failed to update login item: %@",
									autoLaunch ? "Yes" : "No"),
							 info: appBundleIdentifier)
		}
		
		let notif = Notification(name: .autoLaunchChange, object: nil)
		NotificationCenter.default.post(notif)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.
		launchCheckbox.state = UserSettings.LoginAutoStartAtLaunch.value ? .on : .off
	}

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

}
