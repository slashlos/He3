//
//  Panel.swift
//  He3 (Helium)
//
//  Created by shdwprince on 8/10/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//  Copyright © 2017-2020 CD M Santiago. All rights reserved.
//

import Foundation
import Cocoa

extension NSPoint {
    static func - (left: NSPoint, right: NSPoint) -> NSPoint {
        return NSPoint(x: left.x - right.x, y: left.y - right.y)
    }
}

class Panel: NSPanel, NSPasteboardWriting, NSDraggingSource {
    var heliumPanelController : HeliumController {
        get {
            return delegate as! HeliumController
        }
    }
    var promiseFilename : String {
        get {
            return heliumPanelController.promiseFilename
        }
    }
    var promiseURL : URL {
        get {
            return heliumPanelController.promiseURL
        }
    }
    
    var previousMouseLocation: NSPoint?
    
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            // If modifier key was released, dragging should be disabled
            if !event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                previousMouseLocation = nil
            }
        case .leftMouseDown:
            if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                previousMouseLocation = event.locationInWindow
            }
        case .leftMouseUp:
            previousMouseLocation = nil
        case .leftMouseDragged:
            if let previousMouseLocation = previousMouseLocation {
                let delta = previousMouseLocation - event.locationInWindow
                let newOrigin = self.frame.origin - delta
                self.setFrameOrigin(newOrigin)
                return // don't pass event to super
            }
        default:
            break
        }
        
        super.sendEvent(event)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return (context == .outsideApplication) ? [.copy] : []
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return heliumPanelController.performDragOperation(sender)
    }
    
    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        print("ppl type: \(type.rawValue)")
        self.init()
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
       print("ppl type: \(type.rawValue)")
       switch type {
       case .rowDragType:
           return promiseURL.absoluteString as NSString
           
       case .fileURL:
           return KeyedArchiver.archivedData(withRootObject: promiseURL)
           
       case .string:
           return promiseURL.absoluteString
           
       default:
           print("unknown \(type)")
           return nil
       }
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		let types : [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string]

		print("wtp \(types)")
        return types
    }
    
    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        print("wtp type: \(type.rawValue)")
        switch type {
        default:
            return .promised
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    func selectTabItem(_ sender: Any?) {
        if let item = (sender as? NSMenuItem), let window : NSWindow = item.representedObject as? NSWindow, let group = window.tabGroup {
            print("set selected window within group: \(String(describing: window.identifier))")
            group.selectedWindow = window
            windowController?.synchronizeWindowTitleWithDocumentName()
        }
    }
    override func addTabbedWindow(_ window: NSWindow, ordered: NSWindow.OrderingMode) {
        super.addTabbedWindow(window, ordered: ordered)
        window.invalidateRestorableState()
    }
    override func moveTabToNewWindow(_ sender: Any?) {
        super.moveTabToNewWindow(sender)
        self.invalidateRestorableState()
    }
    override func selectPreviousTab(_ sender: Any?) {
        super.selectPreviousTab(sender)
        windowController?.synchronizeWindowTitleWithDocumentName()
    }
    override func selectNextTab(_ sender: Any?) {
        super.selectNextTab(sender)
        windowController?.synchronizeWindowTitleWithDocumentName()
    }
}

class PlaylistsPanel : NSPanel {
    
}

class ReleasePanel : Panel {
    
}

//  Offset a window from the current app key window
extension NSWindow {
    
    var titlebarHeight : CGFloat {
        if self.styleMask.contains(.fullSizeContentView), let svHeight = self.standardWindowButton(.closeButton)?.superview?.frame.height {
            return svHeight
        }

        let contentHeight = contentRect(forFrameRect: frame).height
        let titlebarHeight = frame.height - contentHeight
        return titlebarHeight > k.TitleNormal ? k.TitleUtility : titlebarHeight
    }
    
    func offsetFromKeyWindow() {
        if let keyWindow = NSApp.keyWindow {
            self.offsetFromWindow(keyWindow)
        }
        else
        if let mainWindow = NSApp.mainWindow {
            self.offsetFromWindow(mainWindow)
        }
    }

    func offsetFromWindow(_ theWindow: NSWindow) {
        let titleHeight = theWindow.titlebarHeight
        let oldRect = theWindow.frame
        let newRect = self.frame
        
        //	Offset this window from the window by title height pixels to right, just below
        //	either the title bar or the toolbar accounting for incons and/or text.
        
        let x = oldRect.origin.x + k.TitleNormal
        var y = oldRect.origin.y + (oldRect.size.height - newRect.size.height) - titleHeight
        
        if let toolbar = theWindow.toolbar {
            if toolbar.isVisible {
                let item = theWindow.toolbar?.visibleItems?.first
                let size = item?.maxSize
                
                if ((size?.height)! > CGFloat(0)) {
                    y -= (k.ToolbarItemSpacer + (size?.height)!);
                }
                else
                {
                    y -= k.ToolbarItemHeight;
                }
                if theWindow.toolbar?.displayMode == .iconAndLabel {
                    y -= (k.ToolbarItemSpacer + k.ToolbarTextHeight);
                }
                y -= k.ToolbarItemSpacer;
            }
        }
        
        self.setFrameOrigin(NSMakePoint(x,y))
    }
    
    func overlayWindow(_ theWindow: NSWindow) {
        let oldRect = theWindow.frame
        let newRect = self.frame
//        let titleHeight = theWindow.isFloatingPanel ? k.TitleUtility : k.TitleNormal
        
        //    Overlay this window over the chosen window
        
        let x = oldRect.origin.x
        var y = oldRect.origin.y + (oldRect.size.height - newRect.size.height)
        
        if let toolbar = theWindow.toolbar {
            if toolbar.isVisible {
                let item = theWindow.toolbar?.visibleItems?.first
                let size = item?.maxSize
                
                if ((size?.height)! > CGFloat(0)) {
                    y -= (k.ToolbarItemSpacer + (size?.height)!);
                }
                else
                {
                    y -= k.ToolbarItemHeight;
                }
                if theWindow.toolbar?.displayMode == .iconAndLabel {
                    y -= (k.ToolbarItemSpacer + k.ToolbarTextHeight);
                }
                y -= k.ToolbarItemSpacer;
            }
        }
        self.setFrameOrigin(NSMakePoint(x,y))
    }

}
