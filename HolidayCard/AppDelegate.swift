//
//  AppDelegate.swift
//  HolidayCard
//
//  Created by Michael Price on 12/22/17.
//  Copyright © 2017 GrumpTech. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func mnuBackup_DoClick(_ sender: Any)
    {
        // Initiate the backup
        // TODO: Perform action on a background thread.
        let hcp:HolidayCardProcessor = HolidayCardProcessor()
        _ = hcp.BackupContacts()
    }
    
}

