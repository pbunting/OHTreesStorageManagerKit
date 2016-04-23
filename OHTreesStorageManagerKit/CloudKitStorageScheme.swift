//
//  CoreDataStorageScheme.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation
import CloudKit


internal class CloudKitStorageScheme: StorageScheme {
    
    private var storageObservers: [StorageSchemeListener]
    
    let dataObjectFactory: XDataObjectFactory

    let privateDatabase: CKDatabase!
    
    private var cloudAvailable: Bool = false
    
    private var application: UIApplication?

    var runtimeCache: [XDataObject]?

    internal required init(config: StorageManagerConfig) {
        storageObservers = [StorageSchemeListener]()
        dataObjectFactory = config.objectFactory!

        let myContainer = config.ckConnector()
        self.privateDatabase = myContainer!.privateCloudDatabase
        
        runtimeCache = initializeFromCloudKit()
    }
 
    internal func addObserver(observer: StorageSchemeListener) {
        // ToDo: Look out this is not checking for duplicates
        storageObservers.append(observer)
    }
    
    private func lostTrackHandler(subs: CKSubscription?, err: NSError?) -> Void {
        if let error = err {
            // TODO might not have to track duplicate subscription error
            //            if let interestedDelegate = self.delegate {
            //                interestedDelegate.haveLostTrack(error)
            //            }
            NSLog("Error tracking iCloud records \(error.localizedDescription)")
        }
    }
    
    private func lostTrackHandler(err: NSError) -> Void {
        // TODO might not have to track duplicate subscription error
        //            if let interestedDelegate = self.delegate {
        //                interestedDelegate.haveLostTrack(error)
        //            }
        NSLog("Error tracking iCloud records \(err.localizedDescription)")
    }
    
    private func subscribeToUpdates(recordTypeName: String, predicate: NSPredicate) -> Void {
        
        let subs = CKSubscription(recordType: recordTypeName,
            predicate: predicate,
            options: CKSubscriptionOptions.FiresOnRecordCreation)
        self.privateDatabase.saveSubscription(subs, completionHandler: lostTrackHandler)
    }
    
    private func recordToDictionary(record: CKRecord) -> [String: AnyObject] {
        var dict = [String: AnyObject]()
        record.allKeys().forEach {
            dict[$0] = record.objectForKey($0)
        }
        return dict
    }
    
    private func fetchObjects(entityName: String) -> Void {
        let query = CKQuery(recordType: entityName, predicate: NSPredicate(value: true))
        self.privateDatabase.performQuery(query, inZoneWithID: nil) { (records, error) -> Void in
            if let e = error {
                self.lostTrackHandler(e)
            } else {
                if let recs = records {
                    let newEntities = recs.map( { r in
                        self.dataObjectFactory.fromDictionary(self.recordToDictionary(r))
                    } )
                    newEntities.forEach( { self.add($0, onCompletion: nil) } )
//                        self.add(obj: ,
//                            onCompletion: { (updated: Bool, error: NSError?, updates: [XDataObject]?, deletes: [XDataObject]?) -> Void in
//                            }
//                        )
//                    }
                    self.shareAll(newEntities, deletes: nil)

                }
            }
        }
    }
    
    private func initializeFromCloudKit() -> [XDataObject] {
        
        let entityNames = self.dataObjectFactory.entityNames
        
        self.privateDatabase.fetchAllSubscriptionsWithCompletionHandler({ (subs, error) -> Void in
            if let e = error {
                self.lostTrackHandler(e)
            } else {
                if let s = subs {
                    // Find the Entities that are already subscribed to
                    let entitiesAlreadySubscribed = s.map( {sbscrptn in sbscrptn.recordType!} )
                    // Determine which Entities are not subscribed to yet
                    let entitiesNeedSubscriptions = entityNames.filter( { !entitiesAlreadySubscribed.contains($0) } )
                    // Subscribe to them
                    entitiesNeedSubscriptions.forEach {
                        let subs = CKSubscription(recordType: $0, predicate: NSPredicate(value: true), options: CKSubscriptionOptions.FiresOnRecordCreation)
                        self.privateDatabase.saveSubscription(subs, completionHandler: { (subscription, errr) -> Void in
                            if let sbscpt = subscription {
                                self.fetchObjects(sbscpt.recordType!)
                            }})
                    }
                }
            }
        })
        return [XDataObject]()
//        self.dataObjectFactory.entityNames.forEach {
//            
//            //
//            let pred: NSPredicate = NSPredicate(value: true)
//            let query = CKQuery(recordType: $0,
//                predicate:  pred)
//            subscribeToUpdates($0, predicate: pred)
//            
//            self.privateDatabase.performQuery(query, inZoneWithID: nil) { (records, error) -> Void in
//                if let e = error {
//                    self.lostTrackHandler(e)
//                } else {
//                    if let recs = records {
//                        for r in recs {
//                            objects.append(self.dataObjectFactory.fromDictionary(self.recordToDictionary(r)))
//                        }
//                    }
//                }
//            }
//        }
//        return objects
    }
    
    
    private func isNew(obj : XDataObject) -> Bool {
        //        let o = obj as! XDataObject
//        prepareRuntimeCache()
        let match = runtimeCache?.filter({$0.key == obj.key})
        let result = match!.count == 0
        NSLog("CloudKitStorageManager.isNew=\(result)")
        return result
    }

    private func delete(obj: XDataObject, onCompletion:(updated: Bool, error: NSError?, updates: [XDataObject]?, deletes: [XDataObject]?) -> Void) -> Void {
        
        NSLog("CloudKitStorageManager.delete")
        if !isNew(obj) {
            runtimeCache = runtimeCache!.filter { (d) -> Bool in
                d.key != obj.key
            }
            
//            let pred: NSPredicate = NSPredicate(block: { o, map -> Bool in
//                return map![o.key!!] != nil
//            })
            let pred: NSPredicate = NSPredicate(value: true)
            let query = CKQuery(recordType: obj.objectName,
                predicate:  pred)
            self.privateDatabase.performQuery(query, inZoneWithID: nil) { (records, error) -> Void in
                if let e = error {
                    self.lostTrackHandler(e)
                } else {
                    if let recs = records {
                        for r in recs {
                            self.privateDatabase.deleteRecordWithID(r.recordID, completionHandler: { (id, err) -> Void in
                                onCompletion(updated: true, error: err, updates: nil, deletes: [obj])
                            })
                        }
                    }
                }
            }
        }
    }
    
    private func add(obj: XDataObject, onCompletion:((updated: Bool, error: NSError?, updates: [XDataObject]?, deletes: [XDataObject]?) -> Void)?) -> Void {

        NSLog("CloudKitStorageManager.add")
        
        if isNew(obj) {
    
            let updates = [obj]
            
            runtimeCache!.append(obj)
//            do {
                var records = [CKRecord]()
                // Create a drink cloudkit record
//            let objectRecord = CKRecord(recordType: obj.objectName, recordID: CKRecordID(recordName: obj.key))
//                objectRecord.setValuesForKeysWithDictionary(obj.asDictionary())
            let objectRecord = CKRecord(recordType: obj.objectName)
            objectRecord.setValuesForKeysWithDictionary(obj.asDictionary())
            
                records.append(objectRecord)
                
                let x = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
                x.modifyRecordsCompletionBlock = { (records:[CKRecord]?, deletedRecordIDs:[CKRecordID]?, e:NSError?) -> Void in
                    if let handler = onCompletion {
                        handler(updated: true, error: e, updates: updates, deletes:nil)
                    }
                }
                x.queuePriority = NSOperationQueuePriority.VeryHigh
                self.privateDatabase.addOperation(x)
                
//            } catch let error {
//                NSLog("Error saving XDataObjects to application context: \(error)")
//            }
//            return true
//        } else {
//            return false
//        }
        }
    }
    
    private func completionHandler(act: Bool, e: NSError?, u: [XDataObject]?, d: [XDataObject]?) -> Void {
        if act {
            if let err = e {
                dispatch_async(dispatch_get_main_queue()) {
                    self.lostTrackHandler(err)
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.shareAll(u, deletes: d)
                }
            }
        }
    }
    
    internal func addDataObject(object: XDataObject) {
        NSLog("CloudKitStorageManager.addDataObject")
        add(object, onCompletion: completionHandler)
//        add(object, onCompletion:{
//            (act: Bool, e: NSError?, u: [XDataObject]?, d: [XDataObject]?) -> Void in
//            if act {
//                if let err = e {
//                    dispatch_async(dispatch_get_main_queue()) {
//                        self.lostTrackHandler(err)
//                    }
//                } else {
//                    dispatch_async(dispatch_get_main_queue()) {
//                        self.shareAll(u, deletes: d)
//                    }
//                }
//            }
//        })
    }
    
    private func shareAll(adds : [XDataObject]?, deletes : [XDataObject]?) {
        NSLog("CloudKitStorageManager.shareAll")
        storageObservers.forEach { (smo) -> () in
            smo.shareUpdates(self, adds: adds, deletes: deletes)
        }
    }

    internal func deleteDataObject(object: XDataObject) {
        NSLog("CloudKitStorageManager.deleteDataObject")
        delete(object, onCompletion: completionHandler)
//        delete(object, onCompletion:{
//            (act: Bool, e: NSError?, u: [XDataObject]?, d: [XDataObject]?) -> Void in
//            if act {
//                if let err = e {
//                    dispatch_async(dispatch_get_main_queue()) {
//                        self.lostTrackHandler(err)
//                    }
//                } else {
//                    dispatch_async(dispatch_get_main_queue()) {
//                        self.shareAll(u, deletes: d)
//                    }
//                }
//            }
//        })

        if delete(object) {
            // Now share with any other observers
            shareAll(nil, deletes: [object])
        }
    }
    
    internal func getAllDataObject() -> [XDataObject] {
//        prepareRuntimeCache()
        return runtimeCache!
    }
    
    internal func delete(obj: XDataObject) ->  Bool {
        return true // fail safe, dont stop this object propagating to other storage schemes
    }
    
    internal func add(obj: XDataObject) -> Bool {
        return true // fail safe, dont stop this object propagating to other storage schemes
    }

}


