//
//  CoreDataStorageScheme.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation
import CoreData


internal class CoreDataStorageScheme: StorageScheme {
    
    private var storageObservers: [StorageSchemeListener]
    
    var managedObjectContext: NSManagedObjectContext!
    
    let dataObjectFactory: XDataObjectFactory

    var managedObjectModel: NSManagedObjectModel!
    
    internal required init(config: StorageManagerConfig) {
        storageObservers = [StorageSchemeListener]()
        dataObjectFactory = config.objectFactory!
        
//        let a = NSBundle.mainBundle()
//        let custom = NSBundle(identifier: "com.100trees.OHTreesStorageManagerKitTests")
        
        var urls = [NSURL]()
        NSBundle.allBundles().forEach {
            if let u = $0.URLForResource(config.Core_Data_Model_File_Name, withExtension: "momd") {
                NSLog("Found the right bundle \($0.bundleIdentifier)")
                urls.append(u)
            }
        }
        managedObjectModel = NSManagedObjectModel(contentsOfURL: urls[0])!
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        let failureReason = "There was an error creating or loading the application's saved data."
        do {
            if let _ = config.options["CoreDataInMemory"] {
                try coordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
            } else {
                try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
            }
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        

        
        self.persistentStoreCoordinator = coordinator
        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
    }

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.100trees.DrinkUp" in the application's documents Application Support directory.
        NSLog("AppDelegate.applicationDocumentsDirectory")
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
    // Create the coordinator and store
    var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    

    
    internal func addObserver(obs: StorageSchemeListener) {
        // ToDo: Look out this is not checking for duplicates
        storageObservers.append(obs)
    }
    
    private func initializeFromCoredata() -> [XDataObject] {
        NSLog("CoreDataStorageManager.initializeFromCoredata")
        var results = [XDataObject]()
        
        self.dataObjectFactory.entityNames.forEach {
            let fetchRequest = NSFetchRequest(entityName: $0.uppercaseString)
            do {
                let response =
                try self.managedObjectContext.executeFetchRequest(fetchRequest)
                for r in response {
                    let mo = r as! NSManagedObject
                    let moE = mo.entity
                    var moD = [String: AnyObject]()
                    moE.attributesByName.keys.forEach({ (k) -> () in
                        moD[k] = mo.valueForKey(k)
                    })
                    let newXDataObject = self.dataObjectFactory.fromDictionary(moD)
                    NSLog("CoreData providing data object \(newXDataObject.key)")
                    results.append(newXDataObject)
                }
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
                //            return nil
            }
        }
        return results
    }

    var runtimeCache: [XDataObject]?

    private func prepareRuntimeCache() {
        if runtimeCache == nil {
            runtimeCache = initializeFromCoredata()
            shareAll(runtimeCache!, deletes: [XDataObject]())
        }
    }
    
    internal func getAllDataObject() -> [XDataObject] {
        prepareRuntimeCache()
        return runtimeCache!
    }

    internal func addDataObject(object: XDataObject) {
        NSLog("CoreDataStorageManager.addDataObject")
        if add(object) {
            // Now share with any other observers
            shareAll([object], deletes: [XDataObject]())
        }
    }
    
    internal func deleteDataObject(object: XDataObject) {
        NSLog("CoreDataStorageManager.deleteDataObject")
        if delete(object) {
            // Now share with any other observers
            shareAll([XDataObject](), deletes: [object])
        }
    }

    
    // Inner workings
    private func isNew(obj : XDataObject) -> Bool {
        let o = obj as! XDataObject
        prepareRuntimeCache()
//        let match = runtimeCache?.filter({$0.key == obj.key})
        let match = runtimeCache?.filter({$0.key == o.key})
        let result = match!.count == 0
        NSLog("CoreDataStorageScheme.isNew=\(result)")
        return result
    }

    private func add(obj : XDataObject) -> Bool {
        var added = false
        NSLog("CoreDataStorageScheme.add")
        prepareRuntimeCache()
        if isNew(obj) {
            
            // Store the obj
            let objAsDict = obj.asDictionary()
            let entity = NSEntityDescription.entityForName(obj.objectName.uppercaseString,
                inManagedObjectContext:managedObjectContext)

            let objManagedObject = NSManagedObject(entity: entity!, insertIntoManagedObjectContext: self.managedObjectContext)
            
            objAsDict.forEach { (k,v) -> () in
                objManagedObject.setValue(v, forKey: k)
            }
            do {
                try self.managedObjectContext.save()
                added = true
            } catch let error as NSError {
                print("Could not save \(error), \(error.userInfo)")
            }
            runtimeCache?.append(obj)
        }
        return added
    }
    
    private func delete(obj : XDataObject) -> Bool {
        var deleted = false
        NSLog("CoreDataStorageScheme.delete")
        if !isNew(obj) {
            
            runtimeCache = runtimeCache?.filter({$0.key != obj.key})
            
            let fetchRequest = NSFetchRequest(entityName: obj.objectName.uppercaseString)
            let targetKey = obj.key
            fetchRequest.predicate = NSPredicate(format: "key == %@", targetKey)
            
            do {
                let managedObjects = try self.managedObjectContext.executeFetchRequest(fetchRequest) as! [NSManagedObject]
                managedObjects.forEach {
                    self.managedObjectContext.deleteObject($0)
                }
                do {
                    try self.managedObjectContext.save()
                    deleted = true
                } catch let error as NSError {
                    print("Could not save \(error), \(error.userInfo)")
                }
            } catch {
                fatalError("Failed to fetch object: \(error)")
            }
        }
        return deleted
    }

    private func shareAll(adds : [XDataObject], deletes : [XDataObject]) {
        NSLog("CoreDataStorageScheme.shareAll")
        storageObservers.forEach { (smo) -> () in
            smo.shareUpdates(self, adds: adds, deletes: deletes)
        }
        
    }

    internal func shareUpdates(adds: [XDataObject], deletes: [XDataObject]) {
        NSLog("CoreDataStorageScheme.shareUpdates")
        adds.forEach { (xdo) -> () in
            add(xdo)
        }
        deletes.forEach { (xdo) -> () in
            delete(xdo)
        }
    }


}

