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


class StorageManagerTest2: QuickSpec {
    
    override func spec() {
        
        describe("StorageManager") {

            let objectFactory = TestObjectFactory()

            describe("is able to be initialized") {
                
                describe("using multiple storage methods") {

                    var c = StorageManagerConfig()
                    beforeEach() {
                        StorageManager.reset()
                        
                        c.types.append(.CoreData)
                        c.options["CoreDataInMemory"] = "CoreDataInMemory"
                        c.types.append(.CloudKit)
                        c.objectFactory = objectFactory
                    }

                    it("with no preferences") {
                        
                        expect{ try StorageManager.configure(c) }.toNot(throwError())
                        
                        let sm = StorageManager.instance!
                        
                        let smType = Mirror(reflecting: sm)
                        
                        expect(smType.subjectType == StorageManager.self).to(equal(true))
                    }
                    
                    it("with a preference for main storage") {

                        c.preferredType = .CoreData
                        c.options["CoreDataInMemory"] = "CoreDataInMemory"
                        expect{ try StorageManager.configure(c) }.toNot(throwError())

                        let sm = StorageManager.instance!
                        
                        let smType = Mirror(reflecting: sm)
                        expect(smType.subjectType == StorageManager.self).to(equal(true))
                    }
                    
                }
            }
            
            describe("shares updates") {
                
                beforeEach() {
                    var c = StorageManagerConfig()
                    StorageManager.reset()
                    
                    c.types.append(.CoreData)
                    c.options["CoreDataInMemory"] = "CoreDataInMemory"
                    c.types.append(.CloudKit)
                    c.objectFactory = objectFactory
                    expect{ try StorageManager.configure(c) }.toNot(throwError())
                }

                it("with the application") {
                    _ = StorageManager.instance!

                    
                }
                
                it("with all storage schemes") {
                    
                }
                
            }
            
        }
    }
    
}