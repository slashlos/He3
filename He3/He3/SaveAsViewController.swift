//
//  SaveAsViewController.swift
//  He3
//
//  Created by Carlos D. Santiago on 11/1/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import Foundation
import AppKit

class SaveAsViewController : NSViewController {
	
	@objc var document : Document?
	
	@IBOutlet var secureFileEncoding: NSButton!
	@IBAction func secureFileAction(_ sender: Any) {
		guard let doc = document else { return }
		doc.secureFileEncoding = secureFileEncoding.state == .on
	}
	@IBOutlet var formatPopup: NSPopUpButton!
	@IBOutlet var webArchiveMenuItem: NSMenuItem!
}
