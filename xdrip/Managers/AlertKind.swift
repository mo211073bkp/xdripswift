import Foundation

/// low, high, very low, very high, ...
public enum AlertKind:Int, CaseIterable {
    case low = 0
    case high = 1
    case verylow = 2
    case veryhigh = 3
    case missedreading = 4
    case calibration = 5
    case batterylow = 6
    
    /// example, low alert needs a value = value below which alert needs to fire - there's actually no alert right now that doesn't need a value, in iosxdrip there was the iphonemuted alert, but I removed this here. Function remains, never now it might come back
    ///
    /// probably only useful in UI - named AlertKind and not AlertType because there's already an AlertType which has a different goal
    func needsAlertValue() -> Bool {
        switch self {
        case .low, .high, .verylow,.veryhigh,.missedreading,.calibration,.batterylow:
            return true
        }
    }
    
    /// at initial startup, a default alertentry will be created for every kind of alert. This function defines the default value to be used
    func defaultAlertValue() -> Int {
        switch self {
            
        case .low:
            return Constants.DefaultAlertLevels.low
        case .high:
            return Constants.DefaultAlertLevels.high
        case .verylow:
            return Constants.DefaultAlertLevels.veryLow
        case .veryhigh:
            return Constants.DefaultAlertLevels.veryHigh
        case .missedreading:
            return Constants.DefaultAlertLevels.missedReading
        case .calibration:
            return Constants.DefaultAlertLevels.calibration
        case .batterylow:
            if let transmitterType = UserDefaults.standard.transmitterType {
                return transmitterType.defaultBatteryAlertLevel()
            } else {
                return Constants.DefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            }
        }
    }
    
    /// description of the alert to be used for logging
    func descriptionForLogging() -> String {
        switch self {
            
        case .low:
            return "low"
        case .high:
            return "high"
        case .verylow:
            return "verylow"
        case .veryhigh:
            return "veryhigh"
        case .missedreading:
            return "missedreading"
        case .calibration:
            return "calibration"
        case .batterylow:
            return "batterylow"
        }
    }
    
    /// returns a closure that will verify if alert needs to be fired or not.
    ///
    /// The caller of this function must have checked already checked that lastBgReading is recent and that it has a running sensor - and that calibration is also for the last sensor
    ///
    /// The closure in the return value has several optional input parameters. Not every input parameter will be used, depending on the alertKind. For example, alertKind .calibration will not use the lastBgReading, it will use the lastCalibration
    ///
    ///     * lastBgReading should be reading for the currently active sensor with calculated value != 0
    ///     * lastButOneBgReading should als be for the currently active sensor with calculated value != 0, it is only there to be able to calculate the unitizedDeltaString for the alertBody
    ///     * lastCalibration is to allow to raise a calibration alert
    ///     * batteryLevel is to allow to raise a battery level alert
    ///
    /// The closure returns a bool which indicates if an alert needs to be raised or not, and an optional alertBody and alertTitle and an optional int, which is the optional delay that the alert notification should  have
    ///
    /// For missed reading alert : this is the only case where the delay in the return will have a value.
    ///
    /// - returns:
    ///     - a closure that needs to be called to verify if an alert is needed or not. The closure returns a tuple with a bool, an alertbody, alerttitle and delay. If the bool is false, then there's no need to raise an alert. AlertBody, AlertTitle and delay are used if an alert needs to be raised for the notification. The input to the closure are the currently applicable alertEntry, the next alertEntry (from time point of view), two bg readings, last and lastbutone, last calibration and batteryLevel is the current transmitter battery level - the two bg readings should be readings for the currently active sensor with calculated value != 0, the last calibration must be one for the currently active sensor. If there's no sensor active then there should also  not be bgreadings and a calibration
    func alertNeededChecker() -> (AlertEntry, AlertEntry?, BgReading?, BgReading?, Calibration?, Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) {
        //Not all input parameters in the closure are needed for every type of alert. - this is to make it generic
        switch self {
            
        case .low,.verylow:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                
                // if alertEntry not enabled, return false
                if !alertEntry.alertType.enabled {return (false, nil, nil, nil)}
                
                if let lastBgReading = lastBgReading {
                    // first check if lastBgReading not nil and calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.calculatedValue == 0.0 {return (false, nil, nil, nil)}
                    // now do the actual check if alert is applicable or not
                    if lastBgReading.calculatedValue < Double(alertEntry.value) {
                        return (true, lastBgReading.unitizedDeltaString(previousBgReading: lastButOneBgReading, showUnit: true, highGranularity: true), createAlertTitleForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), nil)
                    } else {return (false, nil, nil, nil)}
                } else {return (false, nil, nil, nil)}
            }
            
        case .high,.veryhigh:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                
                // if alertEntry not enabled, return false
                if !alertEntry.alertType.enabled {return (false, nil, nil, nil)}
                
                if let lastBgReading = lastBgReading {
                    // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.calculatedValue == 0.0 {return (false, nil, nil, nil)}
                    // now do the actual check if alert is applicable or not
                    if lastBgReading.calculatedValue > Double(alertEntry.value) {
                        return (true, lastBgReading.unitizedDeltaString(previousBgReading: lastButOneBgReading, showUnit: true, highGranularity: true), createAlertTitleForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), nil)
                    } else {return (false, nil, nil, nil)}
                } else {return (false, nil, nil, nil)}
            }
            
        case .missedreading:
            return { (currentAlertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delayInSeconds:Int?) in
                
                // if no valid lastbgreading then there's definitely no need to plan an alert
                guard let lastBgReading = lastBgReading else {return (false, nil, nil, nil)}
                
                // this will be the delay of the planned notification, in seconds
                var delayToUseInSeconds:Int?
                //this will be the alertentry to use, either the current one, or the next one, or none
                var alertEntryToUse:AlertEntry?
                
                // so there's a reading, let's find the applicable alertentry
                if currentAlertEntry.alertType.enabled {
                    alertEntryToUse = currentAlertEntry
                } else {
                    if let nextAlertEntry = nextAlertEntry {
                        if nextAlertEntry.alertType.enabled {
                            alertEntryToUse = nextAlertEntry
                        }
                    }
                }
                
                // now see if we found an alertentry, and if yes prepare the return value
                if let alertEntryToUse = alertEntryToUse {
                    // the current alert entry is enabled, we'll use that one to plan the missed reading alert
                    let timeSinceLastReadingInMinutes:Int = Int((Date().toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble())/1000/60)
                    // delay to use in the alert is value in the alertEntry - time since last reading in minutes
                    delayToUseInSeconds = (Int(alertEntryToUse.value) - timeSinceLastReadingInMinutes) * 60
                    return (true, "", Texts_Alerts.missedReadingAlertTitle, delayToUseInSeconds)
                } else {
                    // none of alertentries enables missed reading, nothing to plan
                    return (false, nil, nil, nil)
                }
                
            }
            
        case .calibration:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                
                // if alertEntry not enabled, return false
                if !alertEntry.alertType.enabled || lastCalibration == nil {return (false, nil, nil, nil)}
                                
                // if lastCalibration not nil, check the timestamp and check if delay > value (in hours)
                if abs(lastCalibration!.timeStamp.timeIntervalSinceNow) > TimeInterval(Int(alertEntry.value) * 3600) {
                    return(true, "", Texts_Alerts.calibrationNeededAlertTitle, nil)
                }
                return (false, nil, nil, nil)
            }
            
        case .batterylow:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                
                // if alertEntry not enabled, return false
                if !alertEntry.alertType.enabled || batteryLevel == nil {return (false, nil, nil, nil)}
                
                if alertEntry.value > batteryLevel! {
                    return (true, "", Texts_Alerts.batteryLowAlertTitle, nil)
                }
                return (false, nil, nil, nil)
            }
        }
    }
    
    /// returns notification identifier for local notifications, for specific alertKind.
    func notificationIdentifier() -> String {
        switch self {
            
        case .low:
            return Constants.Notifications.NotificationIdentifiersForAlerts.lowAlert
        case .high:
            return Constants.Notifications.NotificationIdentifiersForAlerts.highAlert
        case .verylow:
            return Constants.Notifications.NotificationIdentifiersForAlerts.veryLowAlert
        case .veryhigh:
            return Constants.Notifications.NotificationIdentifiersForAlerts.veryHighAlert
        case .missedreading:
            return Constants.Notifications.NotificationIdentifiersForAlerts.missedReadingAlert
        case .calibration:
            return Constants.Notifications.NotificationIdentifiersForAlerts.subsequentCalibrationRequest
        case .batterylow:
            return Constants.Notifications.NotificationIdentifiersForAlerts.batteryLow
        }
    }
    
    /// to be used in pickerview, as main title.
    func alertPickerViewMainTitle() -> String {
        switch self {
            
        case .low:
            return Texts_Alerts.lowAlertTitle
        case .high:
            return Texts_Alerts.highAlertTitle
        case .verylow:
            return Texts_Alerts.veryLowAlertTitle
        case .veryhigh:
            return Texts_Alerts.veryHighAlertTitle
        case .missedreading:
            return Texts_Alerts.missedReadingAlertTitle
        case .calibration:
            return Texts_Alerts.calibrationNeededAlertTitle
        case .batterylow:
            return Texts_Alerts.batteryLowAlertTitle
        }
    }
    
}

// specifically for high, low, very high, very low because these need the same kind of alertTitle
fileprivate func createAlertTitleForBgReadingAlerts(bgReading:BgReading, alertKind:AlertKind) -> String {
    var returnValue:String = ""
    
    // the start of the body, which says like "High Alert"
    switch alertKind {
        
    case .low:
        returnValue = returnValue + Texts_Alerts.lowAlertTitle
    case .high:
        returnValue = returnValue + Texts_Alerts.highAlertTitle
    case .verylow:
        returnValue = returnValue + Texts_Alerts.veryLowAlertTitle
    case .veryhigh:
        returnValue = returnValue + Texts_Alerts.veryHighAlertTitle
    default:
        return returnValue
    }
    
    // add unit
    returnValue = returnValue + " " + bgReading.calculatedValue.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    
    // add slopeArrow
    if !bgReading.hideSlope {
        returnValue = returnValue + " " + bgReading.slopeArrow()
    }
    
    return returnValue
}
