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
    //
    // @desc: Constants for the column identifiers. Set in the Storyboard.
    //
    fileprivate enum ColumnIdentifiers: String
    {
        case ContactName      = "colId_ContactName"
        case MailingName      = "colId_MailingName"
        case MailingAddress   = "colId_MailingAddress"
    }
    // MARK: end Constants, Enumerations, & Structures
    
    // MARK: Properties
    @IBOutlet fileprivate var _tableView: NSTableView!
    @IBOutlet fileprivate weak var _constraintTrail: NSLayoutConstraint!
    @IBOutlet fileprivate weak var _constraintTop: NSLayoutConstraint!
    @IBOutlet fileprivate weak var _constraintBottom: NSLayoutConstraint!
    @IBOutlet fileprivate weak var _constraintLead: NSLayoutConstraint!
    // MARK: end Properties
    
    // MARK: Data Members
    //
    // @desc: Cached frame size used to restore the window to its original size when the data are ready.
    fileprivate var _frameSize:CGSize = CGSize()
    fileprivate var _myConstraints:[NSLayoutConstraint] = [NSLayoutConstraint]()
    fileprivate var _dataSource:[HolidayCardProcessor.ContactInfo] = [HolidayCardProcessor.ContactInfo]()
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
        nc.addObserver(self, selector: #selector(UpdateUI(notification:)), name: Notification.Name.HCPreviewDataReady, object: nil)
        
        // Cache our constraints of interest, so that they do not
        // get in the way when "hiding" the window during load.
        _myConstraints.append(_constraintTrail)
        _myConstraints.append(_constraintTop)
        _myConstraints.append(_constraintBottom)
        _myConstraints.append(_constraintLead)
    }

    //
    // @desc:   Class override for showing the view
    //
    // @param:  None
    //
    // @return: None
    //
    // @remarks:None
    //
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
            // Deactivate the constraints so that we can completely hide the window.
            for constraint:NSLayoutConstraint in _myConstraints
            {
                constraint.isActive = false
            }
            
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
    // @param:  notification:   Variable data passed to the notification handler to specify the preview data.
    //
    // @return: None
    //
    // @remarks:Invoked via NotificationCenter event raised from the AppDelegate.
    //
    @objc fileprivate func UpdateUI(notification:NSNotification) -> Void
    {
        // Get the new mode.
        let data:[HolidayCardProcessor.ContactInfo]? = notification.userInfo?[NotificationPayloadKeys.data.rawValue] as? [HolidayCardProcessor.ContactInfo]
        
        if ((data != nil) &&
            ((data?.count)! > 0) &&
            (PreviewType != HolidayCardProcessor.ContactPreviewType.Unknown))
        {
            // Sort & Cache the data.
            _dataSource = data!.sorted(by: { (first:HolidayCardProcessor.ContactInfo, second:HolidayCardProcessor.ContactInfo) -> Bool in
                return (first.contactName.compare(second.contactName) != ComparisonResult.orderedDescending)
            })

            // Show our window. re-establish our constraints,
            // and initiate the data reload
            if (self.view.window != nil)
            {
                // Get the current window frame
                var frame:NSRect = (self.view.window?.frame)!
                // Make ourselves normal again.
                frame = CGRect(origin: frame.origin, size: _frameSize)
                self.view.window?.setFrame(frame, display: true)
                
                // Reactivate the constraints so that the display works properly
                for constraint:NSLayoutConstraint in _myConstraints
                {
                    constraint.isActive = true
                }
                
                // Update the window title
                self.view.window?.title = PreviewTypeDesc + " (\(_dataSource.count) contacts)"
                
                // Load the table data.
                _tableView.reloadData()
                
                // If this is a reset view, hide all columns other than the name.
                if (HolidayCardProcessor.ContactPreviewType.Reset == PreviewType)
                {
                    for column:NSTableColumn in _tableView.tableColumns
                    {
                        // Is this a column other than the contact name?
                        if (ColumnIdentifiers.ContactName.rawValue.compare(column.identifier.rawValue) != ComparisonResult.orderedSame)
                        {
                            // Hide the column
                            column.isHidden = true;
                        }
                    }
                    
                    // Since there will only be one column, prevent column resizing
                    _tableView.allowsColumnResizing = false
                }
            }
        }
        else
        {
            if (self.view.window != nil)
            {
                // Notify the user that there is no data to be previewed.
                let errDesc:String = "There is no data available for the preview."
                let errData:HolidayCardError = HolidayCardError(err: errDesc, stack: String(), style: HolidayCardError.Style.Informational)
                
                // Post the error for reporting.
                let err:[String:HolidayCardError] = [NotificationPayloadKeys.error.rawValue:errData]
                let nc:NotificationCenter = NotificationCenter.default
                nc.post(name: Notification.Name.HCHolidayCardError, object: nil, userInfo: err)

                // There is nothing else for us to do.
                self.view.window?.close()
            }
        }
    }
    
    //
    // @desc:   Read-Only property for the string representation of the preview type
    //
    // @param:  None
    //
    // @return: String representation
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
                
            case HolidayCardProcessor.ContactPreviewType.Reset:
                desc = DESC_BASE + "Reset"
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

//
// @desc: Extension for the Table View Data Source interface.
//
extension MailingListPreviewViewController: NSTableViewDataSource
{
    //
    // @desc:   Specifies the number of rows with data entries
    //
    // @param:  tableView:  Table being querried
    //
    // @return: Number of rows
    //
    // @remarks:None
    //
    func numberOfRows(in tableView: NSTableView) -> Int
    {
        var rows:Int = 0
        
        if (tableView == _tableView)
        {
            rows = _dataSource.count
        }
        
        return rows
    }
}

//
// @desc: Extension for the Table View Delegate interface.
//
extension MailingListPreviewViewController: NSTableViewDelegate
{
    // MARK: Constants and Enumerations
    // MARK: end Constants and Enumerations
    
    // MARK: Table View Delegate Implementation.
    //
    // @desc:   Handler providng the value for each cell
    //
    // @param:  tableView:      Table being querried
    // @param:  tableColumn:    Column being updated
    // @param:  row:            Row being updated
    //
    // @return: NSView cell value
    //
    // @remarks:None
    //
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    {
        var cellValue: String = ""
        var columnId: String = ""
        
        // Determine which column this is.
        columnId = (tableColumn?.identifier)!.rawValue
        
        // Get the data for this request
        let cellDataSource:HolidayCardProcessor.ContactInfo = _dataSource[row]
        
        // Determine the actual data for this cell
        switch (columnId)
        {
        case ColumnIdentifiers.ContactName.rawValue:
            cellValue = cellDataSource.contactName
            break
            
        case ColumnIdentifiers.MailingName.rawValue:
            cellValue = cellDataSource.mailingName
            break
            
        case ColumnIdentifiers.MailingAddress.rawValue:
            cellValue = cellDataSource.mailingAddr
            break
            
        default:
            // Error. Unknown column
            cellValue = "Unknown column"
            break
        }
        
        // Create a cell and populate.
        let cell:NSTableCellView? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: columnId), owner: nil) as? NSTableCellView
        if (cell != nil)
        {
            cell?.textField?.stringValue = cellValue
        }
        
        return cell
    }
}
