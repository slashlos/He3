//
//  ShareViewController.swift
//  He3ShareExtension
//
//  Created by Kyle Carson on 10/30/15.
//  Copyright © 2015 Jaden Geller. All rights reserved.
//  Copyright © 2020-2021 CD M Santiago. All rights reserved.
//

import Cocoa

class ShareViewController: NSViewController {

	var os = ProcessInfo().operatingSystemVersion

	override var nibName: NSNib.Name? {
		return NSNib.Name("ShareViewController")
	}

	override func loadView() {
		super.loadView()
	
		Swift.print("running \(os)")
		
		// Insert code here to customize the view
		let item = self.extensionContext!.inputItems[0] as! NSExtensionItem

		switch (os.majorVersion, os.minorVersion, os.patchVersion) {
		case (10, _, _), (11, _, _):
			if let itemProvider = item.attachments?.first, itemProvider.hasItemConformingToTypeIdentifier("public.url")
			{
				itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil)
				{
					(urlData, error) in
					
					if let urlString = String.init(data: (urlData as? Data)!, encoding: .utf8),
					   let url = URL.init(string: urlString),
					   var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
					{
						components.scheme = "he3lium"
						
						if let he3URL = components.url {
							NSWorkspace.shared.open( he3URL )
						}
					}
					self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
					return
				}
			}
			
			if let attachment = item.attachments?.first, attachment.hasItemConformingToTypeIdentifier("public.url")
			{
				attachment.loadItem(forTypeIdentifier: "public.url", options: nil)
				{
					(url, error) in
					
					if let url = url as? URL,
						var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
					{
						components.scheme = "he3liun"
						
						let heliumURL = components.url!
						
						NSWorkspace.shared.open( heliumURL )
					}
					
					self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
					return
				}
			}
			
			let error = NSError(domain: NSCocoaErrorDomain, code: NSURLErrorBadURL, userInfo: nil)
			self.extensionContext!.cancelRequest(withError: error)

		default:
			if let attachments = item.attachments {
				NSLog("Attachments = %@", attachments as NSArray)
			} else {
				NSLog("No Attachments")
			}
		}
	}

	@IBAction func send(_ sender: AnyObject?) {
		let outputItem = NSExtensionItem()
		// Complete implementation by setting the appropriate value on the output item

		let outputItems = [outputItem]
		self.extensionContext!.completeRequest(returningItems: outputItems, completionHandler: {(status) in
			NSLog("send status = %@", status ? "YES" : "NO")

			if status,
			   let item = outputItems.first,
			   let attachment = item.attachments?.first, attachment.hasItemConformingToTypeIdentifier("public.url")
			{
				attachment.loadItem(forTypeIdentifier: "public.url", options: nil) {
					(url, error) in
					
					if let url = url as? URL,
						var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
					{
						components.scheme = "he3lium"
						
						let heliumURL = components.url!
						NSLog("URL = %@", heliumURL.absoluteString)

						NSWorkspace.shared.open( heliumURL )
					}
				}
				
				self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
				return
			}
		})
	}

	@IBAction func cancel(_ sender: AnyObject?) {
		let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
		self.extensionContext!.cancelRequest(withError: cancelError)
	}

}
