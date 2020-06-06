//
//  Types+Settings.swift
//  He3
//
//  Created by Carlos D. Santiago on 5/9/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
import Cocoa

//  Global static strings
public struct k {
	static let AppName = "He3"
	static let AppLogo = "Above all else"
    static let Helium = "Helium"
    static let Incognito = "Incognito"
    static let scheme = "he3"
    static let caches = "he3-local" /// cache string
    static let oauth2 = "he3-oauth" /// oauth handler
    static let he3 = "he3"
    static let asset = "asset"
    static let html = "html"
    static let text = "text"
    static let mime = "mime"
    static let type = "type"
	static let wrap = "wrap"
	static let asis = "asis"
    static let utf8 = "UTF-8"
    static let desktop = "Desktop"
    static let docIcon = "he3_logo"
	static let listIcon = "listIcon"
	static let itemIcon = "itemIcon"
	static let icntIcon = "icntIcon"
    static let Playlist = "Playlist"
    static let Playlists = "Playlists"
    static let playlists = "playlists"
	static let Playitem = "Playitem"
    static let Playitems = "Playitems"
    static let playitems = "playitems"
    static let Settings = "settings"
    static let Custom = "Custom"
    static let webloc = "webloc"
    static let hpi = "h3i"
    static let hpl = "h3l"
	static let hic = "h3c"
    static let play = "play"
    static let item = "item"
    static let name = "name"
    static let list = "list"
	static let tally = "tally"
    static let tooltip = "tooltip"
    static let link = "link"
    static let date = "date"
    static let time = "time"
    static let rank = "rank"
    static let rect = "rect"
    static let plays = "plays"
    static let label = "label"
    static let hover = "hover"
    static let alpha = "alpha"
    static let trans = "trans"
    static let agent = "agent"
    static let view = "view"
    static let fini = "finish"
    static let vers = "vers"
    static let data = "data"
    static let turl = "turl"
    static let TitleUtility: CGFloat = 16.0
    static let TitleNormal: CGFloat = 22.0
    static let ToolbarItemHeight: CGFloat = 48.0
    static let ToolbarItemSpacer: CGFloat = 1.0
    static let ToolbarTextHeight: CGFloat = 12.0
    static let Release = "Release"
    static let ReleaseURL = k.caches + ":///asset/RELEASE"
    static let ReleaseNotes = "Release Notes"
    static let bingInfo = "Microsoft Bing Search"
    static let bingName = "Bing"
    static let bingLink = "https://search.bing.com/search?Q=%@"
    static let googleInfo = "Google Search"
    static let googleName = "Google"
    static let googleLink = "https://www.google.com/search?q=%@"
    static let yahooName = "Yahoo"
    static let yahooInfo = "Yahoo! Search"
    static let yahooLink = "https://search.yahoo.com/search?q=%@"
    static let searchInfos = [k.bingInfo, k.googleInfo, k.yahooInfo]
    static let searchNames = [k.bingName, k.googleName, k.yahooName]
    static let searchLinks = [k.bingLink, k.googleLink, k.yahooLink]
}

public struct Settings {
    internal class Setup<T> {
        private let key: String
        private var setting: T
        
        init(_ userDefaultsKey: String, value: T) {
            self.key = userDefaultsKey
            self.setting = value
        }
        
        var keyPath: String {
            get {
                return self.key
            }
        }
        var `default`: T {
            get {
                if let value = UserDefaults.standard.object(forKey: self.key) as? T {
                    return value
                } else {
                    // Sets existing setting if failed
                    return self.setting
                }
            }
        }
        var value: T {
            get {
                return self.setting
            }
            set (value) {
                self.setting = value
                //  Inform all interested parties for this panel's controller only only
                NotificationCenter.default.post(name: Notification.Name(rawValue: self.keyPath), object: nil)
            }
        }
    }
    
    let autoHideTitlePreference = Setup<HeliumController.AutoHideTitlePreference>("rawAutoHideTitle", value: .never)
    let floatAboveAllPreference = Setup<HeliumController.FloatAboveAllPreference>("rawFloatAboveAll", value: .spaces)
    let opacityPercentage = Setup<Int>("opacityPercentage", value: 60)
    let rank = Setup<Int>(k.rank, value: 0)
    let date = Setup<TimeInterval>(k.date, value: Date().timeIntervalSinceReferenceDate)
    let time = Setup<TimeInterval>(k.time, value: 0.0)
    let rect = Setup<NSRect>(k.rect, value: NSMakeRect(0, 0, 0, 0))
    let plays = Setup<Int>(k.plays, value: 0)
    let customUserAgent = Setup<String>("customUserAgent", value: UserSettings.UserAgent.value)
    
    // See values in HeliumController.TranslucencyPreference
    let translucencyPreference = Setup<HeliumController.TranslucencyPreference>("rawTranslucencyPreference", value: .never)
}

class KeyedArchiver : NSKeyedArchiver {
    open override class func archivedData(withRootObject rootObject: Any) -> Data {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: rootObject, requiringSecureCoding: true)
            return data
        }
        catch let error {
            Swift.print("KeyedArchiver: \(error.localizedDescription)")
            return Data.init()
        }
    }
    open override class func archiveRootObject(_ rootObject: Any, toFile path: String) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: rootObject, requiringSecureCoding: true)
            try data.write(to: URL.init(fileURLWithPath: path))
            return true
        }
        catch let error {
            Swift.print("KeyedArchiver: \(error.localizedDescription)")
            return false
        }
    }
}

class KeyedUnarchiver : NSKeyedUnarchiver {
    open override class func unarchiveObject(with data: Data) -> Any? {
        do {
			let unarchiver = try NSKeyedUnarchiver.init(forReadingFrom: data)
			unarchiver.requiresSecureCoding = false
			let object = unarchiver.decodeObject(of: [PlayList.self,PlayItem.self], forKey: NSKeyedArchiveRootObjectKey)
            return object
        }
        catch let error {
            Swift.print("unarchiveObject(with:) \(error.localizedDescription)")
            return nil
        }
    }

    open override class func unarchiveObject(withFile path: String) -> Any? {
        do {
            let data = try Data(contentsOf: URL.init(fileURLWithPath: path))
			let unarchiver = try NSKeyedUnarchiver.init(forReadingFrom: data)
			unarchiver.requiresSecureCoding = false
			let object = unarchiver.decodeObject(of: [PlayList.self,PlayItem.self], forKey: NSKeyedArchiveRootObjectKey)
            return object
        }
        catch let error {
            Swift.print("unarchiveObject(withFile:) \(error.localizedDescription)")
            return nil
        }
    }
	
    open class func unarchiveObject(withURL url: URL) -> Any? {
		return unarchiveObject(withFile: url.path)
	}
}

extension NSUserInterfaceItemIdentifier {
    static let name = NSUserInterfaceItemIdentifier(rawValue: "name")
    static let plays = NSUserInterfaceItemIdentifier(rawValue: "plays")
	static let turl = NSUserInterfaceItemIdentifier(rawValue: "turl")
}
