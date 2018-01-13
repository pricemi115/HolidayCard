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
    static let HCEnableGenerateListBtn  = Notification.Name("HCEnableGenerateListBtn")
    static let HCModeChange             = Notification.Name("HCModeChange")
}
