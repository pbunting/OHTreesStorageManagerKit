//
//  CoreDataStorageScheme.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

internal class CloudKitStorageScheme {
    
    private var storageObservers: [StorageSchemeListener]
    
    internal required init(objectFactory: XDataObjectFactory) {
        storageObservers = [StorageSchemeListener]()
    }
    
//    internal func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
//        return true
//    }
    
    internal func addObserver(observer: StorageSchemeListener) {
        
    }
    
    internal func addDataObject(object: XDataObject) {
        
    }
    
    internal func deleteDataObject(object: XDataObject) {
        
    }
    
//    internal func getAllDataObject() -> [XDataObject] {
//        
//    }

}

