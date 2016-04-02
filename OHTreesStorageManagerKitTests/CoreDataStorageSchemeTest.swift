//
//  CoreDataStorageSchemeTest.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/26/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation

import Quick
import Nimble
@testable import OHTreesStorageManagerKit


class CoreDataStorageSchemeTest: QuickSpec {
    override func spec() {
        
        describe("CoreDataStorageSchemeTest") {
        
            beforeEach() {
                StorageManager.reset()
                var c = StorageManagerConfig()
                c.types.append(.CoreData)
                c.objectFactory = TestObjectFactory()
                c.options["CoreDataInMemory"] = "CoreDataInMemory"
                do {
                    try StorageManager.configure(c)
                } catch {
                    // do nothing
                }
            }

            describe("initializes") {
                
                it("is empty") {
                    let sm = StorageManager.instance!
                    
                    let emptiness = sm.get()
                    expect(emptiness.count).to(equal(0))
                }
            }
            
            describe("can store") {
                
                it("and retrieve") {
                    let sm: StorageManager = StorageManager.instance!
                    let obj1 = TestObject()
                    
                    let v1 = obj1.key
                    sm.add(obj1)
                    
                    let obj2 = sm.get()[0]
                    let v2 = obj2.key
                    
                    expect(v1 == v2).to(equal(true))
                }
                
                it("one TestObject and AnotherTestObject") {
                    let sm: StorageManager = StorageManager.instance!
                    let obj1 = TestObject()
                    let obj2 = AnotherTestObject()
                    
                    sm.add(obj1)
                    sm.add(obj2)
                    
                    let obj = sm.get()
                    
                    expect(obj.count).to(equal(2))
                    
                    let obj0Type = Mirror(reflecting: obj[0])
                    expect(obj0Type.subjectType == TestObject.self || obj0Type.subjectType == AnotherTestObject.self).to(equal(true))
                    let obj1Type = Mirror(reflecting: obj[1])
                    expect(obj1Type.subjectType == TestObject.self || obj1Type.subjectType == AnotherTestObject.self).to(equal(true))
                    expect(obj0Type.subjectType == obj1Type.subjectType).to(equal(false))
                }
            }
            
            describe("on changes to the data") {

                it("observers are notified") {
                    
                    StorageManager.reset()
                    var c = StorageManagerConfig()
                    c.types.append(.CoreData)
                    c.types.append(.WatchConnectivity)
                    c.objectFactory = TestObjectFactory()
                    c.options["CoreDataInMemory"] = "CoreDataInMemory"
                    
                    let cdsm = CoreDataStorageScheme(config: c)

                    let obs = TestObserver()
                    cdsm.addObserver(obs)
                    
                    let tO = TestObject()
                    cdsm.addDataObject(tO)
                    
                    expect(obs.log.count == 1).to(equal(true))
                    expect(obs.log[0].uppercaseString).to(equal("add with key=TestObject:Key".uppercaseString))
                    obs.log = [String]()
                    
                    cdsm.deleteDataObject(tO)
                    expect(obs.log.count == 1).to(equal(true))
                    expect(obs.log[0].uppercaseString).to(equal("delete with key=TestObject:Key".uppercaseString))
                }
                
            }
            
        }
    }
}