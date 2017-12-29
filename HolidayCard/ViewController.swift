//
//  ViewController.swift
//  HolidayCard
//
//  Created by Michael Price on 12/22/17.
//  Copyright © 2017 GrumpTech. All rights reserved.
//

import Cocoa
import Contacts

class ViewController: NSViewController {

    // MARK: Properties
    @IBOutlet weak var _selGroupSource: NSPopUpButton!
    @IBOutlet weak var _selGroupDestination: NSPopUpButton!
    @IBOutlet weak var _selPostalAddressLabels: NSPopUpButton!
    @IBOutlet weak var _selRelationLabels: NSPopUpButton!
    @IBOutlet weak var _prgBusyIndicator: NSProgressIndicator!
    @IBOutlet weak var _btnGenerateList: NSButton!
    // MARK: end Properties
    
    // MARK: Data Members
    var _hcp:HolidayCardProcessor!
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
        
        
        // Initialize the busy indicator
        _prgBusyIndicator.isHidden = true
        
        // Set focus to the generate button
        _btnGenerateList.becomeFirstResponder()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


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
    @IBAction func _btnGenerateList_doClick(_ sender: Any)
    {
        // Get the names of the source & destination groups.
        let source:String = _selGroupSource.titleOfSelectedItem!
        let dest:String   = _selGroupDestination.titleOfSelectedItem!
        // Get the name of the postal address label to use for the mailing list.
        let address:String = _selPostalAddressLabels.titleOfSelectedItem!
        // Get the name of the related contact label to use for the mailing list.
        let name:String = _selRelationLabels.titleOfSelectedItem!
        
        // Validate that the source and destination are different.
        guard(source.caseInsensitiveCompare(dest) != .orderedSame) else
        {
            return
        }
        
        // Generate the list.
        _hcp.GenerateHolidayList(grpSource: source, addrSource: address, relatedNameSource: name, grpDest: dest)
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
    @IBAction func _btnResetList_doClick(_ sender: Any)
    {
        // Get the name of the destination group that is currently selected.
        let group:String = _selGroupDestination.titleOfSelectedItem!
        // Find out how many "potential" contacts will be eliminated.
        let contacts:[CNContact] = _hcp.GetContactGroupContents(groupName: group)
        
        // Don;t worry about doing anything if there are no contacts in the group.
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
                _hcp.FlushAllGroupContacts(groupName: group)
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
    @IBAction func _selGroupSource_doClick(_ sender: Any)
    {
        // The source group has changed. Update the postal address labels.
        resetPostalAddressOptions()
        // The source group has changed. Update the relation name labels.
        resetRelationNameOptions()
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
    // MARK: end Private helper methods
}

