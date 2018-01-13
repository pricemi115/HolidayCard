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
    // @desc: References to UI control elements
    @IBOutlet weak fileprivate var _selGroupSource: NSPopUpButton!
    @IBOutlet weak fileprivate var _selGroupDestination: NSPopUpButton!
    @IBOutlet weak fileprivate var _selPostalAddressLabels: NSPopUpButton!
    @IBOutlet weak fileprivate var _selRelationLabels: NSPopUpButton!
    @IBOutlet weak fileprivate var _prgBusyIndicator: NSProgressIndicator!
    @IBOutlet weak fileprivate var _btnGenerateList: NSButton!
    @IBOutlet weak fileprivate var _btnResetMailingList: NSButton!
    // MARK: end Properties
    
    // MARK: Data Members
    //
    // @desc: reference to the holiday card processor.
    //
    fileprivate var _hcp:HolidayCardProcessor!
    //
    // @desc: Dictionary of menu items. Used to map source & destination menu selections to the corresponding ContactSource
    //
    fileprivate var _mapMenuItems:Dictionary<uint, HolidayCardProcessor.ContactSource>!
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
        
        // Register for the notification events.
        let nc = NotificationCenter.default
        // Register for the "PermissionGranted" event.
        nc.addObserver(self, selector: #selector(InitializeUI), name: Notification.Name.CNPermissionGranted, object: nil)
        // Register for the "Enable Generate List Button" event.
        nc.addObserver(self, selector: #selector(EnableGenerateList), name: Notification.Name.HCEnableGenerateListBtn, object: self)
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
            (_selGroupDestination.selectedItem?.isEnabled)! &&
            (_selPostalAddressLabels.numberOfItems > 0) &&
            (_selRelationLabels.numberOfItems > 0))
        {
            // Start by disabling the generate list button to prevent ui re-entrancy
            _btnGenerateList.isEnabled = false
            
            // Get the names of the source & destination groups.
            let mnuSource:NSMenuItem? = _selGroupSource.selectedItem
            let source:String = GetIdentifierFromMenuItem(menuItem: mnuSource)
            let mnuDest:NSMenuItem? = _selGroupDestination.selectedItem
            let dest:String   = GetIdentifierFromMenuItem(menuItem: mnuDest)
            // Get the name of the postal address label to use for the mailing list.
            let address:String = _selPostalAddressLabels.titleOfSelectedItem!
            // Get the name of the related contact label to use for the mailing list.
            let name:String = _selRelationLabels.titleOfSelectedItem!
            
            // Generate the list. Perform the operation on a background thread.
            DispatchQueue.global(qos: .background).async
            {
                self._hcp.GenerateHolidayList(sourceId: source, addrSource: address, relatedNameSource: name, destinationId: dest)
                
                // Wait until the background operation finishes.
                DispatchQueue.main.async
                {
                    // Post a notification to update the enabled state of the Genrate List button
                    let updateGenLstBtn:Notification = Notification(name: Notification.Name.HCEnableGenerateListBtn, object: self, userInfo: nil)
                    NotificationCenter.default.post(updateGenLstBtn)
                }
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
        if ((_selGroupDestination.numberOfItems > 0) &&
            (_selGroupDestination.selectedItem?.isEnabled)!)
        {
            // Get menu item for the destination group that is currently selected.
            let mnuDest:NSMenuItem? = _selGroupDestination.selectedItem
            let groupId:String = GetIdentifierFromMenuItem(menuItem: mnuDest)
            // Find out how many "potential" contacts will be eliminated.
            let contacts:[CNContact] = _hcp.GetContactsFromSource(sourceId: groupId)
            
            // Don't worry about doing anything if there are no contacts in the group.
            if (contacts.count > 0)
            {
                // Ensure the user is aware of the potential consequences to their actions.
                // TODO: Use a subview to allow the user to see all of the contacts in the group. For now - just use an alertable message.
                let alert: NSAlert = NSAlert()
                alert.messageText = "There are \(contacts.count) contacts in group '\(_selGroupDestination.titleOfSelectedItem!)' that are about to be deleted."
                alert.alertStyle = .warning
                alert.informativeText = "Are you sure you want to contunue?"
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Proceed")
                // Pose the confirmation
                let response: NSApplication.ModalResponse = alert.runModal()
                // Only proceed if confirmed.
                if (response == .alertSecondButtonReturn)
                {
                    // Start by disabling the generate list button to prevent ui re-entrancy
                    _btnResetMailingList.isEnabled = false
                    
                    // Perform the operation on a background thread.
                    DispatchQueue.global(qos: .background).async
                    {
                        self._hcp.FlushAllGroupContacts(sourceId: groupId)
                        
                        // Wait until the background operation finishes.
                        DispatchQueue.main.async
                        {
                            // Re-enable the Reset button
                            self._btnResetMailingList.isEnabled = true
                        }
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
        // Disable the Generate List button. This will re-enable, if appropriate, after resetting the postal addresses & relation names
        _btnGenerateList.isEnabled = false
        
        // The source group has changed. Update the postal address labels.
        // @remark: This operation will be performed on a background thread. This needs to be accounted for when determining if the Generate List button should be enabled.
        resetPostalAddressOptions()
        // The source group has changed. Update the relation name labels.
        // @remark: This operation will be performed on a background thread. This needs to be accounted for when determining if the Generate List button should be enabled.
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
        _selPostalAddressLabels.isEnabled = false
        
        // Get the menu item for the selected source item
        let mnuItem:NSMenuItem? = _selGroupSource.selectedItem
        let identifier:String = GetIdentifierFromMenuItem(menuItem: mnuItem)
        if (!identifier.isEmpty)
        {
            // Start the busy indicator
            _prgBusyIndicator.startAnimation(self)
            
            // Populate the address labels
            // Especially when **ALL CONTACTS** was selected, this can
            // take some time. Perform the work on a background thread.
            // Perform the operation on a background thread.
            DispatchQueue.global(qos: .background).async
            {
                // Get the list of labels
                let postalLabels:[String] = self._hcp.GetPostalAddressLabels(sourceId: identifier)
            
                // Wait until the background operation finishes.
                DispatchQueue.main.async
                {
                    // Repopulate the labels
                    for label in postalLabels
                    {
                        self._selPostalAddressLabels.addItem(withTitle: label)
                    }
                    
                    // Update the access to the field
                    self._selPostalAddressLabels.isEnabled = (self._selPostalAddressLabels.numberOfItems > 0)

                    // Stop the busy indicator.
                    self._prgBusyIndicator.stopAnimation(self)
                    
                    // Post a notification to update the enabled state of the Genrate List button
                    let updateGenLstBtn:Notification = Notification(name: Notification.Name.HCEnableGenerateListBtn, object: self, userInfo: nil)
                    NotificationCenter.default.post(updateGenLstBtn)
                }
            }
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
        _selRelationLabels.isEnabled = false
        
        // Get the menu item for the selected source item
        let mnuItem:NSMenuItem? = _selGroupSource.selectedItem
        // Get the identifier from the ContactSource associated to the menu selection.
        let identifier:String = GetIdentifierFromMenuItem(menuItem: mnuItem)
        if (!identifier.isEmpty)
        {
            // Start the busy indicator
            _prgBusyIndicator.startAnimation(self)
            
            // Populate the address labels
            // Especially when **ALL CONTACTS** was selected, this can
            // take some time. Perform the work on a background thread.
            // Perform the operation on a background thread.
            DispatchQueue.global(qos: .background).async
            {
                // Get the list of labels
                let relatedNameLabels:[String] = self._hcp.GetRelatedNamesLabels(sourceId: identifier)
                
                // Wait until the background operation finishes.
                DispatchQueue.main.async
                {
                    // Repopulate the labels
                    for label in relatedNameLabels
                    {
                        self._selRelationLabels.addItem(withTitle: label)
                    }
                    
                    // Update the access to the field
                    self._selRelationLabels.isEnabled = (self._selRelationLabels.numberOfItems > 0)
                    
                    // Stop the busy indicator.
                    self._prgBusyIndicator.stopAnimation(self)
                    
                    // Post a notification to update the enabled state of the Genrate List button
                    let updateGenLstBtn:Notification = Notification(name: Notification.Name.HCEnableGenerateListBtn, object: self, userInfo: nil)
                    NotificationCenter.default.post(updateGenLstBtn)
                }
            }
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
        // Prefix for indenting groups in the source view list.
        let contactGroupPrefix:String = String("    ")
        
        // Stop the busy indicator
        _prgBusyIndicator.stopAnimation(self)
        
        // Create/Initialize the Holiday Card Processor
        _hcp = HolidayCardProcessor()
        
        // Create a map of menu items for name-to-identifier
        _mapMenuItems = Dictionary<uint, HolidayCardProcessor.ContactSource>()
        
        // Get the list of contact groups available.
        let contactSources:[HolidayCardProcessor.ContactSource] = _hcp.GetContactSources
        // Reset/Re-Populate the group selection lists.
        _selGroupSource.removeAllItems()
        _selGroupDestination.removeAllItems()
        // Start the tag count at 1 to avoid default values
        var tag:uint = 1
        for source in contactSources
        {
            // Skip Invalid source types
            if (source.type != HolidayCardProcessor.ContactSourceType.Invalid)
            {
                // Register this source in the menu item dictionary
                _mapMenuItems[tag] = source
                
                // All sources get added to the source list, but groups have the prefix added to the displayed name.
                let name:String = ((source.type == HolidayCardProcessor.ContactSourceType.Group) ? (contactGroupPrefix + source.name) : source.name)
                
                // Add the menu selections for the source list.
                _selGroupSource.addItem(withTitle: name)
                // Register the menu item with the dictionary via the tag
                if (_selGroupSource.lastItem != nil)
                {
                    _selGroupSource.lastItem?.tag = Int(tag)
                }

                // Add the menu selections for the destination list.
                _selGroupDestination.addItem(withTitle: name)
                // Register the menu item with the dictionary via the tag
                if (_selGroupDestination.lastItem != nil)
                {
                   _selGroupDestination.lastItem?.tag = Int(tag)
                    
                    // Disable this selection if this item was for a container.
                    _selGroupDestination.lastItem?.isEnabled = (source.type == HolidayCardProcessor.ContactSourceType.Group)
                    
                    // Hide this selection if this item is for the All Contacts.
                    _selGroupDestination.lastItem?.isHidden = (source.type == HolidayCardProcessor.ContactSourceType.AllContacts)
                }
                
                // Increment the tag for the next menu item.
                tag += 1
            }
        }
        
        // Ensure that the first "enabled" destination item is selected.
        for mnuItem:NSMenuItem in _selGroupDestination.itemArray
        {
            // Is this selection enabled?
            if (mnuItem.isEnabled)
            {
                // Select *this* item and quit.
                _selGroupDestination.select(mnuItem)
                break
            }
        }
        
        // Initialize the postal address options.
        resetPostalAddressOptions()
        
        // Initialize the contact relation options.
        resetRelationNameOptions()
        
        // Update the ui control elements
        _selGroupSource.isEnabled = (_selGroupSource.numberOfItems > 0)
        _selGroupDestination.isEnabled = (_selGroupDestination.numberOfItems > 0)
        _btnResetMailingList.isEnabled = (_selGroupDestination.numberOfItems > 0)
        EnableGenerateList()
        
        // Set focus to the generate button
        _btnGenerateList.becomeFirstResponder()
    }
    
    //
    // @desc:   Helper to enable/disable the generate list button on the ui
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the AppDelegate.
    //
    @objc fileprivate func EnableGenerateList() -> Void
    {
        // Enable/Disable the generate list button if wither the postal addresses or relation names are empty
        _btnGenerateList.isEnabled = ((_selGroupSource.numberOfItems > 0) && (_selRelationLabels.numberOfItems > 0) && (_selPostalAddressLabels.numberOfItems > 0))
    }
    
    //
    // @desc:   Helper to get the identifier to use with the Holiday Card Processor
    //
    // @param:  menuItem:    The menu seleciton item with the associated target.
    //
    // @return: Identifier string.
    //
    // @remarks:None
    //
    fileprivate func GetIdentifierFromMenuItem(menuItem:NSMenuItem?) -> String
    {
        var identifier:String = String()
        
        // Is the menu item valid
        if (menuItem != nil)
        {
            // Get the tag associated with the menu item
            let tag:uint = UInt32(menuItem!.tag)
            
            // Is the tag registered in the database?
            if (_mapMenuItems[tag] != nil)
            {
                identifier = (_mapMenuItems[tag]?.identifier)!
            }
        }
        
        return identifier
    }
    // MARK: end Private helper methods
}

