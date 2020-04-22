//
//  ShareViewController.swift
//  He3ShareExtension
//
//  Created by Kyle Carson on 10/30/15.
//  Copyright © 2015 Jaden Geller. All rights reserved.
//  Copyright © 2020 CD M Santiago. All rights reserved.
//

import Cocoa

class ShareViewController: NSViewController {

    override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }

    override func loadView() {
        super.loadView()
    
        if let item = self.extensionContext!.inputItems.first as? NSExtensionItem,
            let attachment = item.attachments?.first, attachment.hasItemConformingToTypeIdentifier("public.url")
        {
            attachment.loadItem(forTypeIdentifier: "public.url", options: nil)
			{
				(url, error) in
				
				if let url = url as? URL,
					var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
				{
					
					components.scheme = "he3"
					
					let he3URL = components.url!
					
					NSWorkspace.shared.open( he3URL )
				}
			}
            
            self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        let error = NSError(domain: NSCocoaErrorDomain, code: NSURLErrorBadURL, userInfo: nil)
        self.extensionContext!.cancelRequest(withError: error)
    }

    @IBAction func send(_ sender: AnyObject?) {
        let outputItem = NSExtensionItem()
        // Complete implementation by setting the appropriate value on the output item
    
        let outputItems = [outputItem]
        self.extensionContext!.completeRequest(returningItems: outputItems, completionHandler: nil)
	}

    @IBAction func cancel(_ sender: AnyObject?) {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        self.extensionContext!.cancelRequest(withError: cancelError)
    }

}
