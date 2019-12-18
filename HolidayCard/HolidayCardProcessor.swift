//
//  @class:          HolidayCardProcessor.swift
//  @application:    HolidayCard
//
//  Created by Michael Price on 12/23/17.
//  Copyright © 2017 GrumpTech. All rights reserved.
//
//  @desc:          Responsible for managing integration with the Contacts database
//                  for the purpose of generating a "Holiday Card" mailing list.
//
//                  This utility class assumes the following:
//                  1. Users are responsible for backing up their contacts database prior to
//                     using this tool.
//                  2. Consuming objects are aware of the fact that many of the services provided by
//                     this class can result in lengthy operations. It is, therefore, recommended that
//                     calls made upon this class are done on background worker threads, unless the
//                     developer has verified that the call does not result in a lengthy execution time.
//
import Foundation
import Contacts

//
// Description: Class responsible for managing contacts database for the purpose of
//              generating a "Holiday Card" mailling list.
//
class HolidayCardProcessor : NSObject
{
    // MARK: Constants, Enumerations, & Structures for the class.
    //
    // @desc: Constant to serve as the identifier for the ** All Contacts ** source
    //
    fileprivate let ALL_CONTACTS_SOURCE_ID:String = "**ALL_CONTACTS**"
    //
    // @desc: Constant to serve as the name for the ** All Contacts ** source
    //
    fileprivate let ALL_CONTACTS_NAME:String = "All Contacts"   // TODO: Support localization

    //
    // @desc: Enumeration specifying the type of contact source.
    //
    enum ContactSourceType:Int
    {
        case Invalid     = -1
        case AllContacts = 0
        case Container   = 1
        case Group       = 2
    }
    //
    // @desc: Enumeration for specifying the preview type
    //
    enum ContactPreviewType:Int
    {
        case Unknown    = -1
        case Preview    = 0
        case Error      = 1
        case Reset      = 2
    }
    //
    // @desc: Structure specifying the data representing a contact source.
    //
    struct ContactSource
    {
        var name:String             = String()
        var identifier:String       = String()
        var type:ContactSourceType  = ContactSourceType.Invalid
    }
    //
    // @desc: Structure for mailing list preview and error reports
    //
    struct ContactInfo
    {
        var contactName:String      = String()
        var mailingName:String      = String()
        var mailingAddr:String      = String()
    }
    // MARK: end Constants, Enumerations, & Structures
    
    // MARK: Data members
    // MARK: end Data members
    
    // MARK: Public interface
    // MARK: -- Public methods
    //
    // Description: Helper to check for permission
    //
    // Arguments:   None
    //
    // Return:      true if permission is granted.
    //
    // Remarks:     This method will block, waiting for the user to respond, when the current permission is set to "Not Defined"
    //
    func determinePermission() -> Bool
    {
        var permissionStatus: (permissionGranted:Bool, alertable:Bool) = self.IsContactPermissionGranted!

        // Has permission to access the contacts database been granted?
        if (!permissionStatus.permissionGranted)
        {
            // Not granted.
            if (permissionStatus.alertable)
            {
                var waitingForResponse:Bool = true
                
                // Permission Not Granted,
                // But we can request it....
                let contactStore = CNContactStore()
                // This is done on a background thread.
                contactStore.requestAccess(for: .contacts, completionHandler:{ (success, error) in
                    permissionStatus.permissionGranted = success && (error == nil)
                    
                    // Done waiting.
                    waitingForResponse = false
                })
                
                // Block!!: Wait until the user has responded.
                while (waitingForResponse)
                {
                    // Do nothing.
                }
            }
        }

        return permissionStatus.permissionGranted
    }
    
    //
    // @desc:   Clear the "destination" contact group
    //
    // @param:  sourceId - Identifier of the group to be flushed.
    //
    // @return: None
    //
    // @remarks:Assumes that the destination group is only used to store the "modified"
    // @remarks:Contacts for the purpose of printing address labels.
    //
    func FlushAllGroupContacts(sourceId: String) -> Void
    {
        let sourceType:ContactSourceType = GetContactSourceType(sourceId: sourceId)
        if (ContactSourceType.Group == sourceType)
        {
            let contactsToDelete:[CNContact] = GetContactsFromSource(sourceId: sourceId)
            
            guard (contactsToDelete.count > 0) else
            {
                // Nothing to do.
                return
            }
            
            // Construct a request to delete all of the items in the
            let requestToDelete = CNSaveRequest()
            for contact:CNContact in contactsToDelete
            {
                // Request to delete.
                requestToDelete.delete(contact.mutableCopy() as! CNMutableContact)
            }
            
            // Perform the deletion.
            do
            {
                let contactStore = CNContactStore()
                try contactStore.execute(requestToDelete)
            } catch let error
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to flush contacts. Err:" + error.localizedDescription
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            }
        }
        else if (ContactSourceType.Invalid != sourceType)
        {
            // Inappropriate source id was passed in.
            // Get the stack trace
            var stackTrace:String = "Stack Trace:"
            Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
            
            let errDesc:String = "FlushContacts() does not accept selections other than Groups."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
        }
    }
    
    //
    // @desc:   Helper to initiate a backup of all contacts.
    //
    // @param:  backupPath: Path to use for the backup location.
    //
    // @return: true if successful
    //
    // @remarks:Backup is a VCard file for all contacts.
    // @remarks:File is stored in the user sandbox in a file named Backup.vcf
    //
    func BackupContacts(backupPath:URL) -> Bool
    {
        var success:Bool = false
        
        // Ensure that the backup path is valid
        var isDirectory:ObjCBool = ObjCBool(false)
        let fileExists = FileManager.default.fileExists(atPath: backupPath.relativePath, isDirectory: &isDirectory)
        if (fileExists && isDirectory.boolValue)
        {
            // List of contacts
            var backupList:[CNContact] = [CNContact]()
            
            // Build a list of contacts.
            do
            {
                let contactStore = CNContactStore()
                // All the keys for querying for the contact backup.
                let keys = [CNContactVCardSerialization.descriptorForRequiredKeys()]
                
                // Create a fetch request for all contacts (non-unified)
                let fetch:CNContactFetchRequest = CNContactFetchRequest(keysToFetch: keys)
                fetch.mutableObjects = false
                fetch.unifyResults = false
                
                // Get all of the contacts and construct a list.
                try contactStore.enumerateContacts(with: fetch, usingBlock: { (contact, stop) in
                    backupList.append(contact)
                })
                // Validate that there are contacts to backup.
                guard (backupList.count > 0) else
                {
                    return false
                }
                
                // Serialize the list of contacts to data for backup storage.
                let data:Data = try CNContactVCardSerialization.data(with: backupList)
                
                // Build a fully qualified path for the backup file.
                var filePath:URL = backupPath.appendingPathComponent("Backup", isDirectory: false)
                filePath = filePath.appendingPathExtension("vcf")
                
                // Write the backup file as an atomic operation.
                try data.write(to: filePath, options: Data.WritingOptions.atomic)
                success = true
            }
            catch let error
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to generate contact database backup. Err:" + error.localizedDescription
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
                
                success = false
            }
        }
        
        return success
    }
    
    //
    // @desc:   Preview the list mailing list
    //
    // @param:  previewType       - Type of preview report
    // @param:  sourceId          - Identifier of the source providing contact data for the holiday mailing list.
    // @param:  addrSource        - Label for the postal address to use for generating the mailing list.
    // @param:  relatedNameSource - Label for the related name to use for generating the mailing list.
    //
    // @return: Array of ContactInfo structs representing the mailing list info
    //
    // @remarks:None
    //
    func GetMailingListPreview(previewType:ContactPreviewType,  sourceId: String, addrSource: String, relatedNameSource: String) -> [ContactInfo]
    {
        var mailingList:[ContactInfo] = [ContactInfo]()
        
        // Get the list
        let contactList:[CNContact] = GetFilteredContacts(sourceId: sourceId, addrSource: addrSource, relatedNameSource: relatedNameSource, valid: (ContactPreviewType.Preview == previewType))
        for contact:CNContact in contactList
        {
            var contactName:String = contact.familyName
            if (!contact.givenName.isEmpty)
            {
                contactName += ", " + contact.givenName
            }
            // If the name is empty, it is probably a general corporation.
            if (contactName.isEmpty &&
                (contact.contactType == CNContactType.organization))
            {
                contactName = contact.organizationName
            }
            
            var mailingName:String = String("* Missing *")
            for relation:CNLabeledValue<CNContactRelation> in contact.contactRelations
            {
                if (relation.label?.caseInsensitiveCompare(relatedNameSource) == .orderedSame)
                {
                    mailingName = relation.value.name
                    break
                }
            }
            
            var mailingAddress:String = String("* Missing *")
            for address:CNLabeledValue<CNPostalAddress> in contact.postalAddresses
            {
                if (address.label?.caseInsensitiveCompare(addrSource) == .orderedSame)
                {
                    mailingAddress = address.value.street + ", " + address.value.city + ", " + address.value.state + ", " + address.value.postalCode
                    break
                }
            }
            
            let newItem:ContactInfo = ContactInfo(contactName: contactName, mailingName: mailingName, mailingAddr: mailingAddress)
            mailingList.append(newItem)
        }
        
        return mailingList
    }
    
    //
    // @desc:   Generate a list of contacts for printing holiday card addresses
    //
    // @param:  sourceId          - Identifier of the source providing contact data for the holiday mailing list.
    // @param:  addrSource        - Label for the postal address to use for generating the mailing list.
    // @param:  relatedNameSource - Label for the related name to use for generating the mailing list.
    // @param:  destinationId     - Identifier of the destination of the holiday mailing list. ** MUST be a Group!!
    //
    // @return: None
    //
    // @remarks:None
    //
    func GenerateHolidayList(sourceId: String, addrSource: String, relatedNameSource: String, destinationId: String) -> Void
    {
        let contactStore = CNContactStore()
        
        // Ensure that the destination refers to a group
        guard (GetContactSourceType(sourceId: destinationId) == ContactSourceType.Group) else
        {
            let errDesc:String = "GenerateHolidayList - Destination must refer to a group."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            
            return
        }
        
        // Ensure that the source and destination are indeed different.
        guard (sourceId.caseInsensitiveCompare(destinationId) != .orderedSame) else
        {
            let errDesc:String = "GenerateHolidayList - Source & Destination are the same."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            
            return
        }
        
        // Ensure that the destination list does not already exist.
        guard (GetContactsFromSource(sourceId: destinationId).count == 0) else
        {
            let errDesc:String = "GenerateHolidayList -Destination needs to be flushed."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            
            return
        }
        
        // Ensure that there are contacts to put into the list.
        let holidayList:[CNContact] = GetHolidayList(sourceId: sourceId, addrSource: addrSource, relatedNameSource: relatedNameSource, valid: true)
        guard (holidayList.count > 0) else
        {
            let errDesc:String = "GenerateHolidayList - No contacts to build a list from."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            
            return
        }
        
        // Get the id of the container housing the "destination" group.
        var holidayContainerId:String = String()
        do
        {
            let predContainer:NSPredicate = CNContainer.predicateForContainerOfGroup(withIdentifier: destinationId)
            let containers:[CNContainer] = try contactStore.containers(matching: predContainer)
            guard (containers.count == 1) else
            {
                let errDesc:String = "GenerateHolidayList - Wrong number of matching containers."
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
                return
            }
            
            // Get the identifier
            holidayContainerId = containers[0].identifier
        }
        catch
        {
            // Get the stack trace
            var stackTrace:String = "Stack Trace:"
            Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
            
            let errDesc:String = "Unable to get the specified source contact container."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
        }
        
        // Get the group for the destination id.
        // Get the id of the container housing the "destination" group.
        var grpHolidayGroup:CNGroup? = nil
        do
        {
            let matchingGroups:[String] = [destinationId]
            let predGroup:NSPredicate = CNGroup.predicateForGroups(withIdentifiers: matchingGroups)
            let groups:[CNGroup] = try contactStore.groups(matching: predGroup)
            guard (groups.count == 1) else
            {
                let errDesc:String = "GenerateHolidayList - Wrong number of matching destination groups."
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
                return
            }
            
            // Get the identifier
            grpHolidayGroup = groups[0]
        }
        catch
        {
            // Get the stack trace
            var stackTrace:String = "Stack Trace:"
            Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
            
            let errDesc:String = "Unable to get the specified source contact container."
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
        }
        
        // Construct a request to (1) create the new/modified contact and (2) add all of the items in the Holiday Destination group
        let requestToCreate = CNSaveRequest()
        for contact:CNContact in holidayList
        {
            // Create the contact within the same container as the destination group.
            let mutableContact:CNMutableContact = contact.mutableCopy() as! CNMutableContact
            requestToCreate.add(mutableContact, toContainerWithIdentifier: holidayContainerId)
            // Add the contact to the holiday destination group.
            requestToCreate.addMember(contact, to: grpHolidayGroup!)
        }
        
        // Perform the Update.
        do
        {
            try contactStore.execute(requestToCreate)
        } catch let error
        {
            // Get the stack trace
            var stackTrace:String = "Stack Trace:"
            Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
            
            let errDesc:String = "Unable to generate mailing list. Err:" + error.localizedDescription
            let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
            
            // Post the error for reporting.
            let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
            let nc:NotificationCenter = NotificationCenter.default
            nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
        }
    }
    
    //
    // @desc:   Gets a list of postal addresses found in the contacts specifed by the source.
    //
    // @param:  sourceId: Identifier of the source of contacts.
    //
    // @return: List of postal address labels.
    //
    // @remarks:None
    //
    func GetPostalAddressLabels(sourceId:String) -> [String]
    {
        var labels:[String] = [String]()
        
        // Get the contents of the specified group.
        let contacts:[CNContact] = GetContactsFromSource(sourceId: sourceId)
        for contact:CNContact in contacts
        {
            // get all of the postal addresses in the contact.
            for address:CNLabeledValue<CNPostalAddress> in contact.postalAddresses
            {
                // Is this a "new" & valid address label?
                let localizedLabel:String = CNLabeledValue<CNPostalAddress>.localizedString(forLabel: address.label!).lowercased()
                if (!localizedLabel.isEmpty &&
                    !labels.contains(localizedLabel))
                {
                    // Add to the list.
                    labels.append(localizedLabel)
                }
            }
        }
   
        // Sort the list
        if (labels.count > 0)
        {
            labels.sort(by: {$0.caseInsensitiveCompare($1) == ComparisonResult.orderedAscending})
        }
        
        return labels
    }
    
    //
    // @desc:   Gets a list of related names found in the contacts specifed by the source.
    //
    // @param:  sourceId: Identifier of the source of contacts.
    //
    // @return: List of related name labels.
    //
    // @remarks:None
    //
    func GetRelatedNamesLabels(sourceId:String) -> [String]
    {
        var labels:[String] = [String]()
        
        // Get the contents of the specified group.
        let contacts:[CNContact] = GetContactsFromSource(sourceId: sourceId)
        for contact:CNContact in contacts
        {
            // get all of the postal addresses in the contact.
            for relation:CNLabeledValue<CNContactRelation> in contact.contactRelations
            {
                // Is this a "new" & valid contact relation label?
                let localizedLabel:String = CNLabeledValue<CNContactRelation>.localizedString(forLabel: relation.label!).lowercased()
                if (!localizedLabel.isEmpty &&
                    !labels.contains(localizedLabel))
                {
                    // Add to the list.
                    labels.append(localizedLabel)
                }
            }
        }
        
        // Sort the list
        if (labels.count > 0)
        {
            labels.sort(by: {$0.caseInsensitiveCompare($1) == ComparisonResult.orderedAscending})
        }
        
        return labels
    }
    
    //
    // @desc:   Gets a the number of contacts based on the information provided
    //
    // @param:  sourceId:           *required* Identifier of the source of contacts. Used to provice the total number of contacts.
    // @param:  addrSource:         *optional* Label for the postal address used for filtering the contacts.
    // @param:  relatedNameSource:  *optional* Label for the relation name used for filtering the contacts.
    //
    // @return: Tupple - total number of contacts in the source, number of contacts in the source with matching postal address and relation name entries.
    //
    // @remarks:None
    //
    func GetGontactCount(sourceId:String, addrSource: String?, relatedNameSource: String?) -> (totalContacts: uint, filteredContacts: uint)
    {
        var total:uint      = 0
        var filtered:uint   = 0
        
        // Get the list of contacts for the source specified
        let contactList:[CNContact] = GetContactsFromSource(sourceId: sourceId)
        
        // Set the total number of contacts
        total = UInt32(contactList.count)
        
        // Determine the number of contacts with in this list that
        // have a matching postal address and relation name entries.
        if (total > 0)
        {
            // If there is no filtering, then set the filtered count to be the same as the total
            if ((addrSource == nil) && (relatedNameSource == nil))
            {
                filtered = total
            }
            else
            {
                let filteredContactList:[CNContact] = GetFilteredContacts(sourceId: sourceId, addrSource: addrSource!, relatedNameSource: relatedNameSource!, valid: true)
                filtered = UInt32(filteredContactList.count)
            }
        }
        
        return (total, filtered)
    }
    // MARK: -- end Public methods

    // MARK: -- Public properties
    //
    // @desc: Read-only property accessor to determine if permission to access the contacts database has been granted.
    //
    // @paeam:  None
    //
    // @eeturn: Tuple -
    //              permissionGranted:  true if permission to the contacts database has been authorized.
    //              alertable:          true if permission has not been authorized but simply requires the user to manually grant access.
    //
    // @remark: To reset the privacy permissions, use terminal to execute: tccutil reset AddressBook
    //
    var IsContactPermissionGranted: (permissionGranted: Bool, alertable: Bool)!
    {
        get
        {
            let authStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
            
            let permissionAuthorized = (authStatus == CNAuthorizationStatus.authorized)
            let permissionAlertable = !permissionAuthorized && (authStatus != CNAuthorizationStatus.denied)

            return (permissionAuthorized, permissionAlertable)
        }
    }
    
    //
    // @desc:   Read-Only property providing a list of contact containers in the database
    //
    // @param:  None
    //
    // @return: List of contact sources
    //
    // @remarks:The list is a hierarchial listing of containers & groups. i.e. all groups are owned in the container above them.
    //
    var GetContactSources: [ContactSource]!
    {
        get
        {
            var containers:[ContactSource] = [ContactSource]()
            let contactStore = CNContactStore()
            
            // Always append ** All Contacts ** as the very first item.
            // Even when there are no contacts this is a valid selection.
            let allContacts:ContactSource = ContactSource(name: ALL_CONTACTS_NAME, identifier: ALL_CONTACTS_SOURCE_ID, type: ContactSourceType.AllContacts)
            containers.append(allContacts)
            
            do
            {
                let containerList:[CNContainer] = try contactStore.containers(matching: nil)
                
                for container:CNContainer in containerList
                {
                    // Append the container to the list
                    let itemContainer:ContactSource = ContactSource(name: container.name, identifier: container.identifier, type: ContactSourceType.Container)
                    containers.append(itemContainer)
                    
                    // Get any groups contained within this container.
                    let groupList:[CNGroup] = try contactStore.groups(matching: CNGroup.predicateForGroupsInContainer(withIdentifier: container.identifier))
                    // Append the groups to the list.
                    for group:CNGroup in groupList
                    {
                        let itemGroup:ContactSource = ContactSource(name: group.name, identifier: group.identifier, type: ContactSourceType.Group)
                        containers.append(itemGroup)
                    }
                }
            }
            catch let error
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to get the contact containers. Err:" + error.localizedDescription
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            }

            
            return containers
        }
    }
    // MARK: -- end Public properties

    // MARK: Private methods & properties
    //
    // @desc: Generates a list of contacts matching the filter data provided.
    //
    // @param: sourceId          - Identifier of the source providing contact data for the holiday mailing list.
    // @param: addrSource        - Label for the postal address to use for generating the mailing list.
    // @param: relatedNameSource - Label for the related name to use for generating the mailing list.
    // @param: valid             - Flag to indicate if the list is for valid contacts or contacts with errors.
    //
    // Return:      list of immutable CNContacts
    //
    // Remarks:     None
    //
    private func GetFilteredContacts(sourceId: String, addrSource: String, relatedNameSource: String, valid: Bool) -> [CNContact]!
    {
        var filteredList:[CNContact] = [CNContact]()
        
        // Get the requested source list for the holiday contacts
        let sourceContacts:[CNContact] = GetContactsFromSource(sourceId: sourceId)
        
        // Iterate through the list of contacts and create a modified
        // list suitable for label printing.
        for contact:CNContact in sourceContacts
        {
            var filteredRelatedName: String = String()
            var filteredAddress: CNLabeledValue<CNPostalAddress> = CNLabeledValue<CNPostalAddress>.init(label: nil, value: CNPostalAddress())
            for name:CNLabeledValue<CNContactRelation> in contact.contactRelations
            {
                if (name.label?.caseInsensitiveCompare(relatedNameSource) == .orderedSame)
                {
                    filteredRelatedName = name.value.name
                    break
                }
            }
            for address:CNLabeledValue<CNPostalAddress> in contact.postalAddresses
            {
                if (address.label?.caseInsensitiveCompare(addrSource) == .orderedSame)
                {
                    filteredAddress = address
                    break
                }
            }
            
            if  // Valid contacts.
                ((valid &&
                    ((filteredRelatedName.isEmpty == !valid) && (filteredAddress.value.street.isEmpty == !valid) && (filteredAddress.value.city.isEmpty == !valid))) ||
                    // Error candidates
                    (!valid &&
                        ((filteredRelatedName.isEmpty == !valid) || (filteredAddress.value.street.isEmpty == !valid) || (filteredAddress.value.city.isEmpty == !valid))))
            {
                filteredList.append(contact)
            }
        }
        
        return filteredList
    }

    //
    // @desc: Generates a list of immutable Holiday Contacts
    //
    // @param: sourceId          - Identifier of the source providing contact data for the holiday mailing list.
    // @param: addrSource        - Label for the postal address to use for generating the mailing list.
    // @param: relatedNameSource - Label for the related name to use for generating the mailing list.
    // @param: valid             - Flag to indicate if the list is for valid contacts or contacts with errors.
    //
    // Return:      list of immutable CNContacts
    //
    // Remarks:     None
    //
    private func GetHolidayList(sourceId: String, addrSource: String, relatedNameSource: String, valid: Bool) -> [CNContact]!
    {
        var holidayList:[CNMutableContact] = [CNMutableContact]()
        
        // Get the requested source list for the holiday contacts
        let holidayContacts:[CNContact] = GetFilteredContacts(sourceId: sourceId, addrSource: addrSource, relatedNameSource: relatedNameSource, valid: valid)
        
        // Iterate through the list of holiday contacts and create a modified
        // list suitable for label printing.
        for contact:CNContact in holidayContacts
        {
            // Note: Theee is no need to check the validity of this contact. This was validated in the call to GetFilteredContacts()
            
            // Generate a new contact that is friendly to Holiday Card Mailing Lists.
            let newContact:CNMutableContact = CNMutableContact()
            newContact.contactType = CNContactType.person

            // Get the family name to use for this contact
            for name:CNLabeledValue<CNContactRelation> in contact.contactRelations
            {
                if (name.label?.caseInsensitiveCompare(relatedNameSource) == .orderedSame)
                {
                    newContact.familyName = name.value.name
                    break
                }
            }
            // Get the postal address to use for this contact.
            for address:CNLabeledValue<CNPostalAddress> in contact.postalAddresses
            {
                if (address.label?.caseInsensitiveCompare(addrSource) == .orderedSame)
                {
                    newContact.postalAddresses.append(address)
                    break
                }
            }
            
            holidayList.append(newContact)
        }
        
        return holidayList as [CNContact]
    }
    
    //
    // @desc:   Retrieves a list of contacts for the group specified.
    //
    // @param:  sourceId - Identifier of the desired source for the contacts. Possibilities are a group or container.
    //
    // @return: List of contacts
    //
    // @remarks:None
    //
    fileprivate func GetContactsFromSource(sourceId: String) -> [CNContact]
    {
        var contactList:[CNContact] = [CNContact]()
        
        var contactPredicates:[NSPredicate] = [NSPredicate]()
        // Determine the appropriate predicate for getting the reqursted contacts?
        let sourceType:ContactSourceType = GetContactSourceType(sourceId: sourceId)
        
        switch sourceType
        {
        case ContactSourceType.Container:
            // Source Id is for a singla container.
            let pred:NSPredicate = CNContact.predicateForContactsInContainer(withIdentifier: sourceId)
            contactPredicates.append(pred)
            break
            
        case ContactSourceType.Group:
            // Source Id is for a single group.
            let pred:NSPredicate = CNContact.predicateForContactsInGroup(withIdentifier: sourceId)
            contactPredicates.append(pred)
            break
            
        case ContactSourceType.AllContacts:
            // Source Id is for ALL Containers.
            let contactStore = CNContactStore()
            do
            {
                // Get a list of all of the containers.
                let containerList:[CNContainer] = try contactStore.containers(matching: nil)
                
                // Build a list of predicates for each container.
                for container:CNContainer in containerList
                {
                    let pred:NSPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                    contactPredicates.append(pred)
                }
            }
            catch let error
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to get the contact containers. Err:" + error.localizedDescription
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            }
            break
            
        default:
            // Nothing to do.
            break
        }
        
        // Check for a valid contact predicate list
        if (contactPredicates.count > 0)
        {
            // Spefigy the keys that need to be acquired.
            let keys = [CNContactTypeKey, CNContactNamePrefixKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactRelationsKey, CNContactPostalAddressesKey]
            
            do
            {
                let contactStore = CNContactStore()
                for predicate:NSPredicate in contactPredicates
                {
                    // Get the contacts for this predicate
                    let list:[CNContact] = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keys as [CNKeyDescriptor])
                    
                    // Append the list to the super-list.
                    if (list.count > 0)
                    {
                        contactList.append(contentsOf: list)
                    }
                }
            }
            catch
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to get contact container contents."
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            }
        }
        
        return contactList
    }
    
    //
    // @desc:   Helper to determine if the source identifier represents a Container or a Group
    //
    // @param:  sourceId:    Identifier to be checked/validated.
    //
    // @return: Contact Type
    //
    // @remarks:None
    //
    fileprivate func GetContactSourceType(sourceId:String) -> ContactSourceType
    {
        var sourceType:ContactSourceType = ContactSourceType.Invalid
        
        // Is the source id, the special ** All Contacts** one?
        if (sourceId.compare(ALL_CONTACTS_SOURCE_ID) == .orderedSame)
        {
            sourceType = ContactSourceType.AllContacts
        }
        else
        {
            // Determine if this source id is for a single container or group.
            let sources:[String] = [sourceId]
            do
            {
                // Determine the source and create an appropriate predicate for getting the desired contacts.
                let contactStore = CNContactStore()
                let matchingContainers:[CNContainer]    = try contactStore.containers(matching: CNContainer.predicateForContainers(withIdentifiers: sources))
                let matchingGroups:[CNGroup]            = try contactStore.groups(matching: CNGroup.predicateForGroups(withIdentifiers: sources))
                if (!matchingContainers.isEmpty)
                {
                    // Source Id is for a container.
                    sourceType = ContactSourceType.Container
                }
                else if (!matchingGroups.isEmpty)
                {
                    // Source Id is for a group.
                    sourceType = ContactSourceType.Group
                }
            }
            catch
            {
                // Get the stack trace
                var stackTrace:String = "Stack Trace:"
                Thread.callStackSymbols.forEach{stackTrace = stackTrace + "\n" + $0}
                
                let errDesc:String = "Unable to determine contact source."
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: stackTrace, style: HolidayCardError.Style.Critical)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)
            }
        }
        
        return sourceType
    }
    // MARK: end Private methods & properties
}
