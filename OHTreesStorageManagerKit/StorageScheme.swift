//
//  StorageSchemeProtocol.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

internal protocol StorageSchemeListener {
    
    func shareUpdates(source: StorageScheme, adds: [XDataObject]?, deletes: [XDataObject]?)
    
}

internal protocol StorageScheme : StorageSchemeListener {
    
    init(config: StorageManagerConfig)
    
    mutating func addObserver(observer: StorageSchemeListener)
    
    func addDataObject(object: XDataObject)
    
    func deleteDataObject(object: XDataObject)
    
    func getAllDataObject() -> [XDataObject]

    func add(obj : XDataObject) -> Bool
    func delete(obj : XDataObject) -> Bool

}

internal func == (lhs: StorageScheme, rhs: StorageScheme) {
    return lhs == rhs
}

internal extension StorageScheme {

    internal func shareUpdates(source: StorageScheme, adds: [XDataObject]?, deletes: [XDataObject]?) {
        NSLog("StorageScheme.shareUpdates \(StorageScheme.self)")
        if let a = adds {
            a.forEach { (xdo) -> () in
                add(xdo)
            }
        }
        if let d = deletes {
            d.forEach { (xdo) -> () in
                delete(xdo)
            }
        }
    }

}