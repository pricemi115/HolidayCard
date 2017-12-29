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
        let testResult: Bool = hc.requestPermission()
        
        // Check for consistency
        XCTAssertTrue((testResult == hc.IsContactPermissionGranted.permissionGranted), "Permission Mismatch")
    }
    
    func testFlushContacts()
    {
        let hc = HolidayCardProcessor()
        let groupTest: String = "Temp"
        
        // Get the list before the "flush"
        let beforeList:[CNContact] = hc.GetContactGroupContents(groupName: groupTest)

        hc.FlushAllGroupContacts(groupName: groupTest)
        
        // Get the list after the "flush"
        let afterList:[CNContact] = hc.GetContactGroupContents(groupName: groupTest)

        // Determine success.
        XCTAssertTrue(((beforeList.count>0) && (afterList.count==0)), "Contacts Flush failed. before=\(beforeList.count) after=\(afterList.count)")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    
    // Private helper method to show an alert when permission to the contacts have not been granted.
    private func showPermissionAlert() {
        let appName: String = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        let alertString: String = "Application '" + appName + "' requires access to the Contacts application."
        /*
         let alert = UIAlertController(title: "", message: "Allow App to access contacts"
         , preferredStyle: .alert)
         let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
         let settingAction = UIAlertAction(title: "Settings", style: .default, handler: { (action) in
         // Open Settings, right to the page with your app’s permissions
         openSetings()
         })
         
         alert.addAction(cancelAction)
         alert.addAction(settingAction)
         alert.preferredAction = settingAction
         self.present(alert, animated: true, completion: nil)\
         */
        print(alertString)
    }
}
