//
//  CoreDataStorageScheme.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation
import WatchConnectivity

internal class WatchConnectivityStorageScheme: StorageScheme {
    
    private var storageObservers: [StorageSchemeListener]
    
    let dataObjectFactory: XDataObjectFactory
    
    let watchSession: () -> WatchConnectingSession?
    
    internal required init(config: StorageManagerConfig) {
        storageObservers = [StorageSchemeListener]()
        dataObjectFactory = config.objectFactory!
        watchSession = config.wcSession
    }

    internal func addObserver(observer: StorageSchemeListener) {
        // ToDo: Look out this is not checking for duplicates
        storageObservers.append(observer)
    }
    
    internal func addDataObject(object: XDataObject) {
        NSLog("WatchConnectivityStorageManager.addDataObject")
        if add(object) {
            // Now share with any other observers
            shareAll([object], deletes: [XDataObject]())
        }
    }
    
    internal func deleteDataObject(object: XDataObject) {
        NSLog("WatchConnectivityStorageManager.deleteDataObject")
        if delete(object) {
            // Now share with any other observers
            shareAll([XDataObject](), deletes: [object])
        }
    }
    
    var runtimeCache: [XDataObject]?
    
    private func initializeFromWatchKit() -> [XDataObject] {
        NSLog("WatchStorageManager.initializeFromWatchKit")
        guard let objectDicts = watchSession()!.receivedApplicationContext["Objects"] as? [[String : AnyObject]]
            else {
                return []
        }
        let timestamp = WCSession.defaultSession().receivedApplicationContext["timestamp"]
        NSLog("Rx ApplicationContext [@\(timestamp)] \(objectDicts))")
        return objectDicts.flatMap {
            self.dataObjectFactory.fromDictionary($0)
        }
    }

    
    private func prepareRuntimeCache() {
        if runtimeCache == nil {
            runtimeCache = initializeFromWatchKit()
            shareAll(runtimeCache!, deletes: [XDataObject]())
        }
    }
    
    private func isNew(obj : XDataObject) -> Bool {
        //        let o = obj as! XDataObject
        prepareRuntimeCache()
        let match = runtimeCache?.filter({$0.key == obj.key})
        let result = match!.count == 0
        NSLog("WatchConnectivityStorageManager.isNew=\(result)")
        return result
    }

    internal func getAllDataObject() -> [XDataObject] {
        prepareRuntimeCache()
        return runtimeCache!
    }

    private func shareAll(adds : [XDataObject], deletes : [XDataObject]) {
        NSLog("WatchConnectivityStorageManager.shareAll")
        storageObservers.forEach { (smo) -> () in
            smo.shareUpdates(self, adds: adds, deletes: deletes)
        }
    }
    
    
    internal func add(obj : XDataObject) -> Bool {
        NSLog("WatchStorageManager add")
        // Communicate this change with the iOS app
        if isNew(obj) {
            runtimeCache!.append(obj)
            let objectDicts : [[String : AnyObject]] = runtimeCache!.map{
                $0.asDictionary()
            }
            do {
                let timestamp = NSDate()
                let newContext = ["Objects" : objectDicts, "Timestamp" : "\(timestamp)"]
                NSLog("Tx ApplicationContext \(objectDicts)) tagged \(timestamp)")
                try WCSession.defaultSession().updateApplicationContext(newContext as! [String : AnyObject])
            } catch let error {
                NSLog("Error saving XDataObjects to application context: \(error)")
            }
            return true
        } else {
            return false
        }
    }
    
    internal func delete(obj : XDataObject) -> Bool {
        // Communicate this change with the iOS app
        //        let dataObjects = getAllDataObject()
        NSLog("WatchStorageManager.delete")
        
        if !isNew(obj) {
            runtimeCache = runtimeCache!.filter { (d) -> Bool in
                d.key != obj.key
            }
            let objectDicts : [[String : AnyObject]] = runtimeCache!.map{
                $0.asDictionary()
            }
            do {
                let timestamp = NSDate()
                let newContext = ["Objects" : objectDicts, "Timestamp" : "\(timestamp)"]
                NSLog("Tx ApplicationContext \(objectDicts)) tagged \(timestamp)")
                try WCSession.defaultSession().updateApplicationContext(newContext as! [String : AnyObject])
            } catch let error {
                NSLog("Error saving XDataObjects to application context: \(error)")
            }
            return true
        } else {
            return false
        }
    }
    
}