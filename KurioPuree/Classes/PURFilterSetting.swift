//
//  PURFilterSetting.swift
//  Pods
//
//  Created by admin on 7/27/17.
//
//

import Foundation

class PURFilterSetting {
    private(set) var filterClass: Any?
    private(set) var tagPattern: String = ""
    private(set) var settings: [String: Any]?
    
    convenience init(filter filterClass: AnyClass, tagPattern: String) {
        self.init(filter: filterClass, tagPattern: tagPattern, settings: nil)
    }
    
    init(filter filterClass: AnyClass, tagPattern: String, settings: [String: Any]?) {
        self.filterClass = filterClass
        self.tagPattern = tagPattern
        self.settings = settings
    }
}
