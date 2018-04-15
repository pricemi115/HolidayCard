//
//  PrefVuewController.swift
//  HolidayCard
//
//  Created by Michael Price on 3/26/18.
//  Copyright © 2018 GrumpTech. All rights reserved.
//

import Cocoa

//
// @desc: Controller for the preferences content view
//
class PrefViewController: NSViewController
{
    // MARK: Constants, Enumerations, & Structures.
    fileprivate enum BackUpTypes:Int
    {
        case Unknown    = -1
        case Default    = 0
        case Custom     = 1
    }
    // MARK: end Constants, Enumerations, & Structures

    // MARK: Properties
    // @desc: References to UI control elements
    @IBOutlet fileprivate weak var _backupType: NSPopUpButton!
    @IBOutlet fileprivate weak var _backupPath: NSTextField!
    @IBOutlet fileprivate      var _btnChangeBackupLocn: NSButton!
    
    // MARK: end Properties
    
    // MARK: Data Members
    // MARK: end Data Members
    
    // MARK: Class overrides
    //
    // @desc:   Class override for loading the view
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Register for the notification events.
        let nc = NotificationCenter.default
        // Register for the "Backup Location Changed" event.
        nc.addObserver(self, selector: #selector(InitializeUI), name: Notification.Name.APPBackupPathChanged, object: nil)
        
        InitializeUI()
    }
    // MARK: end Class overrides
    
    // MARK: Action Handlers
    //
    // @desc:   Event handler changing the backup location
    //
    // @param:  N/A
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction func _btnChangeBackupLocn_Clicked(_ sender: Any)
    {
        let appDelegate:AppDelegate = NSApplication.shared.delegate as! AppDelegate

        // Open a browse dialog to allow the user to specify the
        // backup location.
        let dialog = NSOpenPanel()
        
        dialog.title                   = "Choose a backup location"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canChooseDirectories    = true
        dialog.canCreateDirectories    = true
        dialog.allowsMultipleSelection = false
        dialog.canChooseFiles          = false
        // Set the location to the current backup location.
        dialog.directoryURL            = URL(fileURLWithPath: appDelegate.BackupPath, isDirectory: true)
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK)
        {
            let result = dialog.directoryURL
            
            if (result != nil)
            {
                let path = result!.path
                
                // Create a dummy file to ensure we can use this location.
                let file:String = path + "/.hc_access_test"
                let data:String = "dummy text"
                do
                {
                    // Make the test.
                    try data.write(toFile: file, atomically: true, encoding: String.Encoding.unicode)

                    // Set the new backup location.
                    appDelegate.BackupPath = path
                }
                catch let error
                {
                    let errDesc:String = "Unable to use backup location: \(path)\nError: \(error.localizedDescription)"
                    let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Warning)
                    
                    // Post the error for reporting.
                    let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                    let nc:NotificationCenter = NotificationCenter.default
                    nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
                }
            }
        }
        else
        {
            // User clicked on "Cancel"
            return
        }
    }
    
    //
    // @desc:   Event handler changing the backup type
    //
    // @param:  N/A
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction func _backupType_Changed(_ sender: Any)
    {
        // Determine the current backup type
        let backupType:BackUpTypes = convertBackupPrompt(prompt: (_backupType.selectedItem?.title)!)
        
        // Enable/Disable the change location button
        _btnChangeBackupLocn.isEnabled = (.Custom == backupType)
        
        // Reset the backup location to default
        if (.Default == backupType)
        {
            let appDelegate:AppDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.BackupPath = appDelegate.DefaultBackupPath
        }
    }

    //
    // @desc:   Event handler for clicking the view backup folder button
    //
    // @param:  N/A
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction func _backupFolderBtn_Clicked(_ sender: Any)
    {
        // We were clicked
        let appDelegate:AppDelegate = NSApplication.shared.delegate as! AppDelegate
        if (appDelegate.IsBackupPathValid)
        {
            let backupURL:URL = URL(fileURLWithPath: appDelegate.BackupPath, isDirectory: true)
            
            // Attempt to launch Finder to the backup location.
            let _:Bool = NSWorkspace.shared.open(backupURL)
        }
    }
    // MARK: end Action Handlers
    
    // MARK: Public Methods
    // MARK: end Public Methods
    
    // MARK: Public Properties
    //
    // @desc:   Event handler
    //
    // @param:  None
    //
    // @return: String array of items for the list
    //
    // @remarks:None
    //
    @objc fileprivate var backupType: [String]!
    {
        get
        {
            // Construct a list of selections for th backup types.
            var selections:[String] = [String]()
            selections.append(getBackupTypePrompt(type: .Default))
            selections.append(getBackupTypePrompt(type: .Custom))

            return selections
        }
    }
    // MARK: end Public Properties
    
    // MARK: Private helper methods & properties
    //
    // @desc:   Helper to convert back up type enumerations to prompts
    //
    // @param:  type: Backup Type to be converted
    //
    // @return: Prompt for the type specified
    //
    // @remarks:None
    //
    fileprivate func getBackupTypePrompt(type: BackUpTypes) -> String
    {
        var prompt:String = String("Unknown")
        
        switch (type)
        {
        case .Default:
            prompt = String("Default")
            break
            
        case .Custom:
            prompt = String("Custom")
            break
            
        default:
            prompt = String("Unknown_\(type.rawValue)")
            break
        }
        
        return prompt
    }
    
    //
    // @desc:   Helper to convert back up type prompt to an enumeration
    //
    // @param:  prompt: Backup Prompt to be converted
    //
    // @return: Backup Type for the prompt specified
    //
    // @remarks:None
    //
    fileprivate func convertBackupPrompt(prompt:String) -> BackUpTypes
    {
        var type:BackUpTypes = BackUpTypes.Unknown
        
        // Check for Default
        if (getBackupTypePrompt(type: .Default).compare(prompt) == ComparisonResult.orderedSame)
        {
            // Default prompt
            type = .Default
        }
        else if (getBackupTypePrompt(type: .Custom).compare(prompt) == ComparisonResult.orderedSame)
        {
            // Custom prompt
            type = .Custom
        }
        else
        {
            // Unknown prompt
            type = .Unknown
        }
        
        return type
    }
    
    //
    // @desc:   Helper to update the UI
    //
    // @param:  none
    //
    // @return: none
    //
    // @remarks:None
    //
    @objc fileprivate func InitializeUI() -> Void
    {
        // Get the current & default path for the backup location from the application delegate
        let appDelegate:AppDelegate = NSApplication.shared.delegate as! AppDelegate
        let currentPath = appDelegate.BackupPath
        let defaultPath = appDelegate.DefaultBackupPath

        // Determine the backup type, based on the paths.
        var backupType:BackUpTypes = BackUpTypes.Unknown
        if (defaultPath.compare(currentPath) == ComparisonResult.orderedSame)
        {
            backupType = .Default
        }
        else
        {
            backupType = .Custom
        }
        _backupType.selectItem(withTitle: getBackupTypePrompt(type: backupType))
        _btnChangeBackupLocn.isEnabled = (.Custom == backupType)
        
        // Display the path for the user.
        let attrPath:NSMutableAttributedString = NSMutableAttributedString(string: currentPath)
        _backupPath.attributedStringValue = attrPath
        _backupPath.toolTip = currentPath
    }
    // MARK: end Private helper methods & properties
}
