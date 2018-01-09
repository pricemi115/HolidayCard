//
//  @class:         ViewController.swift
//  @application:   HolidayCard
//
//  Created by Michael Price on 22-DEC-2017.
//  Copyright © 2017 GrumpTech. All rights reserved.
//
//  @desc:          Primary ViewController for the HolidayCard application.
//

import Cocoa
import Contacts

class ViewController: NSViewController {

    // MARK: Properties
    @IBOutlet weak fileprivate var _selGroupSource: NSPopUpButton!
    @IBOutlet weak fileprivate var _selGroupDestination: NSPopUpButton!
    @IBOutlet weak fileprivate var _selPostalAddressLabels: NSPopUpButton!
    @IBOutlet weak fileprivate var _selRelationLabels: NSPopUpButton!
    @IBOutlet weak fileprivate var _prgBusyIndicator: NSProgressIndicator!
    @IBOutlet weak fileprivate var _btnGenerateList: NSButton!
    @IBOutlet weak fileprivate var _btnResetMailingList: NSButton!
    // MARK: end Properties
    
    // MARK: Data Members
    fileprivate var _hcp:HolidayCardProcessor!
    // MARK: end Data Members
    //
    // @desc:   Initializer for the User Interface view
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    override func viewDidLoad() {
        super.viewDidLoad()

        // Just initialize the UI
        
        // Initialize the busy indicator and activate it.
        _prgBusyIndicator.usesThreadedAnimation = true
        _prgBusyIndicator.startAnimation(self)
        
        _selGroupSource.removeAllItems()
        _selGroupSource.isEnabled = false
        _selGroupDestination.removeAllItems()
        _selGroupDestination.isEnabled = false
        _selRelationLabels.removeAllItems()
        _selRelationLabels.isEnabled = false
        _selPostalAddressLabels.removeAllItems()
        _selPostalAddressLabels.isEnabled = false
        
        // Set focus to the generate button
        _btnGenerateList.isEnabled = false
        _btnGenerateList.becomeFirstResponder()
        
        _btnResetMailingList.isEnabled = false
        
        // Register for the "PermissionGranted" notification event.
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(InitializeUI), name: Notification.Name.CNPermissionGranted, object: nil)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // MARK: Public Methods
    // MARK: end Publix Methods

    // MARK: Action Handlers
    //
    // @desc:   Handler for the doClick event of the Generate List button
    //
    // @param:  Not used
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func _btnGenerateList_doClick(_ sender: Any)
    {
        if ((_selGroupSource.numberOfItems > 0) &&
            (_selGroupDestination.numberOfItems > 0) &&
            (_selPostalAddressLabels.numberOfItems > 0) &&
            (_selRelationLabels.numberOfItems > 0))
        {
            // Get the names of the source & destination groups.
            let source:String = _selGroupSource.titleOfSelectedItem!
            let dest:String   = _selGroupDestination.titleOfSelectedItem!
            // Get the name of the postal address label to use for the mailing list.
            let address:String = _selPostalAddressLabels.titleOfSelectedItem!
            // Get the name of the related contact label to use for the mailing list.
            let name:String = _selRelationLabels.titleOfSelectedItem!
            
            // Generate the list. Perform the operation on a background thread.
            DispatchQueue.global(qos: .background).async
            {
                self._hcp.GenerateHolidayList(grpSource: source, addrSource: address, relatedNameSource: name, grpDest: dest)
            }
        }
    }
    
    //
    // @desc:   Handler for the doClick event of the Reset List button
    //
    // @param:  Not used
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func _btnResetList_doClick(_ sender: Any)
    {
        if (_selGroupDestination.numberOfItems > 0)
        {
            // Get the name of the destination group that is currently selected.
            let group:String = _selGroupDestination.titleOfSelectedItem!
            // Find out how many "potential" contacts will be eliminated.
            let contacts:[CNContact] = _hcp.GetContactGroupContents(groupName: group)
            
            // Don't worry about doing anything if there are no contacts in the group.
            if (contacts.count > 0)
            {
                // Ensure the user is aware of the potential consequences to their actions.
                // TODO: Use a subview to allow the user to see all of the contacts in the group. For now - just use an alertable message.
                let alert: NSAlert = NSAlert()
                alert.messageText = "There are \(contacts.count) contacts in group '\(group)' that are about to be deleted."
                alert.alertStyle = .warning
                alert.informativeText = "Are you sure you want to contunue?"
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Proceed")
                // Pose the confirmation
                let response: NSApplication.ModalResponse = alert.runModal()
                // Only proceed if confirmed.
                if (response == .alertSecondButtonReturn)
                {
                    // Perform the operation on a background thread.
                    DispatchQueue.global(qos: .background).async
                    {
                        self._hcp.FlushAllGroupContacts(groupName: group)
                    }
                }
            }
        }
    }
    
    //
    // @desc:   Handler for the doClick event of the Source Group selection
    //
    // @param:  Not used
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func _selGroupSource_doClick(_ sender: Any)
    {
        // The source group has changed. Update the postal address labels.
        resetPostalAddressOptions()
        // The source group has changed. Update the relation name labels.
        resetRelationNameOptions()
        
        // Enable/Disable the generate list button if either the source group, postal addresses, or relation names are empty
        _btnGenerateList.isEnabled = ((_selGroupSource.numberOfItems > 0) && (_selRelationLabels.numberOfItems > 0) && (_selPostalAddressLabels.numberOfItems > 0))
    }

    // MARK: end Action Handlers
    
    // MARK: Private helper methods
    
    //
    // @desc:   Helper to reset the UI for the Postal Address selection
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    fileprivate func resetPostalAddressOptions()
    {
        // Initialize the postal address labels
        _selPostalAddressLabels.removeAllItems()
        let postalLabels:[String] = _hcp.GetPostalAddressLabels(groupName: _selGroupSource.titleOfSelectedItem!)
        for label in postalLabels
        {
            _selPostalAddressLabels.addItem(withTitle: label)
        }
    }
    
    //
    // @desc:   Helper to reset the UI for the Renation Name selection
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    fileprivate func resetRelationNameOptions()
    {
        // Initialize the postal address labels
        _selRelationLabels.removeAllItems()
        let relationNameLabels:[String] = _hcp.GetRelatedNamesLabels(groupName: _selGroupSource.titleOfSelectedItem!)
        for name in relationNameLabels
        {
            _selRelationLabels.addItem(withTitle: name)
        }
    }
    
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
        // Stop the busy indicator
        _prgBusyIndicator.stopAnimation(self)
        
        // Create/Initialize the Holiday Card Processor
        _hcp = HolidayCardProcessor()
        
        // Get the list of contact groups available.
        let groups:[String] = _hcp.GetContactGroups
        // Reset/Re-Populate the group selection lists.
        _selGroupSource.removeAllItems()
        _selGroupDestination.removeAllItems()
        for name in groups
        {
            _selGroupSource.addItem(withTitle: name)
            _selGroupDestination.addItem(withTitle: name)
        }
        
        // Initialize the postal address options.
        resetPostalAddressOptions()
        
        // Initialize the contact relation options.
        resetRelationNameOptions()
        
        // Update the ui control elements
        _selGroupSource.isEnabled = true
        _selGroupDestination.isEnabled = true
        _selRelationLabels.isEnabled = true
        _selPostalAddressLabels.isEnabled = true
        // Enable/Disable the generate list button if wither the postal addresses or relation names are empty
        _btnGenerateList.isEnabled = ((_selGroupSource.numberOfItems > 0) && (_selRelationLabels.numberOfItems > 0) && (_selPostalAddressLabels.numberOfItems > 0))
        _btnResetMailingList.isEnabled = (_selGroupDestination.numberOfItems > 0)
        
        // Set focus to the generate button
        _btnGenerateList.becomeFirstResponder()
    }
    // MARK: end Private helper methods
}

