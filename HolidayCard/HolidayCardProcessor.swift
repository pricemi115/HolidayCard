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
//
import Foundation
import Contacts

//
// Description: Class responsible for managing contacts database for the purpose of
//              generating a "Holiday Card" mailling list.
//
class HolidayCardProcessor : NSObject
{
    // MARK: Constants and enumerations for the class.
    // MARK: end Constants and enumerations
    
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
                
                // Wait until the user has responded.
                while (waitingForResponse)
                {
                    // Do nothing.
                }
            }
        }
        else
        {
            print("Permission pre-approved")
        }
        
        return permissionStatus.permissionGranted
    }
    
    //
    // @desc:   Retrieves a list of contacts for the group specified.
    //
    // @param:  groupName - Name of the group to get the contacts
    //
    // @return: List of contacts
    //
    // @remarks:None
    //
    func GetContactGroupContents(groupName: String) -> [CNContact]
    {
        var contactList:[CNContact] = [CNContact]()
        
        // Get the information for the group specified.
        let (groupFound, groupId):(Bool, String) = GetGroupInfo(groupName: groupName)
        
        // Check for a valid contact group
        if (groupFound &&
            !groupId.isEmpty)
        {
            let keys = [CNContactRelationsKey, CNContactPostalAddressesKey]
            let contactPredicate:NSPredicate = CNContact.predicateForContactsInGroup(withIdentifier: groupId)
            
            do
            {
                let contactStore = CNContactStore()
                contactList = try contactStore.unifiedContacts(matching: contactPredicate, keysToFetch: keys as [CNKeyDescriptor])
            }
            catch
            {
                print("GetGontactGroupContents(): Error getting contacts")
            }
        }
        
        return contactList
    }
    
    //
    // @desc:   Clear the "destination" contact group
    //
    // @param:  groupName - Name of the group to be flushed.
    //
    // @return: None
    //
    // @remarks:Assumes that the destination group is only used to store the "modified"
    // @remarks:contacts for the purpose of printing address labels.
    //
    func FlushAllGroupContacts(groupName: String) -> Void
    {
        let contactsToDelete:[CNContact] = GetContactGroupContents(groupName: groupName)
        
        guard (contactsToDelete.count > 0) else
        {
            // Nothing to do.
            print("FlushAllContactsInTemp() - Nothing to Flush")
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
            print("Success, You deleted the user(s)")
        } catch let error
        {
            print("FlushAllContactsInTemp() - Error = \(error)")
        }
    }
    
    //
    // @desc:   Helper to initiate a backup of all contacts.
    //
    // @param:  None
    //
    // @return: true if successful
    //
    // @remarks:Backup is a VCard file for all contacts.
    // @remarks:File is stored in the user sandbox in a file named Backup.vcf
    //
    func BackupContacts() -> Bool
    {
        var success:Bool = false

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
            let directoryURL:URL = try FileManager.default.url(for: FileManager.SearchPathDirectory.applicationSupportDirectory,
                                                               in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: true)
            var filePath:URL = directoryURL.appendingPathComponent("Backup", isDirectory: false)
            filePath = filePath.appendingPathExtension("vcf")
            
            // Write the backup file as an atomic operation.
            try data.write(to: filePath, options: Data.WritingOptions.atomic)
            success = true
        }
        catch let error
        {
            // Do nothing/
            print("Backup() - \(error)")
            success = false
        }
        
        return success
    }
    
    //
    // @desc:   Generate a list of contacts for printing holiday card addresses
    //
    // @param:  grpSource - Name of the group providing the source data for the holiday mailing list.
    // @param:  grpDest   - Name of the group for the destination of the holiday mailing list.
    //
    // @return: None
    //
    // @remarks:None
    //
    func GenerateHolidayList(grpSource: String, addrSource: String, relatedNameSource: String, grpDest: String) -> Void
    {
        let contactStore = CNContactStore()
        let grpHolidayGroup: CNGroup = GetGroup(groupName: grpDest).group
        
        // Ensure that the source and destination are indeed different.
        guard (grpSource.caseInsensitiveCompare(grpDest) != .orderedSame) else
        {
            print("GenerateHolidayList - Source & Destination are the same")
            return
        }
        
        // Ensure that there are contacts to put into the list.
        let holidayList:[CNContact] = GetHolidayList(groupSource: grpSource, addrSource: addrSource, relatedNameSource: relatedNameSource, valid: true)
        guard (holidayList.count > 0) else
        {
            print("GenerateHolidayList - No contacts to build a list from.")
            return
        }
        
        // Ensure that the destination list does not already exist.
        guard (GetContactGroupContents(groupName: grpDest).count == 0) else
        {
            print("GenerateHolidayList - Destination needs to be flushed.")
            return
        }
        
        // Get the id og the container housing the "destination" group.
        var holidayContainerId:String = String()
        do
        {
            let predContainer:NSPredicate = CNContainer.predicateForContainerOfGroup(withIdentifier: grpHolidayGroup.identifier)
            let containers:[CNContainer] = try contactStore.containers(matching: predContainer)
            guard (containers.count == 1) else
            {
                print("GenerateHolidayList() - Wrong number of matching containers.")
                return
            }
            
            // Get the identifier
            holidayContainerId = containers[0].identifier
        }
        catch
        {
            print("GenerateHolidayList() - Error getting container.")
        }
        
        // Construct a request to (1) create the new/modified contact and (2) add all of the items in the Holiday Destination group
        let requestToCreate = CNSaveRequest()
        for contact:CNContact in holidayList
        {
            // Create the contact within the same container as the destination group.
            let mutableContact:CNMutableContact = contact.mutableCopy() as! CNMutableContact
            requestToCreate.add(mutableContact, toContainerWithIdentifier: holidayContainerId)
            // Add the contact to the holiday destination group.
            requestToCreate.addMember(contact, to: grpHolidayGroup)
        }
        
        // Perform the Update.
        do
        {
            try contactStore.execute(requestToCreate)
            print("Success, You added the user(s)")
        } catch let error
        {
            print("GenerateHolidayList() - Error = \(error)")
        }
    }
    
    //
    // @desc: Generates a list of immutable Holiday Contacts
    //
    // @param: groupSource       - Name of the group acting as the source for the holiday mailing list.
    // @param: addrSource        - Label for the postal address to use for generating the mailing list.
    // @param: relatedNameSource - Label for the related name to use for generating the mailing list.
    // @param: valid             - Flag to indicate if the list is for valid contacts or contacts with errors.
    //
    // Return:      list of immutable CNContacts
    //
    // Remarks:     None
    //
    private func GetHolidayList(groupSource: String, addrSource: String, relatedNameSource: String, valid: Bool) -> [CNContact]!
    {
        var holidayList:[CNMutableContact] = [CNMutableContact]()
        
        // Get the requested source list for the holiday contacts
        let holidayContacts:[CNContact] = GetContactGroupContents(groupName: groupSource)
        
        // Iterate through the list of holiday contacts and create a modified
        // list suitable for label printing.
        for contact:CNContact in holidayContacts
        {
            var holidayName: String = String()
            var holidayAddress: CNLabeledValue<CNPostalAddress> = CNLabeledValue<CNPostalAddress>()
            for name:CNLabeledValue<CNContactRelation> in contact.contactRelations
            {
                if (name.label?.caseInsensitiveCompare(relatedNameSource) == .orderedSame)
                {
                    holidayName = name.value.name
                    break
                }
            }
            for address:CNLabeledValue<CNPostalAddress> in contact.postalAddresses
            {
                if (address.label?.caseInsensitiveCompare(addrSource) == .orderedSame)
                {
                    holidayAddress = address
                    break
                }
            }
            
            if  // Valid contacts.
                ((valid &&
                  ((holidayName.isEmpty == !valid) && (holidayAddress.value.street.isEmpty == !valid) && (holidayAddress.value.city.isEmpty == !valid))) ||
                 // Error candidates
                 (!valid &&
                  ((holidayName.isEmpty == !valid) || (holidayAddress.value.street.isEmpty == !valid) || (holidayAddress.value.city.isEmpty == !valid))))
            {
                let newContact:CNMutableContact = CNMutableContact()
                newContact.contactType = CNContactType.person
                if (!holidayName.isEmpty)
                {
                    newContact.familyName = holidayName
                }
                if ((holidayAddress.label != nil) &&
                    (!holidayAddress.label!.isEmpty))
                {
                    newContact.postalAddresses.append(holidayAddress)
                }
                holidayList.append(newContact)
            }
        }
        
        return holidayList as [CNContact]
    }
    
    //
    // @desc:   Accessor for group information.
    //
    // @param:  groupName - Name of the group
    //
    // @return: valid - Flag indicating group exists.
    //          groupId - String identifier of the group.
    //
    // @remarks:None
    //
    func GetGroupInfo(groupName:String) -> (valid: Bool, groupId: String)
    {
        let (valid, group):(Bool, CNGroup) = GetGroup(groupName: groupName);
        
        return (valid, group.identifier)
    }
    
    func GetPostalAddressLabels(groupName:String) -> [String]
    {
        var labels:[String] = [String]()
        
        // Get the contents of the specified group.
        let contacts:[CNContact] = GetContactGroupContents(groupName: groupName)
        for contact:CNContact in contacts
        {
            // get all of the postal addresses in the contact.
            for address:CNLabeledValue<CNPostalAddress> in contact.postalAddresses
            {
                // Is this a "new" & valid address label?
                let localizedLabel:String = CNLabeledValue<CNPostalAddress>.localizedString(forLabel: address.label!)
                if (!localizedLabel.isEmpty &&
                    !labels.contains(localizedLabel))
                {
                    // Add to the list.
                    labels.append(localizedLabel)
                }
            }
        }
        
        return labels
    }
    
    func GetRelatedNamesLabels(groupName:String) -> [String]
    {
        var labels:[String] = [String]()
        
        // Get the contents of the specified group.
        let contacts:[CNContact] = GetContactGroupContents(groupName: groupName)
        for contact:CNContact in contacts
        {
            // get all of the postal addresses in the contact.
            for relation:CNLabeledValue<CNContactRelation> in contact.contactRelations
            {
                // Is this a "new" & valid contact relation label?
                let localizedLabel:String = CNLabeledValue<CNContactRelation>.localizedString(forLabel: relation.label!)
                if (!localizedLabel.isEmpty &&
                    !labels.contains(localizedLabel))
                {
                    // Add to the list.
                    labels.append(localizedLabel)
                }
            }
        }
        
        return labels
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
    // @remark: throws an permission exception if permissions are not yet determined.
    //
    var IsContactPermissionGranted: (permissionGranted: Bool, alertable: Bool)!
    {
        get
        {
            let authStatus: CNAuthorizationStatus = CNAuthorizationStatus.notDetermined//  CNContactStore.authorizationStatus(for: CNEntityType.contacts)
            
            let permissionAuthorized = (authStatus == CNAuthorizationStatus.authorized)
            let permissionAlertable = !permissionAuthorized && (authStatus != CNAuthorizationStatus.denied)

            return (permissionAuthorized, permissionAlertable)
        }
    }
    
    //
    // @desc:   Read-Only property providing a list of names for the contact groups.
    //
    // @param:  None
    //
    // @return: List of group names.
    //
    // @remarks:None
    //
    var GetContactGroups: [String]!
    {
        get
        {
            var groupNames:[String] = [String]()
            let contactStore = CNContactStore()

            do
            {
                let groupList:[CNGroup] = try contactStore.groups(matching: nil)
                
                // Build a list of the group names.
                for group:CNGroup in groupList
                {
                    groupNames.append(group.name)
                }
            }
            catch let err
            {
                print("GetContactGroups: Error getting group list err-\(err)")
            }
            
            return groupNames
        }
    }
    
    // MARK: -- end Public properties

    // MARK: Private methods & properties
    //
    // @desc:   Finds the CNGroup based on the name provided.
    //
    // @param:  groupName - Name of the group being sought
    //
    // @return: (Tuple) status - true if matching group found.
    //                  group  - CNGroup being sought.
    //
    // @remarks: None
    //
    fileprivate func GetGroup(groupName:String) -> (status: Bool, group: CNGroup)
    {
        var status = false
        var grpSearch:CNGroup = CNGroup()
        let contactStore = CNContactStore()
        
        // Get all of the known groups.
        do
        {
            let groupList:[CNGroup] = try contactStore.groups(matching: nil)
        
            // Find the group that matches the Holiday Card source.
            for group:CNGroup in groupList
            {
                if (group.name == groupName)
                {
                    // Match found
                    grpSearch = group
                    status = true
                    break
                }
            }
        }
        catch
        {
            status = false
        }
        
        return (status, grpSearch)
    }
    // MARK: end Private methods & properties
}
