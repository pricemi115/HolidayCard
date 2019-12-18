//
//  SideBarViewController.swift
//  HolidayCard
//
//  Created by Michael Price on 1/14/18.
//  Copyright © 2018 GrumpTech. All rights reserved.
//

import Cocoa

//
// @desc: Controller for the sidebar view
//
class SideBarViewController: NSViewController
{
    // MARK: Constants, Enumerations, & Structures.
    //
    // @desc: Constant width for side bar view. Used to prevent the repositioning of the
    //        split view slider control.
    fileprivate let SIDEBAR_WIDTH:CGFloat = 120.0
    
    //
    // @desc: SideBar modes
    //
    enum SIDEBAR_MODE : Int
    {
        case sourceMode
        case destinationMode
    }
    // MARK: end Constants, Enumerations, & Structures

    // MARK: Properties
    // @desc: References to UI control elements
    @IBOutlet fileprivate weak var _btnSourceContent: NSButtonCell!
    @IBOutlet fileprivate weak var _btnDestinationContent: NSButton!
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
        
        // Hard code width constraints on the split views to prevent adjusting the split-view divider.
        NSLayoutConstraint(item: self.view, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: SIDEBAR_WIDTH).isActive = true

        // Tag each of the buttons
        _btnSourceContent.tag       = SIDEBAR_MODE.sourceMode.rawValue
        _btnDestinationContent.tag  = SIDEBAR_MODE.destinationMode.rawValue
        
        // Disable the UI until we are ready
        _btnSourceContent.isEnabled = false
        _btnSourceContent.state = NSControl.StateValue.off
        _btnDestinationContent.isEnabled = false
        _btnDestinationContent.state = NSControl.StateValue.off

        // Register for the notification events.
        let nc = NotificationCenter.default
        // Register for the "PermissionGranted" event.
        nc.addObserver(self, selector: #selector(InitializeUI), name: Notification.Name.CNPermissionGranted, object: nil)
    }
    // MARK: end Class overrides

    // MARK: Public Methods
    // MARK: end Publix Methods
    
    // MARK: Action Handlers
    @IBAction func actionEventHandler(_ sender: NSButton)
    {
        // Prevent turning the button(s) off.
        if (sender.state != NSControl.StateValue.off)
        {
            let newMode:SIDEBAR_MODE = SIDEBAR_MODE(rawValue: sender.tag)!
            // Ensure that the "other" button is off.
            switch (newMode)
            {
            case SIDEBAR_MODE.sourceMode:
                // Ensure that destination mode is off
                _btnDestinationContent.state = NSControl.StateValue.off
                break
                
            case SIDEBAR_MODE.destinationMode:
                // Ensure that source mode is off
                _btnSourceContent.state = NSControl.StateValue.off
                break
            }
            
            // Post a notification of the new mode.
            let mode:[String:SIDEBAR_MODE] = ["mode":newMode]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCModeChange, object: nil, userInfo: mode)
        }
        else
        {
            // Force the control to remain on.
            sender.state = NSControl.StateValue.on
        }
    }
    // MARK: end Action Handlers

    // MARK: Private helper methods
    //
    // @desc:   Helper to initialize the view controler at the appropriate time.
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the AppDelegate.
    //
    @objc fileprivate func InitializeUI() -> Void
    {
        // Setup the UI, defaulting to the source content
        // Disable the UI until we are ready
        _btnSourceContent.isEnabled = true
        _btnSourceContent.state = NSControl.StateValue.on
        _btnDestinationContent.isEnabled = true
        _btnDestinationContent.state = NSControl.StateValue.off
        
        // Update any clients with the currently selected mode.
        // Post a notification of the new mode.
        let mode:[String:SIDEBAR_MODE] = ["mode":SIDEBAR_MODE.sourceMode]
        let nc:NotificationCenter = NotificationCenter.default
        nc.post(name: Notification.Name.HCModeChange, object: nil, userInfo: mode)
    }
    // MARK: end Private helper methods
}
