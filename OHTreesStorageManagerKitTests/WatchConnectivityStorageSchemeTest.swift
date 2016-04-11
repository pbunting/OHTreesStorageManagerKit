//
//  WatchConnectivityStorageSchemeTest.swift
//  OHTreesStorageManagerKit
//
//  Created by Paul Bunting on 3/26/16.
//  Copyright © 2016 Paul Bunting. All rights reserved.
//

import Foundation
import WatchConnectivity

import Quick
import Nimble
@testable import OHTreesStorageManagerKit

class MockWatchConnectingSession: WatchConnectingSession {
    var didCallActivateSession = false
    
    private var wcSessionDelegate_: WCSessionDelegate?
    
    weak var delegate: WCSessionDelegate? {
        get {
            return wcSessionDelegate_
        }
        set {
            wcSessionDelegate_ = newValue
        }}

    var receivedApplicationContexts: [[String: AnyObject]] = [[String: AnyObject]]()
    
    
    func activateSession() {
        didCallActivateSession = true
    }
    
    var receivedApplicationContext: [String: AnyObject] {
        get {
            if receivedApplicationContexts.count > 0 {
                return receivedApplicationContexts.removeFirst()
            } else {
                return [String: AnyObject]()
            }
        }
    }

}

class WatchConnectivityStorageSchemeTest: QuickSpec {
    override func spec() {
        
        describe("WatchConnectivityStorageSchemeTest") {
        
            var mockSession: MockWatchConnectingSession!
            func getSession() -> WatchConnectingSession {
                return mockSession
            }
            
            beforeEach() {
                StorageManager.reset()
                var c = StorageManagerConfig()
                c.types.append(.WatchConnectivity)
                c.objectFactory = TestObjectFactory()
                mockSession = MockWatchConnectingSession()
                c.wcSession = getSession
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

                    mockSession = MockWatchConnectingSession()
                    c.wcSession = getSession
                    
                    let cdsm = WatchConnectivityStorageScheme(config: c)

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
            
            describe("can recieve updates from its ios/watch partner") {
                
                var mockSession: MockWatchConnectingSession!
                func getSession() -> WatchConnectingSession {
                    return mockSession
                }

                beforeEach() {
                    StorageManager.reset()
                    var c = StorageManagerConfig()
                    c.types.append(.WatchConnectivity)
                    c.objectFactory = TestObjectFactory()
                    mockSession = MockWatchConnectingSession()
                    c.wcSession = getSession
                    do {
                        try StorageManager.configure(c)
                    } catch {
                        // do nothing
                    }
                }

                it("for adding an item") {
                    let sm: StorageManager = StorageManager.instance!
                    
                    let content : [[String : AnyObject]] = [
                        ["key" : "TestObject"]
                    ]
                    let applicationContextUpdate: [String: AnyObject] = ["Objects": content]
                    
                    // Fortunately the WCSession argument is not used
                    mockSession.delegate!.session!(WCSession.defaultSession(), didReceiveApplicationContext: applicationContextUpdate)
                    
                    let actual = sm.get()
                    expect(actual.count == 1).to(equal(true))
                    
                }

                it("for deleting an item") {
                    let sm: StorageManager = StorageManager.instance!

                    let o1 = TestObject()
                    let o2 = AnotherTestObject()
                    
                    sm.add(o1)
                    sm.add(o2)
                    
                    let pre = sm.get()
                    expect(pre.count == 2).to(equal(true))
                    
                    let content : [[String : AnyObject]] = [
                        ["key" : "TestObject"]
                    ]
                    let applicationContextUpdate: [String: AnyObject] = ["Objects": content]
                    
                    // Fortunately the WCSession argument is not used
                    mockSession.delegate!.session!(WCSession.defaultSession(), didReceiveApplicationContext: applicationContextUpdate)
                    let actual = sm.get()
                    expect(actual.count == 1).to(equal(true))

                    let obj2 = sm.get()[0]
                    let v2 = obj2.key
                    
                    expect(o1.key == v2).to(equal(true))
                }

                it("for deleting the correct item") {
                    let sm: StorageManager = StorageManager.instance!
                    
                    let o1 = TestObject()
                    let o2 = AnotherTestObject()
                    
                    sm.add(o1)
                    sm.add(o2)
                    
                    let pre = sm.get()
                    expect(pre.count == 2).to(equal(true))
                    
                    let content : [[String : AnyObject]] = [
                        ["key" : "AnotherTestObject"]
                    ]
                    let applicationContextUpdate: [String: AnyObject] = ["Objects": content]
                    
                    // Fortunately the WCSession argument is not used
                    mockSession.delegate!.session!(WCSession.defaultSession(), didReceiveApplicationContext: applicationContextUpdate)
                    let actual = sm.get()
                    expect(actual.count == 1).to(equal(true))
                    
                    let obj2 = sm.get()[0]
                    let v2 = obj2.key
                    
                    expect(o2.key == v2).to(equal(true))
                }

            }
            
        }
    }
}