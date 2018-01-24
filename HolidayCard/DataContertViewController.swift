//
//  DataContertViewController.swift
//  HolidayCard
//
//  Created by Michael Price on 1/14/18.
//  Copyright © 2018 GrumpTech. All rights reserved.
//

import Cocoa
import Contacts

//
// @desc: Controller for the data content view
//
class DataContertViewController: NSViewController
{
    // MARK: Constants, Enumerations, & Structures.
    //
    // @desc: Structure for storing the currently selected menu items.
    //
    fileprivate struct SelectedItems
    {
        var source:uint         = 0
        var destination:uint    = 0
        var postal:uint         = 0
        var relation:uint       = 0
    }
    // MARK: end Constants, Enumerations, & Structures
    
    // MARK: Properties
    // @desc: References to UI control elements
    @IBOutlet fileprivate weak var _prgBusyIndicator: NSProgressIndicator!
    @IBOutlet fileprivate weak var _viewSourceContent: NSView!
    @IBOutlet fileprivate weak var _viewDestinationContent: NSView!
    @IBOutlet fileprivate weak var _selContactSource: NSPopUpButton!
    @IBOutlet fileprivate weak var _selRelationLabels: NSPopUpButton!
    @IBOutlet fileprivate weak var _selPostalAddressLabels: NSPopUpButton!
    @IBOutlet fileprivate weak var _selContactDestination: NSPopUpButton!
    @IBOutlet fileprivate weak var _btnGenerateList: NSButton!
    @IBOutlet fileprivate weak var _btnResetMailingList: NSButton!
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
    //
    // @desc: Cache of selected items
    //
    fileprivate var _selectedItems:SelectedItems = SelectedItems()
    //
    // @desc: Count of currently queued disable/enable UI requests.
    fileprivate var _pendingDisableCount:uint = 0
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
        nc.addObserver(self, selector: #selector(EnableUI), name: Notification.Name.HCEnableUserInterface, object: nil)
        nc.addObserver(self, selector: #selector(ModeChange(_:)), name: Notification.Name.HCModeChange, object: nil)
    }
    // MARK: end Class overrides
    
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
        if ((_selContactSource.numberOfItems > 0) &&
            (_selContactDestination.numberOfItems > 0) &&
            (_selContactDestination.selectedItem?.isEnabled)! &&
            (_selPostalAddressLabels.numberOfItems > 0) &&
            (_selRelationLabels.numberOfItems > 0))
        {
            // Start by disabling the UI to prevent ui re-entrancy
            DisableUI()
            
            // Get the names of the source & destination groups.
            let mnuSource:NSMenuItem? = _selContactSource.selectedItem
            let source:String = GetIdentifierFromMenuItem(menuItem: mnuSource)
            let mnuDest:NSMenuItem? = _selContactDestination.selectedItem
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
                    // Post a notification to update the enabled state of the UI
                    let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                    NotificationCenter.default.post(enableUI)
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
        if ((_selContactDestination.numberOfItems > 0) &&
            (_selContactDestination.selectedItem?.isEnabled)!)
        {
            // Get menu item for the destination group that is currently selected.
            let mnuDest:NSMenuItem? = _selContactDestination.selectedItem
            let groupId:String = GetIdentifierFromMenuItem(menuItem: mnuDest)
            // Find out how many "potential" contacts will be eliminated.
            let contacts:[CNContact] = _hcp.GetContactsFromSource(sourceId: groupId)
            
            // Don't worry about doing anything if there are no contacts in the group.
            if (contacts.count > 0)
            {
                // Ensure the user is aware of the potential consequences to their actions.
                // TODO: Use a subview to allow the user to see all of the contacts in the group. For now - just use an alertable message.
                let alert: NSAlert = NSAlert()
                let name:String = GetNameFromMenuItem(menuItem: mnuDest)
                alert.messageText = "There are \(contacts.count) contacts in group '\(name)' that are about to be deleted."
                alert.alertStyle = .warning
                alert.informativeText = "Are you sure you want to contunue?"
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Proceed")
                // Pose the confirmation
                let response: NSApplication.ModalResponse = alert.runModal()
                // Only proceed if confirmed.
                if (response == .alertSecondButtonReturn)
                {
                    // Start by disabling the UI to prevent ui re-entrancy
                    DisableUI()
                    
                    // Perform the operation on a background thread.
                    DispatchQueue.global(qos: .background).async
                    {
                        self._hcp.FlushAllGroupContacts(sourceId: groupId)
                        
                        // Wait until the background operation finishes.
                        DispatchQueue.main.async
                        {
                            // Post a notification to update the enabled state of the UI
                            let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                            NotificationCenter.default.post(enableUI)
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
    @IBAction fileprivate func _selContactSource_doClick(_ sender: Any)
    {
        // Is there a change in the selection?
        if (_selContactSource.selectedTag() != _selectedItems.source)
        {
            // Change made.
            
            // The source group has changed. Update the postal address labels.
            // @remark: This operation will be performed on a background thread. This needs to be accounted for when determining if the Generate List button should be enabled.
            resetPostalAddressOptions()
            // The source group has changed. Update the relation name labels.
            // @remark: This operation will be performed on a background thread. This needs to be accounted for when determining if the Generate List button should be enabled.
            resetRelationNameOptions()
        }
    }
    // MARK: end Action Handlers
    
    // MARK: Private helper methods
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
        let mnuItem:NSMenuItem? = _selContactSource.selectedItem
        let identifier:String = GetIdentifierFromMenuItem(menuItem: mnuItem)
        if (!identifier.isEmpty)
        {
            // Start by disabling the UI to prevent ui re-entrancy
            DisableUI()

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
                        // Set the tag.
                        if (self._selPostalAddressLabels.lastItem != nil)
                        {
                            self._selPostalAddressLabels.lastItem?.tag = self._selPostalAddressLabels.numberOfItems
                        }
                    }
                    
                    // Post a notification to update the enabled state of the UI
                    let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                    NotificationCenter.default.post(enableUI)
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
        let mnuItem:NSMenuItem? = _selContactSource.selectedItem
        // Get the identifier from the ContactSource associated to the menu selection.
        let identifier:String = GetIdentifierFromMenuItem(menuItem: mnuItem)
        if (!identifier.isEmpty)
        {
            // Start by disabling the UI to prevent ui re-entrancy
            DisableUI()

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
                        // Set the tag.
                        if (self._selRelationLabels.lastItem != nil)
                        {
                            self._selRelationLabels.lastItem?.tag = self._selRelationLabels.numberOfItems
                        }
                    }
                    
                    // Post a notification to update the enabled state of the UI
                    let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                    NotificationCenter.default.post(enableUI)
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
        
        // Reset the count of pending disable requests.
        _pendingDisableCount = 0
        
        // Create/Initialize the Holiday Card Processor
        _hcp = HolidayCardProcessor()
        
        // Create a map of menu items for name-to-identifier
        _mapMenuItems = Dictionary<uint, HolidayCardProcessor.ContactSource>()
        
        // Get the list of contact groups available.
        let contactSources:[HolidayCardProcessor.ContactSource] = _hcp.GetContactSources
        // Reset/Re-Populate the group selection lists.
        _selContactSource.removeAllItems()
        _selContactDestination.removeAllItems()
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
                _selContactSource.addItem(withTitle: name)
                // Register the menu item with the dictionary via the tag
                if (_selContactSource.lastItem != nil)
                {
                    _selContactSource.lastItem?.tag = Int(tag)
                }
                
                // Add the menu selections for the destination list.
                _selContactDestination.addItem(withTitle: name)
                // Register the menu item with the dictionary via the tag
                if (_selContactDestination.lastItem != nil)
                {
                    _selContactDestination.lastItem?.tag = Int(tag)
                    
                    // Disable this selection if this item was for a container.
                    _selContactDestination.lastItem?.isEnabled = (source.type == HolidayCardProcessor.ContactSourceType.Group)
                    
                    // Hide this selection if this item is for the All Contacts.
                    _selContactDestination.lastItem?.isHidden = (source.type == HolidayCardProcessor.ContactSourceType.AllContacts)
                }
                
                // Increment the tag for the next menu item.
                tag += 1
            }
        }
        
        // Ensure that the first "enabled" destination item is selected.
        for mnuItem:NSMenuItem in _selContactDestination.itemArray
        {
            // Is this selection enabled?
            if (mnuItem.isEnabled)
            {
                // Select *this* item and quit.
                _selContactDestination.select(mnuItem)
                break
            }
        }
        
        // Initialize the postal address options.
        resetPostalAddressOptions()
        
        // Initialize the contact relation options.
        resetRelationNameOptions()
        
        // Attempt to enable the UI
        EnableUI()

        // Set focus to the generate button
        _btnGenerateList.becomeFirstResponder()
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
    
    //
    // @desc:   Helper to enable the UI elements
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the AppDelegate.
    //
    @objc fileprivate func EnableUI() -> Void
    {
        // Decrement the pending count
        if (_pendingDisableCount > 0)
        {
            _pendingDisableCount -= 1
        }
        
        // Are there any disable operations still pending?
        if (_pendingDisableCount == 0)
        {
            // All clear. Enable the UI
            
            _selContactSource.isEnabled = (_selContactSource.numberOfItems > 0)
            _selContactDestination.isEnabled = (_selContactDestination.numberOfItems > 0)
            _selRelationLabels.isEnabled = (_selRelationLabels.numberOfItems > 0)
            _selPostalAddressLabels.isEnabled = (_selPostalAddressLabels.numberOfItems > 0)
            _btnResetMailingList.isEnabled = (_selContactDestination.numberOfItems > 0)

            // Enable/Disable the generate list button if either the postal addresses or relation names are empty
            _btnGenerateList.isEnabled = ((_selContactSource.numberOfItems > 0) && (_selRelationLabels.numberOfItems > 0) && (_selPostalAddressLabels.numberOfItems > 0))
            
            // Refresh the selected items
            _selectedItems.source       = ((_selContactSource.numberOfItems > 0)        ? UInt32(_selContactSource.selectedTag()) : 0)
            _selectedItems.destination  = ((_selContactDestination.numberOfItems > 0)   ? UInt32(_selContactDestination.selectedTag()) : 0)
            _selectedItems.postal       = ((_selPostalAddressLabels.numberOfItems > 0)  ? UInt32(_selPostalAddressLabels.selectedTag()) : 0)
            _selectedItems.relation     = ((_selRelationLabels.numberOfItems > 0)       ? UInt32(_selRelationLabels.selectedTag()) : 0)

            // The UI is ready, stop the busy indicator
            _prgBusyIndicator.stopAnimation(self)
        }
    }
    
    //
    // @desc:   Helper to disable the generate list button on the ui
    //
    // @param:  None
    //
    // @return: None
    //
    @objc fileprivate func DisableUI() -> Void
    {
        // If we are disabling the UI, it is because we are busy.
        _prgBusyIndicator.startAnimation(self)
        
        _selContactSource.isEnabled = false
        _selContactDestination.isEnabled = false
        _selRelationLabels.isEnabled = false
        _selPostalAddressLabels.isEnabled = false
        _btnResetMailingList.isEnabled = false
        _btnGenerateList.isEnabled = false
        
        // Increment the count of pending disable.
        _pendingDisableCount += 1
    }
    
    //
    // @desc:   Helper to get the ContactSource to use with the Holiday Card Processor
    //
    // @param:  menuItem:    The menu seleciton item with the associated target.
    //
    // @return: ContactSource item associated with this menu item. nil if there there is not a matching item registered,
    //
    // @remarks:None
    //
    fileprivate func GetContactSourceFromMenuItem(menuItem:NSMenuItem?) -> HolidayCardProcessor.ContactSource?
    {
        var source:HolidayCardProcessor.ContactSource? = nil
        
        // Is the menu item valid
        if (menuItem != nil)
        {
            // Get the tag associated with the menu item
            let tag:uint = UInt32(menuItem!.tag)
            
            // Just set the return. If there is not a match, then the
            // value assigned will be nil
            source = _mapMenuItems[tag]
        }
        
        return source
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
        
        let source:HolidayCardProcessor.ContactSource? = GetContactSourceFromMenuItem(menuItem: menuItem)
        
        // Is the menu item valid
        if (source != nil)
        {
            // Get the identifuer from the source item.
            identifier = source!.identifier
        }
        
        return identifier
    }
    
    //
    // @desc:   Helper to get the name to use with the Holiday Card Processor
    //
    // @param:  menuItem:    The menu seleciton item with the associated target.
    //
    // @return: Identifier string.
    //
    // @remarks:None
    //
    fileprivate func GetNameFromMenuItem(menuItem:NSMenuItem?) -> String
    {
        var name:String = String()
        
        let source:HolidayCardProcessor.ContactSource? = GetContactSourceFromMenuItem(menuItem: menuItem)
        
        // Is the menu item valid
        if (source != nil)
        {
            // Get the identifuer from the source item.
            name = source!.name
        }
        
        return name
    }
    // MARK: end Private helper methods
}
