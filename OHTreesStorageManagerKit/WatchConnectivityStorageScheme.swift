//
//  CoreDataStorageScheme.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

// internal class WatchConnectivityStorageScheme: StorageScheme {
internal class WatchConnectivityStorageScheme {
    
    private var storageObservers: [StorageSchemeListener]
    
    internal required init(objectFactory: XDataObjectFactory) {
        storageObservers = [StorageSchemeListener]()
    }

    internal func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        return true
    }
    
    internal func addObserver(observer: StorageSchemeListener) {
        
    }
    
    internal func addDataObject(object: XDataObject) {
        
    }
    
    internal func deleteDataObject(object: XDataObject) {
        
    }
    
    var runtimeCache: [XDataObject]?
    
    private func prepareRuntimeCache() {
        if runtimeCache == nil {
//            runtimeCache = initializeFromCoredata()
            shareAll(runtimeCache!, deletes: [XDataObject]())
        }
    }
    
    internal func getAllDataObject() -> [XDataObject] {
        prepareRuntimeCache()
        return runtimeCache!
    }

    private func shareAll(adds : [XDataObject], deletes : [XDataObject]) {
        NSLog("CoreDataStorageScheme.shareAll")
        storageObservers.forEach { (smo) -> () in
            smo.shareUpdates(adds, deletes: deletes)
        }
        
    }
    
    internal func shareUpdates(adds: [XDataObject], deletes: [XDataObject]) {
        NSLog("CoreDataStorageScheme.shareUpdates")
        adds.forEach { (xdo) -> () in
//            add(xdo)
        }
        deletes.forEach { (xdo) -> () in
//            delete(xdo)
        }
    }

}