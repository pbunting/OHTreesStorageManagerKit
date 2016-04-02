//
//  DataManagerTest.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/19/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Quick
import Nimble
@testable import OHTreesStorageManagerKit

class TestObject : XDataObject {
    
    var key: String = "TestObject:Key"
    
    var objectName : String = "TestObject"
    
    func asDictionary() -> [String: AnyObject] {
        return ["key" : key]
    }

}

class AnotherTestObject : XDataObject {
    
    var key: String = "AnotherTestObject:Key"
    
    var objectName : String = "AnotherTestObject"
    
    func asDictionary() -> [String: AnyObject] {
        return ["key" : key]
    }
    
}

class TestObjectFactory : XDataObjectFactory {

    var entityNames: [String] = [String]()
    
    internal init() {
        entityNames.append("TestObject")
    }
    
    func fromDictionary(dict: [String: AnyObject]) -> XDataObject {
        if let key = dict["key"] {
            let s = key as! String
            let keyComponents = s.characters.split{$0 == ":"}.map(String.init)
            switch keyComponents[0] {
            case "AnotherTestObject":
                return AnotherTestObject()
            default:
                return TestObject()
            }
        }
        
        return TestObject()
    }
}

class TestObserver: StorageSchemeListener {
    
    internal var log : [String] = [String]()
    
    func shareUpdates(scheme: StorageScheme, adds: [XDataObject], deletes: [XDataObject]) {
        adds.forEach {
            log.append("add with key=\($0.key)")
        }
        deletes.forEach {
            log.append("delete with key=\($0.key)")
        }
    }
}

class StorageManagerTest: QuickSpec {
    
    override func spec() {

        describe("StorageManager") {
            
            beforeEach() {
                StorageManager.reset()
                NSLog("Resetting StorageManager")
            }

            
            describe("will not initialize") {
            
                it("with no storage types defined") {
                    
                    expect(StorageManager.instance).to(beNil())
                }
                
                it("with no object factory") {
                    var c = StorageManagerConfig()
                    c.types.append(.CoreData)
                    c.options["CoreDataInMemory"] = "CoreDataInMemory"
                    expect{ try StorageManager.configure(c) }.to(throwError())
//                    expect(StorageManager.instance).to(beNil())
                }
            }
            
            describe("is able to be initialized") {

                let objectFactory = TestObjectFactory()
                
                it("using CoreData") {
                    
                    var c = StorageManagerConfig()
                    c.types.append(.CoreData)
                    c.options["CoreDataInMemory"] = "CoreDataInMemory"
                    c.objectFactory = objectFactory
                    expect{ try StorageManager.configure(c) }.toNot(throwError())
                    
                    let sm = StorageManager.instance!
                    
                    let smType = Mirror(reflecting: sm)
                    expect(smType.subjectType == StorageManager.self).to(equal(true))
                }
                
            }
        
        }
    }

}