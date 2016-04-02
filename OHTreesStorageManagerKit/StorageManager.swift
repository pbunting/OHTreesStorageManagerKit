//
//  StorageManager.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

public struct StorageManagerConfig {

    var Core_Data_Model_File_Name: String = "XDataObjectModel"
    
    var types: [StorageType] = [StorageType]()
    
    var preferredType: StorageType?
    
    var objectFactory: XDataObjectFactory?

    var options : [String: AnyObject] = [String: AnyObject]()
}


public class StorageManager : StorageSchemeListener{

    private var config: StorageManagerConfig!
    
    private static var singleton_: StorageManager?
    
    internal static func reset() {
        singleton_ = nil
    }
    
    public class func configure(config: StorageManagerConfig) throws -> StorageManager {
        if let _ = singleton_ {
            throw StorageManagerErrorType.AlreadyInitialized
        }
        try singleton_ = StorageManager(config: config)
        return singleton_!
    }
    
    public static var instance: StorageManager? {
        get {
            NSLog("StorageManager.instance.get")
            return singleton_
        }
    }
    
    public func add(obj: XDataObject) {
        preferredStorageScheme.addDataObject(obj)
    }
    
    public func delete(obj: XDataObject) {
        preferredStorageScheme.deleteDataObject(obj)
    }
    
    public func get() -> [XDataObject] {
        return preferredStorageScheme.getAllDataObject()
    }
    
    private var preferredStorageScheme: StorageScheme!
    private var storageSchemes: [StorageScheme]!
    
    private init(config: StorageManagerConfig) throws {
        if config.types.count > 0 && config.objectFactory == nil {
            throw StorageManagerErrorType.MissingObjectFactory
        }
        var preferredTypeChosen: StorageType
        if config.preferredType == nil && config.types.count > 0 {
            preferredTypeChosen = config.types[0]
        } else if (config.preferredType == nil) {
            throw StorageManagerErrorType.MissingPreferredStorageType
        } else {
            preferredTypeChosen = config.preferredType!
        }
        storageSchemes = [StorageScheme]()
        config.types.forEach {
            var scheme: StorageScheme
            switch $0 {
//            case .CoreData:
//                scheme = CoreDataStorageScheme(objectFactory: StorageManager.objectFactory!)
//            case .CloudKit:
//                scheme = CloudKitStorageScheme(objectFactory: StorageManager.objectFactory!)
            default: // WatchConnectivity
//                scheme = WatchConnectivityStorageScheme(objectFactory: StorageManager.objectFactory!)
                scheme = CoreDataStorageScheme(config: config)
            }
            if $0 == preferredTypeChosen {
                preferredStorageScheme = scheme
            }
            scheme.addObserver(self)
            storageSchemes.append(scheme)
        }
    }
    
    func shareUpdates(source: StorageScheme, adds: [XDataObject], deletes: [XDataObject]) {
        storageSchemes.filter({ ($0 as! AnyObject) !== (source as! AnyObject) })
            .forEach {
                let ss = $0
                adds.forEach { ss.addDataObject($0) }
                deletes.forEach { ss.deleteDataObject($0) }
            }
    }
}


public enum StorageManagerErrorType: ErrorType {
    case MissingObjectFactory
    case AlreadyInitialized
    case MissingPreferredStorageType
}

public enum StorageType {
    case CoreData, CloudKit, WatchConnectivity
}