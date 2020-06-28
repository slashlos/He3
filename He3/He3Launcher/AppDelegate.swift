//
//  AppDelegate.swift
//  He3 Launcher
//
//  Created by Carlos D. Santiago on 5/11/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//
//	MARK:- This is an agent app without a UI - just launch He3 and exit
import Cocoa

extension Notification.Name {
    static let killHe3Launcher = Notification.Name("killHe3Launcher")
}

@NSApplicationMain
class AppDelegate: NSObject {
	@objc func terminate() {
		NSApp.terminate(nil)
	}
}

extension AppDelegate: NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		// Insert code here to initialize your application
		let he3AppIdentifier = "com.slashlos.he3"
		let runningApps = NSWorkspace.shared.runningApplications
		let isRunning = !runningApps.filter{ $0.bundleIdentifier == he3AppIdentifier }.isEmpty
		
		if !isRunning {
            DistributedNotificationCenter.default().addObserver(self,
																selector: #selector(self.terminate),
																name: .killHe3Launcher,
																object: he3AppIdentifier)
			let path = Bundle.main.bundlePath as NSString
			var components = path.pathComponents
			components = (components as NSArray).subarray(with: NSMakeRange(0, components.count-4)) as! [String]
			components.append("Contents")
			components.append("MacOS")
			components.append("He3") //main app name

			let newPath = NSString.path(withComponents: components)

			NSWorkspace.shared.launchApplication(newPath)
		}
		self.terminate()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

}

