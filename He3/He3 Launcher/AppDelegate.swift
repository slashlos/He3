//
//  AppDelegate.swift
//  He3 Launcher
//
//  Created by Carlos D. Santiago on 5/11/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//
//	MARK:- This is an agent app without a UI - just launch He3 and exit
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		NSWorkspace.shared.launchApplication("He3")
		NSApp.terminate(self)
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

}

