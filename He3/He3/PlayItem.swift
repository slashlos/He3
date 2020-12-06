//
//  PlayItem.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/8/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import Foundation
import QuickLook

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}

extension NSPasteboard.PasteboardType {
    static let playitem = NSPasteboard.PasteboardType(PlayItem.className())
}

enum PlayItemError: Error {
	case unknownTypeIdentifer
}

// Queue for loading thumbnail images for each PhotoItem object.
var thumbNailLoaderQueue: OperationQueue = {
    let queue = OperationQueue()
    return queue
}()

protocol ThumbnailDelegate: AnyObject {
	func thumbnailDidFinish(_ playitem: PlayItem)
}

class PlayItem : NSObject, NSCoding, NSCopying, NSDraggingSource, NSDraggingDestination, NSPasteboardWriting, NSPasteboardReading, NSSecureCoding {
	static var supportsSecureCoding: Bool = true

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
		return context == .withinApplication ? .link : .every
    }
    
    @objc dynamic var name : String = k.item
	@objc dynamic var link : URL = URL.init(string: "http://")! {
		didSet {
			_thumbnailImage = nil
		}
	}
    @objc dynamic var time : TimeInterval = 0
    @objc dynamic var date : TimeInterval = Date().timeIntervalSinceReferenceDate
    @objc dynamic var rank : Int = 0
    @objc dynamic var rect : NSRect = NSZeroRect
	@objc dynamic var tRect: String {
		get {
			return NSStringFromRect(rect)
		}
		set (value) {
			self.rect = NSRectFromString(value)
		}
	}
    @objc dynamic var plays: Int = 0
	@objc dynamic var label: Int = UserSettings.AutoHideTitle.value ? 1 : 0
    @objc dynamic var hover: Int = 0
    @objc dynamic var alpha: Int = 0
	@objc dynamic var opacity: CGFloat {
		get {
			return CGFloat(alpha) / 10.0
		}
		set (value) {
			self.alpha = Int(value * 10.0)
		}
	}
    @objc dynamic var trans: Int = 0
    @objc dynamic var agent: String = UserSettings.UserAgent.value
    @objc dynamic var turl : String {
        get {
            return link.absoluteString
        }
        set (value) {
			if let url = URL.init(string: value) {
				link = url
			}
			else
			{
				NSSound.beep()
			}
        }
    }
	
	var _thumbnailImage: NSImage?
    @objc dynamic var thumbnailImage: NSImage {
        get {
			guard _thumbnailImage == nil else { return _thumbnailImage! }
			let size = NSSize(width: thumbWidth, height: thumbHeight)
			
			_thumbnailImage = PlayItem.loadThumbnailFor(link, size: size)
			return _thumbnailImage!
		}
		set (image) {
			_thumbnailImage = image
		}
	}
	
    private var thumbnailLoading = false
    private let thumbHeight: CGFloat = 48.0
    private let thumbWidth: CGFloat = 48.0
    
    // Delegate to notify when this photo's thumbnail creation is done.
    weak var thumbnailDelegate: ThumbnailDelegate?

	func loadThumbnail() {
		if _thumbnailImage == nil && !thumbnailLoading {
			thumbnailLoading = true
			
            // Set up the async operation to create the thumbnail image.
            let loadThumbnailOperation = LoadThumbnailOperation(url: link)

            // Set up the completion block so we know when the thumbnail image is done.
            loadThumbnailOperation.completionBlock = {
                // Finished creating the thumbnail image.
                OperationQueue.main.addOperation {
                    self.thumbnailImage = loadThumbnailOperation.thumbnailImage
                    self.thumbnailLoading = false
                        
                    // Notify our delegate the thumbnail is ready.
                    self.thumbnailDelegate?.thumbnailDidFinish(self)
                }
            }
            // Start the async load all the photos.
            thumbNailLoaderQueue.addOperation(loadThumbnailOperation)
		}
    }
	
	class func loadThumbnailFor(_ url: URL, size: NSSize) -> NSImage {
		if url.isFileURL {
			let asIcon = false /// we want typical icon decor?
			let dict = [
				kQLThumbnailOptionIconModeKey: NSNumber(booleanLiteral: asIcon)
			] as CFDictionary
			
			let ref = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL, size, dict)
			if let cgImage = ref?.takeUnretainedValue() {
				let thumbnailImage = NSImage(cgImage: cgImage, size: size)
				ref?.release()
				return thumbnailImage
			}
		}
		return ((NSImage.init(named: k.itemIcon)?.resize(w: size.width, h: size.height))!)
	}
	
	// MARK:- Functions
    override init() {
		name = String(format:"%@#%@",k.item,UUID().uuidString)
        link = URL.init(string: "about://blank")!
        time = 0.0
        date = Date().timeIntervalSinceReferenceDate
        rank = 0
        rect = NSZeroRect
        plays = 0
        label = 0
        hover = 0
        alpha = 60
        trans = 0
        agent = UserSettings.UserAgent.value
        super.init()
    }
    init(name:String, link:URL, time:TimeInterval, rank:Int) {
        self.name = name
        self.link = link
        self.date = Date().timeIntervalSinceReferenceDate
        self.time = time
        self.rank = rank
        self.rect = NSZeroRect
        self.plays = 1
        self.label = 0
        self.hover = 0
        self.alpha = 60
        self.trans = 0
        self.agent = UserSettings.UserAgent.value
        super.init()
    }
    init(name:String, link:URL, date:TimeInterval, time:TimeInterval, rank:Int, rect:NSRect, plays:Int, label:Int, hover:Int, alpha:Int, trans: Int, agent: String) {
        self.name = name
        self.link = link
        self.date = date
        self.time = time
        self.rank = rank
        self.rect = rect
        self.plays = plays
        self.label = label
        self.hover = hover
        self.alpha = alpha
        self.trans = trans
        self.agent = agent
        super.init()
    }
    convenience init(with dictionary: Dictionary<String,Any>) {
        self.init()
        self.update(with: dictionary)
    }
    
    func update(with dictionary: Dictionary<String,Any>) {
        if let name : String = dictionary[k.name] as? String, name != self.name {
            self.name = name
        }
        if let link : URL = dictionary[k.link] as? URL, link != self.link {
            self.link = link
        }
        else
        if let urlString : String = dictionary[k.link] as? String, let link = URL.init(string: urlString), link != self.link {
            self.link = link
        }
        if let date : TimeInterval = dictionary[k.date] as? TimeInterval, date != self.date {
            self.date = date
        }
        if let time : TimeInterval = dictionary[k.time] as? TimeInterval, time != self.time {
            self.time = time
        }
        if let rank : Int = dictionary[k.rank] as? Int, rank != self.rank {
            self.rank = rank
        }
        if let rect = dictionary[k.rect] as? NSRect, rect != self.rect {
            self.rect = rect
        }
        if let plays : Int = dictionary[k.plays] as? Int, plays != self.plays {
            self.plays = plays
        }
        self.plays = (self.plays == 0) ? 1 : self.plays // default missing value
        if let label : Int = dictionary[k.label] as? Int, label != self.label  {
            self.label  = label
        }
        if let hover : Int = dictionary[k.hover] as? Int, hover != self.hover {
            self.hover = hover
        }
        if let alpha : Int = dictionary[k.alpha] as? Int, alpha != self.alpha {
            self.alpha = alpha
        }
        if let trans : Int = dictionary[k.trans] as? Int, trans != self.trans {
            self.trans = trans
        }
        if let agent : String = dictionary[k.agent] as? String, agent != self.agent {
            self.agent = agent
        }
    }
    override var description : String {
        return String(format: "%@: %p '%@'", self.className, self, name)
    }
    
	var fileURL: URL {
		get {
			let path = (name.hasSuffix(k.h3i) || name.hasSuffix(k.hpi)) ? name : name + "." + k.hpi
			return URL.init(fileURLWithPath: path)
		}
	}

    func dictionary() -> Dictionary<String,Any> {
        var dict = Dictionary<String,Any>()
        dict[k.name] = name
        dict[k.link] = link.absoluteString
        dict[k.date] = date
        dict[k.time] = time
        dict[k.rank] =  rank
        dict[k.rect] = NSStringFromRect(rect)
        dict[k.plays] = plays
        dict[k.label] = label
        dict[k.hover] = hover
        dict[k.alpha] = alpha
        dict[k.trans] = trans
        dict[k.agent] = agent
        return dict
    }

    // MARK:- NSCoder
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: k.name) as! String
        let link = URL.init(string: coder.decodeObject(forKey: k.link) as! String)
        let date = coder.decodeDouble(forKey: k.date)
        let time = coder.decodeDouble(forKey: k.time)
        let rank = coder.decodeInteger(forKey: k.rank)
        let rect = NSRectFromString(coder.decodeObject(forKey: k.rect) as! String)
        let plays = coder.decodeInteger(forKey: k.plays)
        let label = coder.decodeInteger(forKey: k.label)
        let hover = coder.decodeInteger(forKey: k.hover)
        let alpha = coder.decodeInteger(forKey: k.alpha)
        let trans = coder.decodeInteger(forKey: k.trans)
        let agent = coder.decodeObject(forKey: k.agent) as! String
        self.init(name: name, link: link!, date: date, time: time, rank: rank, rect: rect,
                  plays: plays, label: label, hover: hover, alpha: alpha, trans: trans, agent: agent)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(link.absoluteString, forKey: k.link)
        coder.encode(date, forKey: k.date)
        coder.encode(time, forKey: k.time)
        coder.encode(rank, forKey: k.rank)
        coder.encode(NSStringFromRect(rect), forKey: k.rect)
        coder.encode(plays, forKey: k.plays)
        coder.encode(label, forKey: k.label)
        coder.encode(hover, forKey: k.hover)
        coder.encode(alpha, forKey: k.alpha)
        coder.encode(trans, forKey: k.trans)
        coder.encode(agent, forKey: k.agent)
    }
    
    // MARK:- NSCopying
    convenience required init(_ with: PlayItem) {
        self.init()
        
        self.name  = with.name
        self.link  = with.link
        self.date  = with.date
        self.time  = with.time
        self.rank  = with.rank
        self.rect  = with.rect
        self.plays = with.plays
        self.label = with.label
        self.hover = with.hover
        self.alpha = with.alpha
        self.trans = with.trans
        self.agent = with.agent
    }
    
    func copy(with zone: NSZone? = nil) -> Any
    {
        return type(of:self).init(self)
    }
    
    // MARK:- Pasteboard Reading
    
    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        print("itemR type: \(type.rawValue)")
        switch type {
        case .rowDragType:
            self.init(with: propertyList as! Dictionary)
            
        case .playitem:
			self.init()
			if let dictionary = defaults.dictionary(forKey: propertyList as! String) {
				self.update(with: dictionary)
			}
			
		case .string:
            self.init()
            if let xmlString = propertyList as? String {
                print("convert \(xmlString) to playitem")
            }
            
        default:
            fatalError("PlayItem propertyList type \(type.rawValue)")
        }
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		return [.rowDragType, .playitem, .string]
    }
    
    // MARK:- Pasteboard Writing

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        print("itemW type: \(type.rawValue)")
        switch type {
        case .rowDragType:
            return self.dictionary()
			
		case .playitem:
			defaults.set(self.dictionary(), forKey: name as String)
			return name

        case .string:
			do {
				let data : Data = try JSONSerialization.data(
					withJSONObject: self.dictionary(),
					options: JSONSerialization.WritingOptions.prettyPrinted)
				return NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
			} catch let error {
				DispatchQueue.main.async {
					NSApp.presentError(error)
				}
			}

        default:
            print("unknown \(type)")
        }
		
		return nil
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		return [.rowDragType, .playitem, .string]
    }
	
	//	MARK:- Item Provider Reading
	static var readableTypeIdentifiersForItemProvider = [kUTTypeData as String, kUTTypePlainText as String]
	
	required init(itemProviderData data: Data, typeIdentifier: String) throws {
		super.init()
		
		switch typeIdentifier {
		case kUTTypeData as NSString as String:
			
			let dict = KeyedUnarchiver.unarchiveObject(with: data)
			self.update(with: dict as! Dictionary<String, Any>)

		case kUTTypePlainText as NSString as String:
			do {
				let json = try JSONSerialization.jsonObject(with: data, options: [])
				self.update(with: json as! Dictionary<String, Any>)
			} catch let error {
				DispatchQueue.main.async {
					NSApp.presentError(error)
				}
			}
			
		default:
			throw PlayItemError.unknownTypeIdentifer
		}
	}
	
	static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
		do {
			let item = try PlayItem.init(itemProviderData: data, typeIdentifier: typeIdentifier)
			return item as! Self
		} catch let error {
			print("object: \(error.localizedDescription)")
			throw PlayItemError.unknownTypeIdentifer
		}
	}
	
	//	MARK:- Item Provider Writing

	static var writableTypeIdentifiersForItemProvider = [kUTTypeData as String, kUTTypePlainText as String]
	
	func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
		let dataLoader = PlayItemDataLoader()
		
		let progress = Progress(totalUnitCount: 100)
		var shouldContinue = true
		progress.cancellationHandler = {
			shouldContinue = false
		}
		
		switch typeIdentifier {
		case kUTTypeData as NSString as String:
			dataLoader.beginLoading(update: { percentDone in
				progress.completedUnitCount = percentDone
				return shouldContinue
			}, completionHandler: completionHandler)
			
			let data = KeyedArchiver.archivedData(withRootObject: self.dictionary())
			completionHandler(data, nil)
			
		case kUTTypePlainText as NSString as String:
			do {
				//	convert dictionary to data to json
				let data = try JSONSerialization.data(withJSONObject: self.dictionary(), options: .prettyPrinted)
				let json = try JSONSerialization.jsonObject(with: data, options: [])
				print("\(String(describing: json))")
				progress.completedUnitCount = 100
				completionHandler(data, nil)
			} catch let error {
				DispatchQueue.main.async {
					completionHandler(nil,error)
				}
			}
			
		default:
			break
		}
		
		return progress
	}
	
	/* item writing
	let itemProvider = NSItemProvider(object: <PlayItem>) /// uses object signature
	*/
	
	/* item reading - like tableView performDrop
	
	if itemProvider.canLoadObject(ofClass: PlayItem.self) {
		itemProvider.loadObject(ofClass: PlayItem.self) {
			(object,error) in
				// object is our PlayItem
				DispatchQueue.main.async {
					if let PlayItem = object as? PlayItem {
						/// do something with PlayItem - directly or project
						self.add(PlayItem, at: row)///or update if .on
					}
					else
					{
						self.display(error)
					}
				}
		}
	}
	*/
}

class PlayItemDataLoader: PlayItem {
	
	func beginLoading(update:  @escaping (Int64) -> Bool,
					  completionHandler: @escaping (Data?, Error?) -> Void) {
		
	}
}

