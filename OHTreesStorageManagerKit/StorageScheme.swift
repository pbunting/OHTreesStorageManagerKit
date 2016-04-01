//
//  StorageSchemeProtocol.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

internal protocol StorageSchemeListener {
    
    func shareUpdates(adds: [XDataObject], deletes: [XDataObject])
    
}

internal protocol StorageScheme {
    
    init(config: StorageManagerConfig)
    
    mutating func addObserver(observer: StorageSchemeListener)
    
    func addDataObject(object: XDataObject)
    
    func deleteDataObject(object: XDataObject)
    
    func getAllDataObject() -> [XDataObject]


}