//
//  About.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 6/24/17.
//  Copyright © 2017-2020 CD M Santiago. All rights reserved.
//

import Foundation
import AppKit
import Cocoa
import WebKit

let kTitleUtility =		16
let	kTitleNormal =		22

class AboutBoxController : NSViewController {
	
    @objc @IBOutlet var toggleButton: NSButton!
	@objc @IBOutlet var appNameField: NSTextField!
	@objc @IBOutlet var creditScroll: NSScrollView!
	@objc @IBOutlet var creditTabView: NSTabView!
	@objc @IBOutlet var creditsField: NSTextView!
	@objc @IBOutlet var creditsViewer: WKWebView!
	@objc @IBOutlet var creditsButton: NSButton!
    @objc @IBOutlet var versionButton: NSButton!
    @objc @IBOutlet var creditSeparatorBox: NSBox!
    
    @objc @IBOutlet var hideView: NSView!
    var hideRect: NSRect?
    var origRect: NSRect?
    
	@objc @IBOutlet var appNameButton: NSButton!
	@objc @IBAction func appButtonPress(_ sender: Any) {
        var info = Dictionary<String,Any>()
        info[k.name] = appName
        info[k.vers] = versionString!
        info[k.data] = versionData!
        info[k.link] = versionLink!
        info[k.date] = versionDate!
        
        let json = try? JSONSerialization.data(withJSONObject: info, options: [])
        let jsonString = String(data: json!, encoding: .utf8)
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        if pasteboard.setString(jsonString!, forType: NSPasteboard.PasteboardType.string) {
            print("app info copied to pasteboard")
        }
	}
	
    @objc @IBAction func toggleContent(_ sender: Any) {
        // Toggle content visibility
        if let window = self.view.window {
            let oldSize = window.contentView?.bounds.size
            var frame = window.frame
            if toggleButton.state == .off {
                
                frame.origin.y += ((oldSize?.height)! - (hideRect?.size.height)!)
                window.setFrameOrigin(frame.origin)
                window.setContentSize((hideRect?.size)!)
                
                window.showsResizeIndicator = false
                window.minSize = NSMakeSize((hideRect?.size.width)!,(hideRect?.size.height)!+CGFloat(kTitleNormal))
                window.maxSize = window.minSize
                creditScroll.isHidden = true
                showCredits()
            }
            else
            {
                let hugeSize = NSMakeSize(CGFloat(Float.greatestFiniteMagnitude), CGFloat(Float.greatestFiniteMagnitude))
                
                frame.origin.y += ((oldSize?.height)! - (origRect?.size.height)!)
                window.setFrameOrigin(frame.origin)
                window.setContentSize((origRect?.size)!)

                window.showsResizeIndicator = true
                window.minSize = NSMakeSize((origRect?.size.width)!,(origRect?.size.height)!+CGFloat(kTitleNormal))
                window.maxSize = hugeSize
                creditScroll.isHidden = false
            }
        }
    }
    
    internal func showCredits() {
		//	Names *must* match up to assets inventory; "-md" are markdown
		//	requiring processing to html, others are already there as
		//	attributed strings, else plain text.
        let credits = ["README-md", "HISTORY-md", "LICENSE", "he3_privacy"];
        
        if AboutBoxController.creditState >= AboutBoxController.creditStates
        {
            AboutBoxController.creditState = 0
        }
        //	Setup our credits; if sender is nil, give 'em long history
		
		switch AboutBoxController.creditState {/*
		case 0,1:
			let creditsString = NSString.string(fromAsset: credits[AboutBoxController.creditState])
			creditsViewer.loadHTMLString(creditsString, baseURL: nil)
			///creditTabView.selectTabViewItem(at: 0)*/
			
		default:
			let creditsString = NSAttributedString.string(fromAsset: credits[AboutBoxController.creditState])
			self.creditsField.textStorage?.setAttributedString(creditsString)
			self.creditsField.textColor = .textColor
			///creditTabView.selectTabViewItem(at: 1)
		}
    }
    
    @objc @IBAction func cycleCredits(_ sender: Any) {

        AboutBoxController.creditState += 1

        if toggleButton.state == .off {
            if AboutBoxController.creditState >= AboutBoxController.creditsCount
            {
                AboutBoxController.creditState = 0
            }
            creditsButton.title = copyrightStrings![AboutBoxController.creditState % AboutBoxController.creditStates]
        }
        else
        {
            showCredits()
        }
    }
    
	@IBAction func presentPrivacy(_ sender: Any) {
	}
	
	@objc @IBAction func toggleVersion(_ sender: Any) {
        
        AboutBoxController.versionState += 1
        if AboutBoxController.versionState >= AboutBoxController.versionStates
        {
            AboutBoxController.versionState = 0
        }

        let titles = [ versionData, versionLink, versionDate ]
        versionButton.title = titles[AboutBoxController.versionState]!

        let tooltip = [ "version", "build", "timestamp" ]
        versionButton.toolTip = tooltip[AboutBoxController.versionState];
    }

    var versionData: String? = nil
    var versionLink: String? = nil
    var versionDate: String? = nil

    var appName: String {
        get {
            return (NSApp.delegate as! AppDelegate).AppName
        }
    }
    var versionString: String? = nil
    var copyrightStrings: [String]? = nil

    static var versionState: Int = 0
    static let versionStates: Int = 3
    static var creditState: Int = 0
	static let creditStates: Int = 4
    static let creditsCount: Int = 2// CDMS, JG, ...

    override func viewWillAppear() {
        let theWindow = appNameField.window

        //	We no need no sticking title!
        theWindow?.title = ""

        appNameField.stringValue = appName
        versionButton.title = versionData!
        creditsButton.title = copyrightStrings![AboutBoxController.creditState % AboutBoxController.creditsCount]

        if (appNameField.window?.isVisible)! {
            creditsField.scroll(NSMakePoint( 0, 0 ))
        }
        
        // Version criteria to cycle thru
        AboutBoxController.versionState = -1
        toggleVersion(self)

        //  Credit criteria initially hidden
        AboutBoxController.creditState = 0-1
        toggleButton.state = .off
        cycleCredits(self)
        toggleContent(self)
        
        // Setup the window
        theWindow?.isExcludedFromWindowsMenu = true
        theWindow?.menu = nil
        theWindow?.center()

        //	Show the window
        appNameField.window?.makeKeyAndOrderFront(self)
    }
    
    override func viewDidLoad() {
        //	Initially don't show history
        toggleButton.state = .off
 
        //	Get the info dictionary (Info.plist)
        let infoDictionary = (Bundle.main.infoDictionary)!

        //	Setup the version to one we constrict
        versionString = String(format:"Version %@",
                               infoDictionary["CFBuildMajor"] as! CVarArg)

        // Version criteria to cycle thru
        self.versionData = versionString;
        self.versionLink = String(format:"Build %@",
                                  infoDictionary["CFBuildNumber"] as! CVarArg)
        self.versionDate = infoDictionary["CFBuildDate"] as? String;

        //  Capture hide and show initial sizes
        hideRect = hideView.frame
        origRect = self.view.frame

        // Setup the copyrights field; each separated by "|"
        copyrightStrings = (infoDictionary["NSHumanReadableCopyright"] as? String)?.components(separatedBy: "|")
        toggleButton.state = .off
		
		///creditTabView.selectTabViewItem(at: 0)
    }
	
    //  MARK:- TabView Delegate
    
    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            print("tab willSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if let item = tabViewItem {
            print("tab didSelect: label: \(item.label) ident: \(String(describing: item.identifier))")
        }
    }
}
