//
//  DataContentViewController.swift
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
class DataContentViewController: NSViewController
{
    // MARK: Constants, Enumerations, & Structures.
    //
    // @desc: String templates for displaying the selected contact counts.
    //
    fileprivate static let CONTACT_COUNT_UNKNOWN:String             = "----"
    fileprivate static let CONTACT_COUNT_FILTERED:String            = "<FILTERED_COUNT>"
    fileprivate static let CONTACT_COUNT_TOTAL:String               = "<TOTAL_COUNT>"
    fileprivate static let MATCHING_CONTACT_COUNT_TEMPLATE:String   = CONTACT_COUNT_FILTERED + " of " + CONTACT_COUNT_TOTAL
    fileprivate static let AFFECTED_CONTACT_COUNT_TEMPLATE:String   = CONTACT_COUNT_TOTAL
    //
    // @desc: Persistence Identification Strings.
    //
    fileprivate let PERSISTENCE_KEY_SOURCE_GROUP:String         = "Source.GroupId"
    fileprivate let PERSISTENCE_KEY_SOURCE_RELATION:String      = "Source.RelationId"
    fileprivate let PERSISTENCE_KEY_SOURCE_ADDRESS:String       = "Source.AddressId"
    fileprivate let PERSISTENCE_KEY_DESTINATION_GROUP:String    = "Destination.GroupId"

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
    //
    // @desc: Enumeration for segue identifiers to the Mailing List Preview
    //
    fileprivate enum MailingListSegueIds: String
    {
        case segueIdPreview = "mailingPreview"
        case segueIdError   = "mailingErrors"
        case segueIdReset   = "destinationReset"
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
    @IBOutlet fileprivate weak var _btnPreview: NSButton!
    @IBOutlet fileprivate weak var _btnViewErrors: NSButton!
    @IBOutlet fileprivate weak var _lblMatchingContactCountSource: NSTextField!
    @IBOutlet fileprivate weak var _lblAffectedContactCountDest: NSTextField!
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
    //
    // @desc: Cached Contact Counts
    fileprivate var _contactCounts:(sourceTotal:uint, sourceFiltered:uint, destTotal:uint) = (0, 0, 0)
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
        nc.addObserver(self, selector: #selector(DisableUI), name: Notification.Name.HCDisableUserInterface, object: nil)
        nc.addObserver(self, selector: #selector(ModeChange(notification:)), name: Notification.Name.HCModeChange, object: nil)
        nc.addObserver(self, selector: #selector(UpdateContactCounts), name: Notification.Name.HCUpdateContactCounts, object: nil)
    }
    
    //
    // @desc:   Class override for praparing to seque to another view controler
    //
    // @param:  segue:  The pending segue
    // @paramL  sender: The object initiating the event.
    //
    // @return: None
    //
    // @remarks:Used to preview the mailing list data
    //
    override func prepare(for segue: NSStoryboardSegue, sender: Any?)
    {
        var previewType:HolidayCardProcessor.ContactPreviewType = HolidayCardProcessor.ContactPreviewType.Unknown
        
        // Determine the preview type based on the segue being invoked.
        if (segue.identifier == NSStoryboardSegue.Identifier(rawValue: MailingListSegueIds.segueIdPreview.rawValue))
        {
            previewType = HolidayCardProcessor.ContactPreviewType.Preview
        }
        else if (segue.identifier == NSStoryboardSegue.Identifier(rawValue: MailingListSegueIds.segueIdError.rawValue))
        {
            previewType = HolidayCardProcessor.ContactPreviewType.Error
        }
        else if (segue.identifier == NSStoryboardSegue.Identifier(rawValue: MailingListSegueIds.segueIdReset.rawValue))
        {
            previewType = HolidayCardProcessor.ContactPreviewType.Reset
        }
        
        // Configure the Mailing List view controller.
        let vc:MailingListPreviewViewController? = segue.destinationController as? MailingListPreviewViewController
        if (vc != nil)
        {
            vc?.PreviewType = previewType
        }
        
        // Generate the preview data.
        // Note: This call will be performed on a background thread and should not be blocked.
        //       When the background task completes, the view controler will be notified of the
        //       data to be displayed.
        generateView(viewType: previewType)
    }
    // MARK: end Class overrides
    
    // MARK: Public Methods
    // MARK: end Public Methods
    
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
                    // Since the content of the destination group has changed, reset the counts prior to re-enabling the
                    // UI. This will result in the counts being re-evaluated.
                    self.ResetContactCounts()
                    
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
        let CONFITMATION_RESET      = NSApplication.ModalResponse.alertThirdButtonReturn
        let CONFIRMATION_PREVIEW    = NSApplication.ModalResponse.alertSecondButtonReturn
        let CONFIRMATION_CANCEL     = NSApplication.ModalResponse.alertFirstButtonReturn
        
        if ((_selContactDestination.numberOfItems > 0) &&
            (_selContactDestination.selectedItem?.isEnabled)!)
        {
            // Start by disabling the UI to prevent ui re-entrancy
            DisableUI()
            
            // Get menu item for the destination group that is currently selected.
            let mnuDest:NSMenuItem? = _selContactDestination.selectedItem
            let groupId:String = GetIdentifierFromMenuItem(menuItem: mnuDest)
            // Find out how many "potential" contacts will be eliminated, but do this
            // on a worker thread
            // Populate the address labels
            // Especially when **ALL CONTACTS** was selected, this can
            // take some time. Perform the work on a background thread.
            // Perform the operation on a background thread.
            DispatchQueue.global(qos: .background).async
            {
                // Determine the nubmer of contats in the destination.
                let contactCount = self._hcp.GetGontactCount(sourceId: groupId, addrSource: nil, relatedNameSource: nil).totalContacts

                // Wait until the background operation finishes.
                DispatchQueue.main.async
                {
                    // Post a notification to update the enabled state of the UI,
                    // we may well be re-disabling the UI depending on the users selection of proceed or not.
                    let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                    NotificationCenter.default.post(enableUI)
                    
                    // Don't worry about doing anything if there are no contacts in the group.
                    if (contactCount > 0)
                    {
                        // Ensure the user is aware of the potential consequences to their actions.
                        // Construct a basic alert message.
                        let alert: NSAlert = NSAlert()
                        let name:String = self.GetNameFromMenuItem(menuItem: mnuDest)
                        let verb:String = ((contactCount == 1) ? "is" : "are")
                        let contactPlurality = ((contactCount == 1) ? "" : "s")
                        alert.messageText = "There \(verb) \(contactCount) contact\(contactPlurality) in group '\(name)' that \(verb) about to be deleted."
                        alert.alertStyle = .warning
                        alert.informativeText = "How do you wish to proceed?"
                        alert.addButton(withTitle: "Cancel")
                        alert.addButton(withTitle: "Preview")
                        alert.addButton(withTitle: "Reset")
                        // Pose the confirmation
                        let response: NSApplication.ModalResponse = alert.runModal()
                        // Proceed based upon the users intention
                        switch (response)
                        {
                        case CONFITMATION_RESET, CONFIRMATION_PREVIEW:
                            switch (response)
                            {
                            case CONFITMATION_RESET:
                                // Perform the operation on a background thread.
                                DispatchQueue.global(qos: .background).async
                                {
                                    // Flush the selected group.
                                    self._hcp.FlushAllGroupContacts(sourceId: groupId)
                                    
                                    // Wait until the background operation finishes.
                                    DispatchQueue.main.async
                                    {
                                        // Since the content of the destination group has changed, reset the counts prior to re-enabling the
                                        // UI. This will result in the counts being re-evaluated.
                                        self.ResetContactCounts()
                                        
                                        // Post a notification to update the enabled state of the UI
                                        let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                                        NotificationCenter.default.post(enableUI)
                                    }
                                }
                                break
                                
                            case CONFIRMATION_PREVIEW:
                                // Issue a segue to preview the reset list
                                let segueId: NSStoryboardSegue.Identifier = NSStoryboardSegue.Identifier(MailingListSegueIds.segueIdReset.rawValue)
                                self.performSegue(withIdentifier: segueId, sender: self)
                                break
                                
                            default:
                                // Nothing to do
                                break
                            }
                            break
                            
                        case CONFIRMATION_CANCEL:
                            // Nothing to do
                            break
                            
                        default:
                            // Nothing to do
                            break
                        }
                    }
                }
            }
        }
    }
    
    //
    // @desc:   Handler for the doClick event of the Contact Source selection
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
            
            // Persist the new selection
            let defaults = UserDefaults.standard
            defaults.set(GetIdentifierFromMenuItem(menuItem: _selContactSource.selectedItem!), forKey: PERSISTENCE_KEY_SOURCE_GROUP)
            
            // Reset the contact count displays
            ResetContactCounts()
            
            // The source group has changed. Update the postal address labels.
            // @remark: This operation will be performed on a background thread. This needs to be accounted for when determining if the Generate List button should be enabled.
            resetPostalAddressOptions(selectedValue: _selPostalAddressLabels.titleOfSelectedItem)
            // The source group has changed. Update the relation name labels.
            // @remark: This operation will be performed on a background thread. This needs to be accounted for when determining if the Generate List button should be enabled.
            resetRelationNameOptions(selectedValue: _selRelationLabels.titleOfSelectedItem)
        }
    }
    
    //
    // @desc:   Handler for the doClick event of the Relation Name selection
    //
    // @param:  Not used
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func _selRelationName_doClick(_ sender: Any)
    {
        // Is there a change in the selection?
        if (_selRelationLabels.selectedTag() != _selectedItems.relation)
        {
            // Persist the new selection
            let defaults = UserDefaults.standard
            defaults.set(_selRelationLabels.titleOfSelectedItem, forKey: PERSISTENCE_KEY_SOURCE_RELATION)

            // Update the contact counts.
            ResetContactCounts()
            UpdateContactCounts()
        }
    }
    
    //
    // @desc:   Handler for the doClick event of the Postal Address selection
    //
    // @param:  Not used
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction fileprivate func _selPostalAddress_doClick(_ sender: Any)
    {
        // Is there a change in the selection?
        if (_selPostalAddressLabels.selectedTag() != _selectedItems.postal)
        {
            // Persist the new selection
            let defaults = UserDefaults.standard
            defaults.set(_selPostalAddressLabels.titleOfSelectedItem, forKey: PERSISTENCE_KEY_SOURCE_ADDRESS)

            // Update the contact counts.
            ResetContactCounts()
            UpdateContactCounts()
        }
    }
    
    //
    // @desc:   Handler for the doClick event of the Postal Address selection
    //
    // @param:  Not used
    //
    // @return: None
    //
    // @remarks:None
    //
    @IBAction func _selContactDestination_doClick(_ sender: Any)
    {
        // Is there a change in the selection?
        if (_selContactDestination.selectedTag() != _selectedItems.destination)
        {
            // Persist the new selection
            let defaults = UserDefaults.standard
            defaults.set(GetIdentifierFromMenuItem(menuItem: _selContactDestination.selectedItem!), forKey: PERSISTENCE_KEY_DESTINATION_GROUP)

            // Update the contact counts.
            ResetContactCounts()
            UpdateContactCounts()
        }
    }
    // MARK: end Action Handlers
    
    // MARK: Private helper methods
    //
    // @desc:   Helper to generate the view list for the Mailing List Preview and Mailing List Errors, and Destination Reset List
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    fileprivate func generateView(viewType:HolidayCardProcessor.ContactPreviewType)
    {
        // Validate that we can handle the view type requested.
        guard(viewType != HolidayCardProcessor.ContactPreviewType.Unknown) else
        {
            return
        }
        
        // Get the menu item for the contact list requst.
        let mnuItem:NSMenuItem? = ((HolidayCardProcessor.ContactPreviewType.Reset != viewType) ? _selContactSource.selectedItem : _selContactDestination.selectedItem)
        let sourceIdentifier:String = GetIdentifierFromMenuItem(menuItem: mnuItem)
        // Get the name of the postal address label to use for the mailing list.
        let address:String = ((HolidayCardProcessor.ContactPreviewType.Reset != viewType) ? _selPostalAddressLabels.titleOfSelectedItem! : String())
        // Get the name of the related contact label to use for the mailing list.
        let name:String = ((HolidayCardProcessor.ContactPreviewType.Reset != viewType) ? _selRelationLabels.titleOfSelectedItem! : String())
        
        // Start by disabling the UI to prevent ui re-entrancy
        DisableUI()
        
        // Populate the preview data
        // Especially when **ALL CONTACTS** was selected, this can
        // take some time. Perform the work on a background thread.
        DispatchQueue.global(qos: .background).async
        {
            // Get the preview data
            let mailingListPreview:[HolidayCardProcessor.ContactInfo] = self._hcp.GetMailingListPreview(previewType: viewType, sourceId: sourceIdentifier, addrSource: address, relatedNameSource: name)
            
            // Wait until the background operation finishes.
            DispatchQueue.main.async
            {                
                // Post a notification to update the enabled state of the UI
                let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                NotificationCenter.default.post(enableUI)
                
                // Update the preview view controller with the payload
                let data:[String:[HolidayCardProcessor.ContactInfo]] = [NotificationPayloadKeys.data.rawValue:mailingListPreview]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCPreviewDataReady, object: nil, userInfo: data)
            }
        }
    }
    // @desc:   Helper to reset the UI for the Postal Address selection
    //
    // @param:  selectedValue - Value used to attempt to restore, if possible.
    //
    // @return: None
    //
    // @remarks:None
    //
    fileprivate func resetPostalAddressOptions(selectedValue:String?) -> Void
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
    
                    // Attempt to select the specified restore
                    var value:String = String()
                    if (selectedValue != nil)
                    {
                        value = selectedValue!
                    }
                    else
                    {
                        value = self._selPostalAddressLabels.itemTitle(at: 0)
                    }
                    if (self._selPostalAddressLabels.itemTitles.contains(value))
                    {
                        self._selPostalAddressLabels.selectItem(withTitle: value)
                        
                        // Ensure thar the selection is persisted
                        let defaults = UserDefaults.standard
                        defaults.set(value, forKey: self.PERSISTENCE_KEY_SOURCE_ADDRESS)
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
    // @param:  selectedValue - Value used to attempt to restore, if possible.
    //
    // @return: None
    //
    // @remarks:None
    //
    fileprivate func resetRelationNameOptions(selectedValue:String?) -> Void
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
                    
                    // Attempt to select the specified restore
                    var value:String = String()
                    if (selectedValue != nil)
                    {
                        value = selectedValue!
                    }
                    else
                    {
                        value = self._selRelationLabels.itemTitle(at: 0)
                    }
                    if (self._selRelationLabels.itemTitles.contains(value))
                    {
                        self._selRelationLabels.selectItem(withTitle: value)
                        
                        // Ensure thar the selection is persisted
                        let defaults = UserDefaults.standard
                        defaults.set(value, forKey: self.PERSISTENCE_KEY_SOURCE_RELATION)
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
        
        // Reset the contact count data
        ResetContactCounts()
        
        // Disable the UI
        DisableUI()
        
        // Create/Initialize the Holiday Card Processor
        // Note: Calls made upon this object can be lengthy. It is recommend to perform all (or most anyway)
        //       calls on background worker threads.
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
        
        // Restore the selections
        restoreSelections()
        
        // Post a notification to update the enabled state of the UI
        let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
        NotificationCenter.default.post(enableUI)

        // Set focus to the generate button
        _btnGenerateList.becomeFirstResponder()
    }
    
    //
    // @desc:   Helper to react to mode changes.
    //
    // @param:  notification:   Variable data passed to the notification handler to indicate the new mode.
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the SideBar ViewController.
    //
    @objc fileprivate func ModeChange(notification:NSNotification) -> Void
    {
        // Get the new mode.
        let mode:SideBarViewController.SIDEBAR_MODE? = notification.userInfo?["mode"] as? SideBarViewController.SIDEBAR_MODE
        
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
            _btnResetMailingList.isEnabled = ((_selContactDestination.numberOfItems > 0) && (_contactCounts.destTotal > 0))

            // Enable/Disable the generate list button if either the postal addresses or relation names are empty or there are no matching contacts.
            _btnGenerateList.isEnabled = ((_selContactSource.numberOfItems > 0) && (_contactCounts.sourceFiltered > 0) && (_contactCounts.destTotal == 0) &&
                                          (_selRelationLabels.numberOfItems > 0) && (_selPostalAddressLabels.numberOfItems > 0))
            
            // Enable/Disable the View Errors button based on the source filtered and total counts matching.
            _btnViewErrors.isEnabled = (_contactCounts.sourceFiltered != _contactCounts.sourceTotal)
            
            // Enable/Disable the Preview button based on the source filtered count.
            _btnPreview.isEnabled = (_contactCounts.sourceFiltered > 0)
            
            // Refresh the selected items
            _selectedItems.source       = ((_selContactSource.numberOfItems > 0)        ? UInt32(_selContactSource.selectedTag()) : 0)
            _selectedItems.destination  = ((_selContactDestination.numberOfItems > 0)   ? UInt32(_selContactDestination.selectedTag()) : 0)
            _selectedItems.postal       = ((_selPostalAddressLabels.numberOfItems > 0)  ? UInt32(_selPostalAddressLabels.selectedTag()) : 0)
            _selectedItems.relation     = ((_selRelationLabels.numberOfItems > 0)       ? UInt32(_selRelationLabels.selectedTag()) : 0)
            
            _lblMatchingContactCountSource.isEnabled = true
            _lblAffectedContactCountDest.isEnabled = true

            // The UI is ready, stop the busy indicator
            _prgBusyIndicator.stopAnimation(self)
            
            // Post a notification to update the Contact Count displays
            let updateContactCountDisplays:Notification = Notification(name: Notification.Name.HCUpdateContactCounts, object: self, userInfo: nil)
            NotificationCenter.default.post(updateContactCountDisplays)
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
        _btnPreview.isEnabled = false
        _btnViewErrors.isEnabled = false
        
        _lblMatchingContactCountSource.isEnabled = false
        _lblAffectedContactCountDest.isEnabled = false
        
        // Increment the count of pending disable.
        _pendingDisableCount += 1
    }
    
    //
    // @desc:   Read-only helper to get the default string for the matching contact count displays
    //
    // @param:  None
    //
    // @return: Default count string
    //
    // @remarks:Used to know when UpdateContactCounts needs to do something and to reset/initialize the UI
    //
    fileprivate var DefaultMatchingContactCount: (String)!
    {
        get
        {
            // Specify the default value of the contact count display.
            var defaultDisplay:String = DataContentViewController.MATCHING_CONTACT_COUNT_TEMPLATE
            defaultDisplay = defaultDisplay.replacingOccurrences(of: DataContentViewController.CONTACT_COUNT_FILTERED, with: DataContentViewController.CONTACT_COUNT_UNKNOWN, options: .literal, range: nil)
            defaultDisplay = defaultDisplay.replacingOccurrences(of: DataContentViewController.CONTACT_COUNT_TOTAL, with: DataContentViewController.CONTACT_COUNT_UNKNOWN, options: .literal, range: nil)

            return defaultDisplay
        }
    }
    
    //
    // @desc:   Read-only helper to get the default string for the affected contact count displays
    //
    // @param:  None
    //
    // @return: Default count string
    //
    // @remarks:Used to know when UpdateContactCounts needs to do something and to reset/initialize the UI
    //
    fileprivate var DefaultAffectedContactCount: (String)!
    {
        get
        {
            // Specify the default value of the contact count display.
            var defaultDisplay:String = DataContentViewController.AFFECTED_CONTACT_COUNT_TEMPLATE
            defaultDisplay = defaultDisplay.replacingOccurrences(of: DataContentViewController.CONTACT_COUNT_TOTAL, with: DataContentViewController.CONTACT_COUNT_UNKNOWN, options: .literal, range: nil)
            
            return defaultDisplay
        }
    }
    
    //
    // @desc:   Helper to reset the display labels showing the contact counts.
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:
    //
    fileprivate func ResetContactCounts() -> Void
    {
        // Reset the matching contact display data
        _lblMatchingContactCountSource.stringValue  = DefaultMatchingContactCount
        _lblAffectedContactCountDest.stringValue    = DefaultAffectedContactCount
        
        // Reset the cached contact counts
        _contactCounts.sourceTotal      = 0
        _contactCounts.sourceFiltered   = 0
        _contactCounts.destTotal        = 0
    }
    
    //
    // @desc:   Helper to update the display labels showing the contact counts.
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    @objc  fileprivate func UpdateContactCounts() -> Void
    {
        if ((DefaultMatchingContactCount.caseInsensitiveCompare(_lblMatchingContactCountSource.stringValue) == .orderedSame) ||
            (DefaultAffectedContactCount.caseInsensitiveCompare(_lblAffectedContactCountDest.stringValue) == .orderedSame))
        {
            // Update the contact contact counts for the Source.
            // Get the menu item for the selected source item
            let sourceMenuItem:NSMenuItem? = _selContactSource.selectedItem
            // Get the identifier from the ContactSource associated to the menu selection.
            let sourceIdentifier:String = GetIdentifierFromMenuItem(menuItem: sourceMenuItem)
            // Get the selected postal address.
            let addressSource:String    = ((_selPostalAddressLabels.titleOfSelectedItem != nil) ? _selPostalAddressLabels.titleOfSelectedItem! : String())
            // Get the name of the related contact label to use for the mailing list.
            let nameSource:String       = ((_selRelationLabels.titleOfSelectedItem != nil) ? _selRelationLabels.titleOfSelectedItem! : String())
            
            // Get the menu item for the selected destination item
            let destMenuItem:NSMenuItem? = _selContactDestination.selectedItem
            // Get the identifier from the ContactSource associated to the menu selection.
            let destIdentifier:String = GetIdentifierFromMenuItem(menuItem: destMenuItem)
            
            // Perform the updates on a background thread.
            DisableUI()
            DispatchQueue.global(qos: .background).async
            {
                let sourceCounts:(totalContacts:uint, filteredContacts:uint) = self._hcp.GetGontactCount(sourceId: sourceIdentifier, addrSource: addressSource, relatedNameSource: nameSource)
                
                // Get the destination contact counts on a background worker thead
                let destCounts:(totalContacts:uint, filteredContacts:uint) = self._hcp.GetGontactCount(sourceId: destIdentifier, addrSource: nil, relatedNameSource: nil)
                
                // Wait until the background operation finishes.
                DispatchQueue.main.async
                {
                    // Record the contact counts
                    self._contactCounts.sourceTotal     = sourceCounts.totalContacts
                    self._contactCounts.sourceFiltered  = sourceCounts.filteredContacts
                    self._contactCounts.destTotal       = destCounts.totalContacts
                    
                    // Update the contact counts for the source.
                    var workerLabel:String = DataContentViewController.MATCHING_CONTACT_COUNT_TEMPLATE
                    workerLabel = workerLabel.replacingOccurrences(of: DataContentViewController.CONTACT_COUNT_FILTERED, with: String(self._contactCounts.sourceFiltered), options: .literal, range: nil)
                    workerLabel = workerLabel.replacingOccurrences(of: DataContentViewController.CONTACT_COUNT_TOTAL, with: String(self._contactCounts.sourceTotal), options: .literal, range: nil)
                    self._lblMatchingContactCountSource.stringValue = workerLabel
                    
                    // Update the contact counts for the destination.
                    workerLabel = DataContentViewController.AFFECTED_CONTACT_COUNT_TEMPLATE
                    workerLabel = workerLabel.replacingOccurrences(of: DataContentViewController.CONTACT_COUNT_TOTAL, with: String(self._contactCounts.destTotal), options: .literal, range: nil)
                    self._lblAffectedContactCountDest.stringValue = workerLabel

                    // Post a notification to update the enabled state of the UI
                    let enableUI:Notification = Notification(name: Notification.Name.HCEnableUserInterface, object: self, userInfo: nil)
                    NotificationCenter.default.post(enableUI)
                }
            }
        }
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
    
    //
    // @desc:   Helper to restore the user-selectable settings.
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
    fileprivate func restoreSelections() -> Void
    {
        let defaults = UserDefaults.standard

        // Restore the settings.
        let sourceContactGroup:String?      = defaults.string(forKey: PERSISTENCE_KEY_SOURCE_GROUP)
        let sourceContactAddress:String?    = defaults.string(forKey: PERSISTENCE_KEY_SOURCE_ADDRESS)
        let sourceContactRelation:String?   = defaults.string(forKey: PERSISTENCE_KEY_SOURCE_RELATION)
        let destContactGroup:String?        = defaults.string(forKey: PERSISTENCE_KEY_DESTINATION_GROUP)
        
        // Restore the destination.
        // ==============================================
        // Interate over the current menu selections.
        for mnuItem:NSMenuItem in _selContactDestination.itemArray
        {
            // Determine if this menu item matches the persisted one.
            let contactSrc:HolidayCardProcessor.ContactSource? = GetContactSourceFromMenuItem(menuItem: mnuItem)
            if (contactSrc != nil)
            {
                if ((destContactGroup == nil) ||
                    (destContactGroup?.compare((contactSrc?.identifier)!) == ComparisonResult.orderedSame))
                {
                    // Match found. Ensure that this menu item is enabled.
                    if (mnuItem.isEnabled)
                    {
                        // Ensure that this item is selected.
                        _selContactDestination.select(mnuItem)
                        break
                    }
                }
            }
        }
        
        // Restore the source group.
        // ==============================================
        if ((sourceContactGroup != nil) &&
            (!(sourceContactGroup?.isEmpty)!))
        {
            // Interate over the current menu selections.
            for mnuItem:NSMenuItem in _selContactSource.itemArray
            {
                // Determine if this menu item matches the persisted one.
                let contactSrc:HolidayCardProcessor.ContactSource? = GetContactSourceFromMenuItem(menuItem: mnuItem)
                if (contactSrc != nil)
                {
                    if (sourceContactGroup?.compare((contactSrc?.identifier)!) == ComparisonResult.orderedSame)
                    {
                        // Match found. Ensure that this menu item is enabled.
                        if (mnuItem.isEnabled)
                        {
                            // Ensure that this item is selected.
                            _selContactSource.select(mnuItem)
                            break
                        }
                    }
                }
            }
        }
        
        // Initialize the postal address options.
        resetPostalAddressOptions(selectedValue: sourceContactAddress)
        
        // Initialize the contact relation options.
        resetRelationNameOptions(selectedValue: sourceContactRelation)
    }
    // MARK: end Private helper methods
}
