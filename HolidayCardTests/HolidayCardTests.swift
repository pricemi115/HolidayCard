//
//  HolidayCardTests.swift
//  HolidayCardTests
//
//  Created by Michael Price on 12/22/17.
//  Copyright © 2017 GrumpTech. All rights reserved.
//

import XCTest
@testable import HolidayCard
import Contacts

class HolidayCardTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testContactsPermission()
    {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let hc = HolidayCardProcessor()
        let testResult: Bool = hc.determinePermission()
        
        // Check for consistency
        XCTAssertTrue((testResult == hc.IsContactPermissionGranted.permissionGranted), "Permission Mismatch")
    }
    
    func testFlushContacts()
    {
        let hc = HolidayCardProcessor()
        let groupTest: String = "Temp"
        
        // Get the list before the "flush"
        let beforeFlush = hc.GetGontactCount(sourceId: groupTest, addrSource: nil, relatedNameSource: nil)

        hc.FlushAllGroupContacts(sourceId: groupTest)
        
        // Get the list after the "flush"
        let afterFlush = hc.GetGontactCount(sourceId: groupTest, addrSource: nil, relatedNameSource: nil)

        // Determine success.
        XCTAssertTrue(((beforeFlush.totalContacts>0) && (afterFlush.totalContacts==0)), "Contacts Flush failed. before=\(beforeFlush.totalContacts) after=\(afterFlush.totalContacts)")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
