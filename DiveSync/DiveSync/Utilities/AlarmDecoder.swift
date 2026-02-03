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
        if contains(.ascentSpeed)   { result.append("ASCENT") }
        if contains(.ndl)           { result.append("DECO") }
        if contains(.depth)         { result.append("DEPTH") }
        if contains(.time)          { result.append("EDT") }
        if contains(.mod)           { result.append("MOD") }
        if contains(.oxTox)         { result.append("OXTOX") }
        if contains(.oxTox100)      { result.append("OXTOX 100%M") }
        if contains(.decoStopMissed){ result.append("MISSED DECO STOP") }
        return result
    }
    
    var isAscentSpeed: Bool {
        contains(.ascentSpeed)
    }
    
    var isDeco: Bool {
        contains(.ndl)
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
        if contains(.deco200ft)  { result.append("DECO STOP 200FT") }
        if contains(.batWarning) { result.append("BAT LOW") }
        if contains(.batAlarm)   { result.append("BATTERY TOO LOW") }
        return result
    }
    
    var isViolation: Bool {
        contains(.deco200ft)
    }
}

func buildAlarmString(alarmId1: String?, alarmId2: String?) -> [String] {
    var result: [String] = []
    
    if let v1 = alarmId1.flatMap(UInt8.init) {
        let alarms1 = AlarmId1(rawValue: v1)
        result.append(contentsOf: alarms1.descriptions)
    }
    
    if let v2 = alarmId2.flatMap(UInt8.init) {
        let alarms2 = AlarmId2(rawValue: v2)
        result.append(contentsOf: alarms2.descriptions)
    }
    
    return result
}

