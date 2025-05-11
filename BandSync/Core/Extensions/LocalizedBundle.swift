//
//  LocalizedBundle.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  Bundle+Language.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

private var bundleKey: UInt8 = 0

final class LocalizedBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }

        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        defer { object_setClass(Bundle.main, LocalizedBundle.self) }

        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            objc_setAssociatedObject(Bundle.main, &bundleKey, langBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
