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

    internal required init(config: StorageManagerConfig) {
        storageObservers = [StorageSchemeListener]()
        dataObjectFactory = config.objectFactory!

        let myContainer = CKContainer.defaultContainer()
        self.privateDatabase = myContainer.privateCloudDatabase

    }
    
    internal func addObserver(observer: StorageSchemeListener) {
        // ToDo: Look out this is not checking for duplicates
        storageObservers.append(observer)
    }
    
    var runtimeCache: [XDataObject]?
    
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
    
    private func initializeFromCloudKit() -> [XDataObject] {
        
        var objects = [XDataObject]()
        
        self.dataObjectFactory.entityNames.forEach {
            let pred = NSPredicate()
            let query = CKQuery(recordType: $0,
                predicate:  pred)
            subscribeToUpdates($0, predicate: pred)
            
            self.privateDatabase.performQuery(query, inZoneWithID: nil) { (records, error) -> Void in
                if let e = error {
                    self.lostTrackHandler(e)
                } else {
                    if let recs = records {
                        for r in recs {
                            objects.append(self.dataObjectFactory.fromDictionary(self.recordToDictionary(r)))
                        }
                    }
                }
            }
        }
        return objects
    }
    
    private func prepareRuntimeCache() {
        if runtimeCache == nil {
            runtimeCache = initializeFromCloudKit()
            shareAll(runtimeCache!, deletes: nil)
        }
    }
    
    private func isNew(obj : XDataObject) -> Bool {
        //        let o = obj as! XDataObject
        prepareRuntimeCache()
        let match = runtimeCache?.filter({$0.key == obj.key})
        let result = match!.count == 0
        NSLog("CloudKitStorageManager.isNew=\(result)")
        return result
    }

    private func add(obj: XDataObject, onCompletion:(updated: Bool, error: NSError?, updates: [XDataObject]?, deletes: [XDataObject]?) -> Void) -> Void {

        NSLog("CloudKitStorageManager.add")
        
        if isNew(obj) {
    
            let updates = [obj]
            
            runtimeCache!.append(obj)
//            do {
                var records = [CKRecord]()
                // Create a drink cloudkit record
                let objectRecord = CKRecord(recordType: obj.objectName)
                objectRecord.setValuesForKeysWithDictionary(obj.asDictionary())
                
                records.append(objectRecord)
                
                let x = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
                x.modifyRecordsCompletionBlock = { (records:[CKRecord]?, deletedRecordIDs:[CKRecordID]?, e:NSError?) -> Void in
                    onCompletion(updated: true, error: e, updates: updates, deletes:nil)
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
    
    internal func addDataObject(object: XDataObject) {
        NSLog("CloudKitStorageManager.addDataObject")
        add(object, onCompletion:{
            (act: Bool, e: NSError?, u: [XDataObject]?, d: [XDataObject]?) -> Void in
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
        })
    }
    
    private func shareAll(adds : [XDataObject]?, deletes : [XDataObject]?) {
        NSLog("CloudKitStorageManager.shareAll")
        storageObservers.forEach { (smo) -> () in
            smo.shareUpdates(self, adds: adds, deletes: deletes)
        }
    }

    internal func deleteDataObject(object: XDataObject) {
        NSLog("CloudKitStorageManager.deleteDataObject")
        if delete(object) {
            // Now share with any other observers
            shareAll(nil, deletes: [object])
        }
    }
    
    internal func getAllDataObject() -> [XDataObject] {
        prepareRuntimeCache()
        return runtimeCache!
    }
    
    
    
//    private func saveDrinks(newDrinks: [Drink]?, onCompletion:(r:[CKRecord]?, e: NSError?) -> Void ) -> Void {
//        var records = [CKRecord]()
//        if let drinks = newDrinks {
//            for d in drinks {
//                // Create a drink cloudkit record
//                let drinkRecord = CKRecord(recordType: "drink")
//                drinkRecord.setObject(d.volume.size, forKey: sizeKey)
//                drinkRecord.setObject(d.volume.units.rawValue, forKey: unitsKey)
//                drinkRecord.setObject(d.timestamp, forKey: timestampKey)
//                records.append(drinkRecord)
//            }
//        }
//        
//        let x = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
//        x.modifyRecordsCompletionBlock = { (records:[CKRecord]?, deletedRecordIDs:[CKRecordID]?, e:NSError?) -> Void in
//            onCompletion(r: records, e:e)
//        }
//        x.queuePriority = NSOperationQueuePriority.VeryHigh
//        self.privateDatabase.addOperation(x)
//        
//    }

    internal func delete(obj: XDataObject) ->  Bool {
        return false
    }
    
    internal func add(obj: XDataObject) -> Bool {

                
//                self.saveDrinks([d], )

                
//                try WCSession.defaultSession().updateApplicationContext(newContext as! [String : AnyObject])

//        
//        if let currentDrinks = self.getTodays() {
//            var updatedDrinks = [Drink]()
//            updatedDrinks.appendContentsOf(currentDrinks)
//            updatedDrinks.append(d)
//            
//            let derivedTarget: Volume!
//            if (target != nil) {
//                derivedTarget = target
//            } else {
//                derivedTarget = sumDrinkVolumes(updatedDrinks)
//            }
//            
//            if archive {
//                if let interestedDelegate = self.delegate {
//                    interestedDelegate.willUpdateDrinks(updatedDrinks, target: derivedTarget)
//                }
//                
//                self.saveDrinks([d], onCompletion: { (r, e) -> Void in
//                    if let error = e {
//                        NSLog("Error \(error.localizedDescription) recording drink")
//                    } else {
//                        NSLog("Recorded drink at \(d.timestamp)")
//                    }
//                    if let interestedDelegate = self.delegate {
//                        dispatch_async(dispatch_get_main_queue()) {
//                            interestedDelegate.didUpdateDrinks(e, update: updatedDrinks, target: derivedTarget)
//                        }
//                    }
//                })
//            }
//            
//        } else {
//            if let interestedDelegate = self.delegate {
//                interestedDelegate.haveLostTrack(NSError(domain: "com.100trees.", code: 2, userInfo: nil))
//            }
//        }
//    }
        return true // fail safe, dont stop this object propagating to other storage schemes
    }

}


