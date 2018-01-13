//
//  DataContertViewController.swift
//  HolidayCard
//
//  Created by Michael Price on 1/14/18.
//  Copyright © 2018 GrumpTech. All rights reserved.
//

import Cocoa

//
// @desc: Controller for the data content view
//
class DataContertViewController: NSViewController
{
    // MARK: Constants, Enumerations, & Structures.
    // MARK: end Constants, Enumerations, & Structures
    
    // MARK: Properties
    // @desc: References to UI control elements
    @IBOutlet fileprivate weak var _prgBusyIndicator: NSProgressIndicator!
    @IBOutlet fileprivate weak var _viewSourceContent: NSView!
    @IBOutlet fileprivate weak var _viewDestinationContent: NSView!
    
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
        
        // Hide the custom content views
        _viewSourceContent.isHidden         = true
        _viewDestinationContent.isHidden    = true
        
        // Start the busy indicator
        _prgBusyIndicator.usesThreadedAnimation = true
        _prgBusyIndicator.startAnimation(self)

        // Register for the notification events.
        let nc = NotificationCenter.default
        // Register for the "PermissionGranted" event.
        nc.addObserver(self, selector: #selector(InitializeUI), name: Notification.Name.CNPermissionGranted, object: nil)
        nc.addObserver(self, selector: #selector(ModeChange(_:)), name: Notification.Name.HCModeChange, object: nil)
    }
    // MARK: end Class overrides
    
    // MARK: Public Methods
    // MARK: end Publix Methods
    
    // MARK: Action Handlers
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
        // The UI is ready, stop the busy indicator
        _prgBusyIndicator.stopAnimation(self)
    }
    
    //
    // @desc:   Helper to react to mode changes.
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the SideBar ViewController.
    //
    @objc fileprivate func ModeChange(_ notification:NSNotification) -> Void
    {
        // Get the new mode.
        let mode:SideBarViewController.SIDEBAR_MODE? = notification.userInfo?["mode"] as? SideBarViewController.SIDEBAR_MODE
        
        if (mode != nil)
        {
            print("New Mode \(mode!)")
        }
        
        // Update the view visability
        _viewDestinationContent.isHidden    = (SideBarViewController.SIDEBAR_MODE.sourceMode == mode)
        _viewSourceContent.isHidden         = (SideBarViewController.SIDEBAR_MODE.destinationMode == mode)
    }
    // MARK: end Private helper methods
}
