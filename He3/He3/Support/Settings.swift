//
//  Settings.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/9/20.
//  Copyright © 2020-2021 Carlos D. Santiago. All rights reserved.
//

import Foundation
import Cocoa

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
    
    let autoHideTitlePreference = Setup<HeliumController.AutoHideTitlePreference>("rawAutoHideTitle", value: .outside)
    let floatAboveAllPreference = Setup<HeliumController.FloatAboveAllPreference>("rawFloatAboveAll", value: .allSpace)
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
