/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Operation subclass to create a thumbnail image from a given URL.
*/

import Cocoa
import Foundation

class LoadThumbnailssOperationFor: Operation {
    
	var playlist: PlayList
	
	init(playlist: PlayList) {
		self.playlist = playlist
        super.init()
    }
    
    override var isAsynchronous: Bool { return true }
    
    override func main() {
		//	tell all our items to load their thumbnail image
		if !playlist.list.isEmpty {
			for item in playlist.list {
				item.loadThumbnail()
			}
        }
    }
}

class LoadThumbnailOperation: Operation {

    private let thumbHeight: CGFloat = 48.0
    private let thumbWidth: CGFloat = 48.0
    
	var itemURL: URL!
    var thumbnailImage: NSImage!
    
    init(url: URL) {
		itemURL = url
        super.init()
    }
    
    override var isAsynchronous: Bool { return true }
    
    override func main() {
        if  nil == thumbnailImage {
            let maximumSize = NSSize(width: thumbWidth, height: thumbHeight)
			self.thumbnailImage = PlayItem.loadThumbnailFor(itemURL, size: maximumSize)
        } else {
            Swift.debugPrint("Could not allocate this image for \(String(describing: self.itemURL))")
        }
    }
    
}
