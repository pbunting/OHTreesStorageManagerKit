//
//  XDataObject.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

public protocol XDataObjectFactory {
    
    var entityNames: [String] {
        get
    }

    func fromDictionary(dict: [String: AnyObject]) -> XDataObject
}

public protocol XDataObject {
    
    var key: String { get }
    
    var objectName : String { get }
    
    func asDictionary() -> [String: AnyObject]
    
}
