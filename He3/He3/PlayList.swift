//
//  PlayList.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/8/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import Cocoa
import Foundation
import ContactsUI
import Contacts

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}

extension NSPasteboard.PasteboardType {
    static let playlist = NSPasteboard.PasteboardType(PlayList.className())
}

enum PlayListError: Error {
	case unknownTypeIdentifer
}

class PlayList : NSObject, NSCoding, NSCopying, NSDraggingSource, NSDraggingDestination, NSPasteboardWriting, NSPasteboardReading, NSSecureCoding, NSItemProviderReading, NSItemProviderWriting {
	static var supportsSecureCoding: Bool = true
	
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
		return context == .withinApplication ? .link : .every
    }
    
    @objc dynamic var name : String = k.name
    @objc dynamic var list : Array <PlayItem> = Array()
    @objc dynamic var date : TimeInterval = Date.timeIntervalSinceReferenceDate
    @objc dynamic var tally: Int {
        get {
            return self.list.count
        }
    }
    @objc dynamic var plays: Int {
        get {
            var plays = 0
            for item in self.list {
                plays += item.plays
            }
            return plays
        }
    }
    @objc dynamic var shiftKeyDown : Bool {
        get {
            return (NSApp.delegate as! AppDelegate).shiftKeyDown
        }
    }
    @objc dynamic var optionKeyDown : Bool {
        get {
            return (NSApp.delegate as! AppDelegate).optionKeyDown
        }
    }

    @objc @IBOutlet weak var tooltip : NSString! {
        get {
            if shiftKeyDown {
                return String(format: "%ld play(s)", self.plays) as NSString
            }
            else
            {
                return String(format: "%ld item(s)", self.list.count) as NSString
            }
        }
        set (value) {
            
        }
    }
	
	@objc dynamic var _thumbnailImage: NSImage?
	@objc dynamic var thumbnailImage: NSImage {
		get {
			guard _thumbnailImage == nil else { return _thumbnailImage! }

			_thumbnailImage = NSImage.init(named: k.listIcon)?.resize(w: 48, h: 48)
			return _thumbnailImage!
		}
	}

    override var description: String {
        get {
            return String(format: "<%@: %p '%@' %ld item(s)", self.className, self, self.name, list.count)
        }
    }
    
	var fileURL: URL {
		get {
			let path = [k.h3l,k.hpl].contains(name.pathExtension) ? name : name + "." + k.hpl
			return URL.init(fileURLWithPath: path)
		}
	}
	
    // MARK:- Functions
    override init() {
        date = Date().timeIntervalSinceReferenceDate
        super.init()

        list = Array <PlayItem> ()
		name = String(format:"%@#%@",k.play,UUID().uuidString)

        //  watch shift key changes affecting our playlist
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shiftKeyDown(_:)),
			name: .shiftKeyDown,
            object: nil)

        //  watch option key changes affecting our playlist
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(optionKeyDown(_:)),
			name: .optionKeyDown,
            object: nil)
    }
    
    @objc internal func shiftKeyDown(_ note: Notification) {
		self.kvoToolTips([Notification.Name.shiftKeyDown.rawValue])
    }
    
    @objc internal func optionKeyDown(_ note: Notification) {
		self.kvoToolTips([Notification.Name.optionKeyDown.rawValue])
    }

    convenience init(name:String, list:Array <PlayItem>) {
        self.init()

        self.list = list
        self.name = name
    }
    
    func dictionary() -> Dictionary<String,Any> {
        var dict = Dictionary<String,Any>()
        var items: [Any] = Array()
        for item in self.list {
            items.append(item.dictionary())
        }
        dict[k.name] = self.name
        dict[k.list] = items
        dict[k.date] = self.date
        return dict
    }
    convenience init(with dictionary: Dictionary<String,Any>) {
        self.init()
        
        self.update(with: dictionary, createMissingItems: true)
    }
    func update(with dictionary: Dictionary<String,Any>, createMissingItems: Bool = false) {
		guard 3 == dictionary.keys.count, dictionary.keys.sorted().elementsEqual([k.date,k.list,k.name]) else { return }
        if let name : String = dictionary[k.name] as? String, name != self.name {
            self.name = name
        }
        if let plists : [Dictionary<String,Any>] = dictionary[k.list] as? [Dictionary<String,Any>] {
            
            for plist in plists {
				if !createMissingItems,
				   let item1 : PlayItem = list.name(plist[k.name] as! String),
				   let item2 : PlayItem = list.link(plist[k.link] as! String), item1 == item2
				{
                    item1.update(with: plist)
                }
                else
                if createMissingItems
                {
					self.list.append(PlayItem(from: plist))
                }
            }
        }
        if let date : TimeInterval = dictionary[k.date] as? TimeInterval, date != self.date {
            self.date = date
        }
    }
    
    // MARK:- NSCoder
    required convenience init(coder: NSCoder) {
        let name = coder.decodeObject(forKey: k.name) as! String
        let list = coder.decodeObject(forKey: k.list) as! [PlayItem]
        let date = coder.decodeDouble(forKey: k.date)
        self.init(name: name, list: list)
        self.date = date
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: k.name)
        coder.encode(list, forKey: k.list)
        coder.encode(date, forKey: k.date)
    }
    
    // MARK:- NSCopying
    convenience required init(_ with: PlayList) {
        self.init()
        
        self.name = with.name
        self.list = with.list
        self.date = with.date
    }
    
    func copy(with zone: NSZone? = nil) -> Any
    {
        return type(of:self).init(self)
    }
    
    // MARK:- Pasteboard Reading

    required convenience init(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        print("listR type: \(type.rawValue)")
        switch type {
        case .rowDragType:
            self.init(with: propertyList as! Dictionary)
		
		case .playlist:
			self.init()
			if let playname = propertyList as? String, let dictionary = defaults.dictionary(forKey: playname) {
				self.update(with: dictionary, createMissingItems: true)
			}
			
        case .string:///JSON
            self.init()
            if let xmlString = propertyList as? String {
                print("convert \(xmlString) to playlist")
            }
            
        default:
            fatalError("PlayList propertyList type \(type.rawValue)")
        }
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
		return [.rowDragType, .playlist, .string]
    }
    
    // MARK:- Pasteboard Writing

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        print("listW type: \(type.rawValue)")
        switch type {
		case .rowDragType:
			return self.dictionary()

		case .playlist:
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
		return [.rowDragType, .playitem, .playlist, .string]
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
			throw PlayListError.unknownTypeIdentifer
		}
	}
	
	static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
		do {
			let item = try PlayList(itemProviderData: data, typeIdentifier: typeIdentifier)
			return item as! Self
		} catch let error {
			print("object: \(error.localizedDescription)")
			throw PlayListError.unknownTypeIdentifer
		}
	}
	
	//	MARK:- Item Provider Writing

	static var writableTypeIdentifiersForItemProvider = [kUTTypeData as String, kUTTypePlainText as String]
	
	func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
		let dataLoader = PlayListDataLoader()
		
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
	let itemProvider = NSItemProvider(object: <playlist>) /// uses object signature
	*/
	
	/* item reading - like tableView performDrop
	
	if itemProvider.canLoadObject(ofClass: PlayList.self) {
		itemProvider.loadObject(ofClass: Playlist.self) {
			(object,error) in
				// object is our PlayList
				DispatchQueue.main.async {
					if let playlist = object as? PlayList {
						/// do something with playlist - directly or project
						self.add(playlist, at: row)///or update if .on
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

class PlayListDataLoader: PlayList {
	
	func beginLoading(update:  @escaping (Int64) -> Bool,
					  completionHandler: @escaping (Data?, Error?) -> Void) {
		
	}
}
