//
//  DateFormatterUtility.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/20/24.
//

import Foundation

class DateFormatterUtility {
    /// Formats a date and time string into the desired format.
    /// - Parameters:
    ///   - date: The date string in "yyyy/MM/dd" format.
    ///   - time: The time string in "HH:mm" format.
    /// - Returns: A formatted date string in "MMM d, yyyy HH:mm a" format.
    static func formatDateTime(date: String, time: String, inputFormat: String, outputFormat: String) -> String {
        // Combine date and time into a single string
        let dateTimeString = "\(date) \(time)"
        
        // Configure a date formatter for the input format
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = inputFormat
        
        // Convert the input string into a Date object
        guard let parsedDate = inputFormatter.date(from: dateTimeString) else {
            return "Invalid date"
        }
        
        // Configure a date formatter for the output format
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = outputFormat
        
        // Return the formatted date
        return outputFormatter.string(from: parsedDate)
    }
    
    static func formatDate(date: String, inputFormat: String, outputFormat: String) -> String {
        // Configure a date formatter for the input format
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = inputFormat
        
        // Convert the input string into a Date object
        guard let parsedDate = inputFormatter.date(from: date) else {
            return "Invalid date"
        }
        
        // Configure a date formatter for the output format
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = outputFormat
        
        // Return the formatted date
        return outputFormatter.string(from: parsedDate)
    }
    
    static func formatTime(time: String, inputFormat: String, outputFormat: String) -> String {
        // Định dạng thời gian đầu vào
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = inputFormat // Định dạng 24 giờ
        
        // Chuyển đổi chuỗi thời gian thành `Date`
        guard let date = inputFormatter.date(from: time) else {
            return "Invalid time"
        }
        
        // Định dạng thời gian đầu ra
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = outputFormat
        
        // Trả về chuỗi thời gian được định dạng
        return outputFormatter.string(from: date)
    }
}

