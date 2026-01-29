//
//  AlarmDecoder.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 1/22/26.
//

struct DiveErrors: OptionSet {
    let rawValue: UInt8

    static let powerLoss        = DiveErrors(rawValue: 1 << 0)
    static let temporaryViol    = DiveErrors(rawValue: 1 << 1)
    static let permanentViol1   = DiveErrors(rawValue: 1 << 2)
    static let permanentViol2   = DiveErrors(rawValue: 1 << 3)
    static let depthOutOfRange  = DiveErrors(rawValue: 1 << 4)
    static let longDive         = DiveErrors(rawValue: 1 << 5)
    static let violUnderwater   = DiveErrors(rawValue: 1 << 6)
    static let violSurface      = DiveErrors(rawValue: 1 << 7)

    var isViolation: Bool {
        contains(.violUnderwater) || contains(.violSurface)
    }
}

struct AlarmId1: OptionSet {
    let rawValue: UInt8

    static let ascentSpeed   = AlarmId1(rawValue: 1 << 0)
    static let ndl            = AlarmId1(rawValue: 1 << 1)
    static let depth          = AlarmId1(rawValue: 1 << 2)
    static let time           = AlarmId1(rawValue: 1 << 3)
    static let mod            = AlarmId1(rawValue: 1 << 4)
    static let oxTox          = AlarmId1(rawValue: 1 << 5)
    static let oxTox100       = AlarmId1(rawValue: 1 << 6)
    static let decoStopMissed = AlarmId1(rawValue: 1 << 7)

    var descriptions: [String] {
        var result: [String] = []
        if contains(.ascentSpeed)   { result.append("ASCENT SPEED ALARM") }
        if contains(.ndl)           { result.append("NDL ALARM") }
        if contains(.depth)         { result.append("DEPTH ALARM") }
        if contains(.time)          { result.append("TIME ALARM") }
        if contains(.mod)           { result.append("MOD ALARM") }
        if contains(.oxTox)         { result.append("OXTOX ALARM") }
        if contains(.oxTox100)      { result.append("OXTOX 100 ALARM") }
        if contains(.decoStopMissed){ result.append("DECO STOP MISSED ALARM") }
        return result
    }
}

struct AlarmId2: OptionSet {
    let rawValue: UInt8

    static let depthRange = AlarmId2(rawValue: 1 << 0)
    static let longDive   = AlarmId2(rawValue: 1 << 1)
    static let deco200ft  = AlarmId2(rawValue: 1 << 2)
    static let batWarning = AlarmId2(rawValue: 1 << 3)
    static let batAlarm   = AlarmId2(rawValue: 1 << 4)
    static let tankTurn  = AlarmId2(rawValue: 1 << 5)
    static let tankEnd   = AlarmId2(rawValue: 1 << 6)
    static let tankDtr   = AlarmId2(rawValue: 1 << 7)

    var descriptions: [String] {
        var result: [String] = []
        if contains(.depthRange) { result.append("DEPTH RANGE ALARM") }
        if contains(.longDive)   { result.append("LONG DIVE ALARM") }
        if contains(.deco200ft)  { result.append("DECO STOP 200FT ALARM") }
        if contains(.batWarning) { result.append("BAT WARNING") }
        if contains(.batAlarm)   { result.append("BAT ALARM") }
        if contains(.tankTurn)  { result.append("TANK TURN ALARM") }
        if contains(.tankEnd)   { result.append("TANK END ALARM") }
        if contains(.tankDtr)   { result.append("TANK DTR ALARM") }
        return result
    }
}

func buildAlarmString(alarmId1: String?, alarmId2: String?) -> String {
    var result: [String] = []
    
    if let v1 = alarmId1.flatMap(UInt8.init) {
        let alarms1 = AlarmId1(rawValue: v1)
        result.append(contentsOf: alarms1.descriptions)
    }
    
    if let v2 = alarmId2.flatMap(UInt8.init) {
        let alarms2 = AlarmId2(rawValue: v2)
        result.append(contentsOf: alarms2.descriptions)
    }
    
    return result.joined(separator: ", ")
}

