//
//  @class:         AppDelegate.swift
//  @application:   HolidayCard
//
//  Created by Michael Price on 22-DEC-2017.
//  Copyright © 2017 GrumpTech. All rights reserved.
//
//  @desc:          Application Delegate for HolidayCard
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    // MARK: Initializer/Deinitializer
    //
    // @desc:   Application Initializer
    //
    // @param:  Unused
    //
    // @return: None
    //
    // @remarks:None
    //
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        // Register for the "HolidayCard Error" notification event.
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(self.showError(_:)), name: Notification.Name.HCHolidayCardError, object: nil)
        
        // Ensure that the application will have permission to access the
        // contacts database.
        // Note: This will be performed on a background thread.
        DispatchQueue.global(qos: .background).async
        {
            let hcp:HolidayCardProcessor = HolidayCardProcessor()
            let permissionGranted = hcp.determinePermission()
            
            // When the main thread regains control...
            DispatchQueue.main.async
            {
                // Check the status
                if (!permissionGranted)
                {
                    // Permission has not been granted. Alert the user.
                    let appName: String = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
                    let alertString: String = "The application '" + appName + "' requires access to the Contacts database. Please visit the Privacy settings under Security & Privacy in the Settings app"
                    
                    // Notify the user.
                    let alert: NSAlert = NSAlert()
                    alert.messageText = "Insufficient application privacy permissions"
                    alert.alertStyle = NSAlert.Style.critical
                    alert.informativeText = alertString + "\n\nThe application will now terminate."
                    alert.addButton(withTitle: "Ok")
                    alert.runModal()
                    
                    // Forcibly terminate the application.
                    exit(-1000)
                }
                else
                {
                    // Post a notification that we are good to go.
                    // Event is sync'd by the ViewControllers to initialize their user interfaces.
                    let okToLoad:Notification = Notification(name: Notification.Name.CNPermissionGranted, object: self, userInfo: nil)
                    NotificationCenter.default.post(okToLoad)
                }
            }
        }
    }
    
    //
    // @desc:   Application De-Initializer
    //
    // @param:  Unused
    //
    // @return: None
    //
    // @remarks:None
    //
    func applicationWillTerminate(_ aNotification: Notification)
    {
        // Nothing needed.
    }
    // MARK: end Initializer/Deinitializer
    
    // MARK: Action Handlers
    //
    // @desc:   Event handler for the custom backup menu selection
    //
    // @param:  Unused
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func mnuBackup_DoClick(_ sender: Any)
    {
        var success:Bool = false
        
        // Initiate the backup (on a background thread to prevent locking up the UI)
        DispatchQueue.global(qos: .background).async
        {
            let hcp:HolidayCardProcessor = HolidayCardProcessor()
            if (hcp.IsContactPermissionGranted!.permissionGranted)
            {
                success = hcp.BackupContacts()
            }
            
            // If the backup failed, notify the user. But do so on the primary app thread.
            DispatchQueue.main.async
            {
                // Backup Failed?
                if (!success)
                {
                    // Notify the user.
                    let alert: NSAlert = NSAlert()
                    alert.messageText = "Backup Failed !!"
                    alert.alertStyle = NSAlert.Style.critical
                    alert.informativeText = "Application backup of the contacts database failed !!"
                    alert.addButton(withTitle: "Ok")
                    alert.runModal()
                }
            }
        }
    }
    
    //
    // @desc:   Event handler for the Show Help selection
    //
    // @param:  Unused
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func mnuHelp_ShowHelp(_ sender: Any)
    {
        // The application is documented online via a GitHub Wiki.
        let helpPage:String = "https://github.com/pricemi115/HolidayCard/wiki"
        
        // Create a URL object for the help page.
        let url:URL? = URL(string: helpPage)
        let workspace:NSWorkspace = NSWorkspace()
        
        if ((url == nil) ||
            (!workspace.open(url!)))
        {
            // Failed to show help.

            // Get the stack trace
            var stackTrace:String = "Stack Trace:"
            Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
            
            let errDesc:String = "Unable to open help page. Info:\(helpPage)"
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Warning)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = ["error":errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
        }
    }
    // MARK: end Action Handlers
    
    // MARK: Private methods
    //
    // @desc:   Helper to notify the user of an error
    //
    // @param:  error: Holiday Card error
    //
    // @return: None
    //
    // @remarks:None
    //
    @objc func showError(_ notification:NSNotification) -> Void
    {
        // Get the error
        let error:HolidayCardError? = notification.userInfo?["error"] as? HolidayCardError
        
        if (error != nil)
        {
            // Notify the user on the primary application thread.
            DispatchQueue.main.async
            {
                // Notify the user.
                let alert: NSAlert = NSAlert()
                alert.messageText = "Error notification"
                alert.alertStyle = (error?.Style)!
                alert.informativeText = (error?.Description)! + "\n\n" + (error?.StackTrace)!
                alert.addButton(withTitle: "Ok")
                alert.runModal()
            }
        }
    }
    // MARK: end Private methods
}

