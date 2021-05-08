//
//  ColorController.swift
//  He3
//
//  Created by Carlos D. Santiago on 2/25/21.
//  Copyright © 2021 Carlos D. Santiago. All rights reserved.
//

import Foundation
import Cocoa

class He3ColorWell: NSColorWell {
	override func activate(_ exclusive: Bool) {
		NSColorPanel.shared.showsAlpha = true;
		super.activate(exclusive);
	}

	override func deactivate() {
		NSColorPanel.shared.showsAlpha = false;
		super.deactivate();
	}
}

class ColorController : NSWindowController {
	
}

class ColorViewController : NSViewController
{
	var panel : HeliumController {
		get {
			return self.representedObject as! HeliumController
		}
	}
	
	@objc @IBOutlet var backgroundColor: NSColor?

	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.
		let color = panel.backgroundColorPreference ?? panel.homeColor
		colorWell.color = color
		colorField.stringValue = color.toHexString
	}
	
	override func viewWillAppear() {
		let cp = NSColorPanel.shared
		super.viewWillAppear()
		
		if cp.isVisible {
			cp.orderOut(self)
		}
		
		if NSColorPanel.sharedColorPanelExists {
			colorWell.deactivate()
		}
	}
	
	@IBOutlet weak var colorWell: NSColorWell!

	@objc @IBAction func colorWellAction(_ sender: NSColorWell) {
		Swift.print("colorWellAction")
		let color = sender.color

		colorWell.color = color
		panel.backgroundColorPreference = color
		colorField.stringValue = color.toHexString
	}
	
	@objc @IBAction func dismiss(_ sender: Any) {
		Swift.print("dismiss: \(sender)")

		if 0 != (sender as AnyObject).tag {
			colorReset(sender)
		}
		
		let cp = NSColorPanel.shared
		super.viewWillAppear()
		
		if cp.isVisible {
			cp.orderOut(self)
		}
		
		if NSColorPanel.sharedColorPanelExists {
			colorWell.deactivate()
		}

		self.view.window?.orderOut(sender)
	}
	
	@IBOutlet weak var colorField: NSTextField!
	@IBAction func colorFieldAction(_ sender: Any) {
		var value = colorField.stringValue
		
		if value.count < 9 {
			let iAlpha = colorWell.color.alphaComponent
			if value.hasPrefix("#") { value = String(value.dropFirst()) }
			
			value = String(format: "#%02x%@", Int(iAlpha*255), value)
		}

		Swift.print("colorFieldAction: \(value)")
		colorWell.color = NSColor(name: value)
		panel.backgroundColorPreference = colorWell.color
	}
	
	@IBAction func colorReset(_ sender: Any) {
		Swift.print("colorReset")

		colorWell.color = backgroundColor ?? panel.homeColor
	}
}
