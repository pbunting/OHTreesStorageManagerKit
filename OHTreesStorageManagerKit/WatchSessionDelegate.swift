//
//  WatchSessionDelegate.swift
//  PhoneWatchPair
//
//  Created by Paul Bunting on 2/27/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation
import WatchConnectivity

class WatchSessionDelegate : NSObject, WCSessionDelegate {
    
    private var dataObjectFactory: XDataObjectFactory!
    private var storageManager: StorageManager!
    
    init(factory: XDataObjectFactory, manager: StorageManager) {
        dataObjectFactory = factory
        storageManager = manager
    }
    
    private func contains(dataObjects : [XDataObject], key: String) -> Bool {
        let defaultResult = false
        for n in dataObjects {
            if n.key == key {
                return true
            }
        }
        return defaultResult
    }
    
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        //
        NSLog("WatchSessionDelegate didReceiveApplicationContext \(applicationContext)")
//        let knownObjects = DataManager.instance.localStorage?.getAllDataObject()
//        NSLog("new applicationContext: \(applicationContext)")
//        NSLog("known objects: \(knownObjects)")
        var tstamp: String
        if let timestamp = applicationContext["Timestamp"] as? String {
            tstamp = timestamp
        } else {
            tstamp = "Unknown"
        }
        NSLog("WatchSessionDelegate received update tagged \(tstamp)")
        guard let objectDicts = applicationContext["Objects"] as? [[String : AnyObject]]
            else {
                return
        }
        let update = objectDicts.flatMap { dataObjectFactory.fromDictionary($0) }
        let currentObjects = storageManager.get()
        
        currentObjects.filter({ !contains(update, key: $0.key) }).forEach {
            NSLog("context update causing \($0.key) to be deleted")
            storageManager.delete($0)
        }
        
        update.forEach {
            NSLog("...\($0) \($0.key)")
            storageManager.add($0)
        }
        
    }
}