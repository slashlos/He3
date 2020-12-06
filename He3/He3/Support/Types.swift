//
//  Types.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/9/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
import Cocoa

//  Global static strings

public struct k {
	static let kUTHe3PlayList = "com.slashlos.he3.hpl"
	static let kUTHe3PlayItem = "com.slashlos.he3.hpi"
	static let kUThe3PlayIcnt = "com.slashlos.he3.hic"
	
	static let kUTHe3Play3ist = "com.slashlos.he3.h3l"
	static let kUTHe3Play3tem = "com.slashlos.he3.h3i"
	static let KUTHe3play3cnt = "com.slashlos.he3.h3c"
	
	static let AppName = "He3"
	static let AppLogo = "Above all else"
    static let Helium = "Helium"
    static let Incognito = "Incognito"
    static let scheme = "he3"
    static let caches = "he3-local" /// cache string
    static let oauth2 = "he3-oauth" /// oauth handler
    static let he3 = "he3"
    static let asset = "asset"
	static let blank = "about://blank"
	static let file = "file"
    static let html = "html"
	static let https = "https"
	static let http = "http"
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
	static let WebArchive = "WebArchive"
	static let webarchive = "webarchive"
	static let h3i = "h3i"
	static let h3l = "h3l"
	static let h3c = "h3c"
    static let hpi = "hpi"
    static let hpl = "hpl"
	static let hic = "hic"
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
	static let PrivacyURL = k.caches + ":///asset/he3_privacy.rtf"
    static let Release = "Release"
    static let ReleaseURL = k.caches + ":///asset/RELEASE.html"
    static let ReleaseNotes = "Release Notes"
    static let bingInfo = "Microsoft Bing Search"
    static let bingName = "Bing"
    static let bingLink = "https://search.bing.com/search?Q=%@"
	static let ddgoInfo = "Duck Duck Go"
	static let ddgoName = "DuckDuckGo"
	static let ddgoLink = "https://duckduckgo.com/?q=%@"
    static let googleInfo = "Google Search"
    static let googleName = "Google"
    static let googleLink = "https://www.google.com/search?q=%@"
    static let yahooName = "Yahoo"
    static let yahooInfo = "Yahoo! Search"
    static let yahooLink = "https://search.yahoo.com/search?q=%@"
	static let searchInfos = [k.bingInfo, k.ddgoInfo, k.googleInfo, k.yahooInfo]
	static let searchNames = [k.bingName, k.ddgoName, k.googleName, k.yahooName]
	static let searchLinks = [k.bingLink, k.ddgoLink, k.googleLink, k.yahooLink]
}

extension NSUserInterfaceItemIdentifier {
    static let name = NSUserInterfaceItemIdentifier(rawValue: "name")
    static let plays = NSUserInterfaceItemIdentifier(rawValue: "plays")
	static let turl = NSUserInterfaceItemIdentifier(rawValue: "turl")
}
