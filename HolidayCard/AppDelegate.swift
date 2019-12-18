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
    // MARK: Constants, Enumerations, & Structures.
    fileprivate let PERSISTENCE_KEY_BACKUP_PATH:String = "BackupPath"
    // MARK: end Constants, Enumerations, & Structures.

    // MARK: Data Members
    //
    // @desc: reference to the holiday card processor.
    //
    fileprivate var _backupPath:URL? = nil
    
    // MARK: end Data Members
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
        
        // Determine if a .plist file exists. If not attempt to create one.
        do
        {
            let plistFileName:String = Bundle.main.bundleIdentifier! + ".plist"
            
            var plistURL:URL = try FileManager.default.url(for: FileManager.SearchPathDirectory.libraryDirectory,
                                                          in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
            plistURL = plistURL.appendingPathComponent("Preferences")
            plistURL = plistURL.appendingPathComponent(plistFileName, isDirectory: false)
            
            if (!FileManager.default.fileExists(atPath: plistURL.path))
            {
                // Create an empty preferences file.
                var fileAttrs:[FileAttributeKey : Int16] = [FileAttributeKey : Int16]()
                fileAttrs[FileAttributeKey.posixPermissions] = Int16(777)                
                FileManager.default.createFile(atPath: plistURL.path, contents: Data(), attributes: fileAttrs)
            }
        }
        catch
        {
            // Ignore error
        }
        
        // Attempt to restore the Backup Path
        let defaults = UserDefaults.standard
        _backupPath = defaults.url(forKey: PERSISTENCE_KEY_BACKUP_PATH)
        if (_backupPath == nil)
        {
            // Use default
            _backupPath = URL(fileURLWithPath: DefaultBackupPath, isDirectory: true)
        }

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
        
        // Post a notification to disable the UI
        let disableUI:Notification = Notification(name: Notification.Name.HCDisableUserInterface, object: self, userInfo: nil)
        NotificationCenter.default.post(disableUI)
        
        // Initiate the backup (on a background thread to prevent locking up the UI)
        DispatchQueue.global(qos: .background).async
        {
            let hcp:HolidayCardProcessor = HolidayCardProcessor()
            if (hcp.IsContactPermissionGranted!.permissionGranted)
            {
                success = hcp.BackupContacts(backupPath: self._backupPath!)
            }
            
            // If the backup failed, notify the user. But do so on the primary app thread.
            DispatchQueue.main.async
            {
                // Set default message strings. Assume failure.
                var msgTxt:String = String("Backup Failed !!")
                var infoTxt:String = String("Application backup of the contacts database failed !!")
                if (success)
                {
                    msgTxt = String("Backup Finished")
                    infoTxt = String("Application backup of the contacts database complete.")
                }
                
                // Post a notification to update the enabled state of the UI
                let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                NotificationCenter.default.post(enableUI)
                
                // Backup Status
                // Notify the user.
                let alert: NSAlert = NSAlert()
                alert.messageText = msgTxt
                alert.alertStyle = NSAlert.Style.critical
                alert.informativeText = infoTxt
                alert.addButton(withTitle: "Ok")
                alert.runModal()
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
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
        }
    }
    // MARK: end Action Handlers
    
    // MARK: Properties
    //
    // @desc:   Read-Only Property for specifying the default path to the database backup location
    //
    // @param:  Unused
    //
    // @return: Path to the backup location
    //
    // @remarks:None
    //
    var DefaultBackupPath:String
    {
        get
        {
            var defaultPath = String()
            
            do
            {
                let defaultURL:URL = try FileManager.default.url(for: FileManager.SearchPathDirectory.applicationSupportDirectory,
                                                               in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: true)
                defaultPath = defaultURL.relativePath
            }
            catch let error
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to set default path for database backup. Err:" + error.localizedDescription
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            }

            return defaultPath
        }
    }
    
    //
    // @desc:   RW Property for specifying the path to the database backup location
    //
    // @param:  Unused
    //
    // @return: Path to the backup location
    //
    // @remarks:None
    //
    var BackupPath:String
    {
        get
        {
            var path = String()
            
            if (_backupPath != nil)
            {
                path = _backupPath!.relativePath
            }
            
            return path
        }
        
        set
        {
            // Check for a change
            if (BackupPath.compare(newValue) != ComparisonResult.orderedSame)
            {
                // Validate that the candidate path exists
                var isDirectory:ObjCBool = ObjCBool(false)
                let fileExists = FileManager.default.fileExists(atPath: newValue, isDirectory: &isDirectory)
                if (fileExists && isDirectory.boolValue)
                {
                    _backupPath = URL(fileURLWithPath: newValue, isDirectory: true)
                    
                    // Persist the new setting.
                    let defaults = UserDefaults.standard
                    defaults.set(_backupPath, forKey: PERSISTENCE_KEY_BACKUP_PATH)
                }
                
                // Post a notification to update the enabled state of the UI
                // Note: Notify even if the change was rejected. This will allow the
                //       ui to refresh.
                let backupPathChanged:Notification = Notification(name: Notification.Name.APPBackupPathChanged, object: self, userInfo: nil)
                NotificationCenter.default.post(backupPathChanged)
            }
        }
    }

    //
    // @desc:   Read-Only property to determine if the backup path is valid
    //
    // @param:  none
    //
    // @return: true if the backup path is valid.
    //
    // @remarks:None
    //
    var IsBackupPathValid:Bool
    {
        get
        {
            var isDirectory:ObjCBool = ObjCBool(false)
            let fileExists = FileManager.default.fileExists(atPath: BackupPath, isDirectory: &isDirectory)
            
            return (fileExists && isDirectory.boolValue)
        }
    }
    // MARK: end Properties

    
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
        let error:HolidayCardError? = notification.userInfo?[NotificationPayloadKeys.error.rawValue] as? HolidayCardError
        
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

