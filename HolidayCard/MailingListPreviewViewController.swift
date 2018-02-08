//
//  MailingListPreviewViewController.swift
//  HolidayCard
//
//  Created by Michael Price on 2/7/18.
//  Copyright © 2018 GrumpTech. All rights reserved.
//

import Cocoa

//
// @desc: Controller for the mailing list preview view
//
class MailingListPreviewViewController: NSViewController
{
    // MARK: Constants, Enumerations, & Structures.
    // MARK: end Constants, Enumerations, & Structures
    
    // MARK: Properties
    // MARK: end Properties
    
    // MARK: Data Members
    //
    // @desc: Cached frame size used to restore the window to its original size when the data are ready.
    fileprivate var _frameSize:CGSize = CGSize()
    //
    // @desc: Preview Type
    fileprivate var _previewType:HolidayCardProcessor.ContactPreviewType = HolidayCardProcessor.ContactPreviewType.Unknown
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
        nc.addObserver(self, selector: #selector(UpdateUI), name: Notification.Name.HCPreviewDataReady, object: nil)
    }

    override func viewWillAppear()
    {
        super.viewWillAppear()
        
        // Hide ourself by becomming really small.
        // Note: Use the current origin so as to not change desktops if there are multiple.
        // Note: Since this VC is intiated as a *modal* segue, if we never show this window, then
        //       the application will effectively lock up.
        // We will show ourself when we have data to display
        if (self.view.window != nil)
        {
            // Get the current window frame
            var frame:NSRect = (self.view.window?.frame)!
            // Cache the frame size for restoration later.
            _frameSize = frame.size
            // Make ourselves really small.
            frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: 0, height: 0)
            self.view.window?.setFrame(frame, display: false)
        }
    }
    // MARK: end Class overrides
    
    // MARK: Public Methods
    // MARK: end Public Methods
    
    // MARK: Public Properties
    //
    // @desc:   Property for the preview type
    //
    // @param:  None
    //
    // @return: Preview type
    //
    // @remarks:None
    //
    var PreviewType: HolidayCardProcessor.ContactPreviewType
    {
        get
        {
            return _previewType
        }
        
        set
        {
            _previewType = newValue
        }
    }
    // MARK: end Public Properties
    
    // MARK: Action Handlers
    // MARK: end Action Handlers
    
    // MARK: Private helper methods
    //
    // @desc:   Helper to Update the UI and show the mailing list preview
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the AppDelegate.
    //
    @objc fileprivate func UpdateUI() -> Void
    {
        if (self.view.window != nil)
        {
            // Get the current window frame
            var frame:NSRect = (self.view.window?.frame)!
            // Make ourselves normal again.
            frame = CGRect(origin: frame.origin, size: _frameSize)
            self.view.window?.setFrame(frame, display: true)
            
            // Update the window title
            self.view.window?.title = PreviewTypeDesc
        }
    }
    
    //
    // @desc:   Read-Only property for the string representation of the preview type
    //
    // @param:  None
    //
    // @return: String representation/
    //
    // @remarks:None
    //
    fileprivate var PreviewTypeDesc: String
    {
        get
        {
            let DESC_BASE:String = "Mailing List: "
            var desc:String =  String("Invalid preview type")
            
            switch (PreviewType)
            {
            case HolidayCardProcessor.ContactPreviewType.Preview:
                desc = DESC_BASE + "Preview"
                break
                
            case HolidayCardProcessor.ContactPreviewType.Error:
                desc = DESC_BASE + "Errors"
                break
                
            default:
                desc = DESC_BASE + "Unknown"
                break
            }
            
            return desc
        }
    }
    // MARK: end Private helper methods
}
