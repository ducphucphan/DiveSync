//
//  Constants.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/23/24.
//

import Foundation
import DGCharts
import UIKit

let USERINFO_DIR            = "/DIVESYNC/USERINFO/"
let PHOTOS_DIR              = "/DIVESYNC/PHOTOS/"
let PDC_DATA                = "/DIVESYNC/.PDCData/"

let CACHE                   = "cache"

let OFF                     = "OFF"

let M                       = 0
let FT                      = 1

let CONST_PSI_TO_BAR: Double = 0.06895         // 1 PSI = 0.0689475729 BAR
let CONST_PSI_TO_mBAR: Double = 68.95          // 1 PSI = 68.9475729 mBAR
let CONST_BAR_TO_PSI: Double = 14.50377        // 1 BAR = 14.503773 PSI
let CONST_mBAR_TO_PSI: Double = 0.01450        // 1 mBAR = 0.01450 PSI
let CONST_FT_TO_M: Double = 0.3048             // 1 foot = 0.3048 Meter
let CONST_M_TO_FT: Double = 3.2808             // 1 Meter = 3.2808 Feet
let CONST_CUFT_TO_LITER: Double = 28.317       // 1 Cubic Feet = 28.317 Liters
let CONST_LITER_TO_CUFT: Double = 0.0353       // 1 Liter = 0.0353 Cubic Feet
let CONST_KM_TO_MILE: Double = 0.621371        // 1 Km = 0.621371 Mile

struct DiveGraphColor {
    static let startNomalColor = NSUIColor(hexString: "#ffffff", alpha: 1.0)!//60efff
    static let endNormalColor = NSUIColor(hexString: "#ffffff", alpha: 1.0)!//001E62
    static let startDecoColor = NSUIColor(hexString: "#ff0000", alpha: 1.0)!
    static let endDecoColor = NSUIColor(hexString: "#5c0000", alpha: 1.0)!
    static let startTooFastColor = NSUIColor(hexString: "#FFFFFF", alpha: 1.0)!
    static let endTooFastColor = NSUIColor(hexString: "#FFFF00", alpha: 1.0)!
    static let shadowColor = UIColor.gray.withAlphaComponent(0.5)
}

func convertF2C(_ f: Double) -> Double {
    if f == 0 { return 0 }
    return (f - 32.0) * 5.0 / 9.0
}

func convertC2F(_ c: Double) -> Double {
    return (9.0 / 5.0) * c + 32.0
}

func convertPSI2BAR(_ psi: Double) -> Double {
    return psi * CONST_PSI_TO_BAR
}

func convertKnot2Km(_ knot: Double) -> Double {
    return knot * 1.852
}

func convertKm2Knot(_ km: Double) -> Double {
    return km * 0.539957
}

func converFeet2Meter(_ ft: Double) -> Double {
    return ft * CONST_FT_TO_M
}

func convertMeter2Feet(_ m: Double) -> Double {
    return m * CONST_M_TO_FT
}

func convertCUFT2L(_ cuft: Double) -> Double {
    return cuft * CONST_CUFT_TO_LITER
}

func convertL2CUFT(_ l: Double) -> Double {
    return l * CONST_LITER_TO_CUFT
}

func convertUBAR2PSI(_ bar: Double) -> Double {
    return bar * CONST_BAR_TO_PSI
}

func convertLBS2KG(_ lbs: Double) -> Double {
    return lbs * 0.45359237
}

func formatNumber(_ value: Double, decimalIfNeeded: Int = 1) -> String {
    let rounded = Double(round(pow(10.0, Double(decimalIfNeeded)) * value) / pow(10.0, Double(decimalIfNeeded)))
    if rounded.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", rounded)
    } else {
        return String(format: "%.\(decimalIfNeeded)f", rounded)
    }
}
