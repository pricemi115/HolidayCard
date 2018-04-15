//
//  @class:         NotificationExtensions
//  @application:   HolidayCard
//
//  Created by Michael Price on 06-JAN-2018.
//  Copyright © 2018 GrumpTech. All rights reserved.
//
//  @desc:          Extension of the Notification class for customized NotificationCenter events.
//

import Foundation

//
// @desc: Application extensions to the Notification Center's list of known notification events.
//
extension Notification.Name
{
    static let CNPermissionGranted      = Notification.Name("CNPermissionGranted")
    static let HCHolidayCardError       = Notification.Name("HCHolidayCardError")
    static let HCEnableUserInterface    = Notification.Name("HCEnableUserInterface")
    static let HCDisableUserInterface   = Notification.Name("HCDisableUserInterface")
    static let HCModeChange             = Notification.Name("HCModeChange")
    static let HCUpdateContactCounts    = Notification.Name("HCUpdateContactCounts")
    static let HCPreviewDataReady       = Notification.Name("HCPreviewDataReady")
    static let APPBackupPathChanged     = Notification.Name("APPBackupPathChanged")
}

//
// @desc: Enumeration for keys used for passing payload data along with notifications.
//
enum NotificationPayloadKeys:String
{
    case error  = "error"
    case data   = "data"
}
