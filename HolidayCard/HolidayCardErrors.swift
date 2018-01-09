//
//  @class:         HolidayCardErrors.swift
//  @application:   HolidayCard
//
//  Created by Michael Price on 06-JAN-2018.
//  Copyright © 2018 GrumpTech. All rights reserved.
//
//  @desc:          Class for managing errors and error notification thrown by the system.
//

import Cocoa
import Foundation

class HolidayCardError : Error
{
    // MARK: Public Enumerations
    enum Style {
        case Informational
        case Warning
        case Critical
    }
    
    // MARK: Data members
    // @desc: Description of the error.
    fileprivate var _errDesc:String!
    // @desc: Stack Trace
    fileprivate var _errStackTrace:String!
    // @desc: Error style
    fileprivate var _errStyle:NSAlert.Style!
    // MARK: end Data members
    
    // MARK: Constructor/Destructor
    //
    // @desc:   Default constructor
    //
    // @param:  None
    //
    // @return: Holiday Card error
    //
    // @remarks:Not very useful
    //
    init()
    {
        _errDesc = "Generic error"
        _errStackTrace = ""
        _errStyle = NSAlert.Style.informational
    }
    
    //
    // @desc:   Constructor
    //
    // @param:  err     - Description of the error.
    // @param:  stack   - Stack trace of the occurrence of the error.
    //
    // @return: Holiday Card error
    //
    // @remarks:None
    //
    init(err:String, stack:String, style:Style)
    {
        _errDesc = err
        _errStackTrace = stack
        
        switch style
        {
        case .Informational:
            _errStyle = NSAlert.Style.informational
        case .Warning:
            _errStyle = NSAlert.Style.warning
        default:
            _errStyle = NSAlert.Style.critical
        }
    }
    // MARK: end Constructor/Desctuctor
    
    // MARK: Properties
    //
    // @desc:   Read-Only property accessor of the error description
    //
    // @param:  None
    //
    // @return: Error description
    //
    // @remarks:None
    //
    var Description: String
    {
        get
        {
            return _errDesc
        }
    }
    
    //
    // @desc:   Read-Only property accessor for the stack trace.
    //
    // @param:  None
    //
    // @return: Stack trace as a string
    //
    // @remarks:None
    //
    var StackTrace: String
    {
        get
        {
            return _errStackTrace
        }
    }
    
    //
    // @desc:   Read-Only property accessor for the error style.
    //
    // @param:  None
    //
    // @return: Error style
    //
    // @remarks:None
    //
    var Style: NSAlert.Style
    {
        get
        {
            return _errStyle
        }
    }
    // MARK: end Properties
}
