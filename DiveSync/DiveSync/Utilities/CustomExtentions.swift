//
//  CustomExtentions.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/8/24.
//

import UIKit
import GRDB
import DGCharts

extension UINavigationController {
    func setTitleWithIcon(for navigationItem: UINavigationItem, title: String, icon: UIImage) {
        // Create a container view to hold both the icon and the title
        let titleView = UIView()
        
        // Create the image view for the icon
        let iconImageView = UIImageView(image: icon)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create the label for the title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add the icon image and the label to the title view
        titleView.addSubview(iconImageView)
        titleView.addSubview(titleLabel)
        
        // Set constraints for icon and label
        NSLayoutConstraint.activate([
            // Icon constraints
            iconImageView.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            
            // Title label constraints
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleView.centerYAnchor)
        ])
        
        // Set the custom view as the navigation item’s title view
        navigationItem.titleView = titleView
    }
    
    func setCustomTitle(for navigationItem: UINavigationItem,
                        title: String,
                        fontSize: CGFloat = 16,
                        pushBack: Bool = false, backImage: String? = "line.3.horizontal") {
        // 1. Tạo title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: fontSize)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.sizeToFit()
        let titleItem = UIBarButtonItem(customView: titleLabel)
        
        // 2. Tạo nút back nếu pushBack = true
        var leftBarButtonItems: [UIBarButtonItem] = []
        
        if pushBack {
            let backButton = UIButton(type: .system)
            
            // Sử dụng UIButtonConfiguration thay vì contentEdgeInsets
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: backImage ?? "") // Hoặc ảnh tùy chỉnh
            config.imagePadding = 0 // Điều chỉnh khoảng cách của icon
            config.baseForegroundColor = .white
            backButton.configuration = config
            
            backButton.addTarget(self, action: #selector(defaultBackAction), for: .touchUpInside)
            
            let backItem = UIBarButtonItem(customView: backButton)
            leftBarButtonItems.append(backItem)
        }
        
        // 3. Thêm title vào leftBarButtonItems
        leftBarButtonItems.append(titleItem)
        
        // 4. Gán vào navigationItem
        navigationItem.leftBarButtonItems = leftBarButtonItems
    }
    
    func setCustomTitleAndBack(for navigationItem: UINavigationItem, title: String, fontSize: CGFloat = 16) {
        // 1. Tạo title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: fontSize)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.sizeToFit()
        let titleItem = UIBarButtonItem(customView: titleLabel)
        
        // 2. Tạo nút back nếu pushBack = true
        var leftBarButtonItems: [UIBarButtonItem] = []
        
        let backButton = UIButton(type: .system)
        
        // Sử dụng UIButtonConfiguration thay vì contentEdgeInsets
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.backward") // Hoặc ảnh tùy chỉnh
        config.imagePadding = 0 // Điều chỉnh khoảng cách của icon
        config.baseForegroundColor = .white
        backButton.configuration = config
        
        backButton.addTarget(self, action: #selector(defaultBackAction), for: .touchUpInside)
        
        let backItem = UIBarButtonItem(customView: backButton)
        leftBarButtonItems.append(backItem)
        
        // 3. Thêm title vào leftBarButtonItems
        leftBarButtonItems.append(titleItem)
        
        // 4. Gán vào navigationItem
        navigationItem.leftBarButtonItems = leftBarButtonItems
    }
    
    @objc private func defaultBackAction() {
        self.popViewController(animated: true)
    }
}

extension UIApplication {
    // MARK: - Helper to get topMost ViewController
    func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .filter { $0.activationState == .foregroundActive }
        .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.rootViewController }
        .first) -> UIViewController? {
            if let nav = base as? UINavigationController {
                return topMostViewController(base: nav.visibleViewController)
            }
            if let tab = base as? UITabBarController {
                return topMostViewController(base: tab.selectedViewController)
            }
            if let presented = base?.presentedViewController {
                return topMostViewController(base: presented)
            }
            return base
        }
}

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Remove the "#" character if it's present
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        // Default to black if the hex string is invalid
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

extension Row {
    func doubleToString(format: String?, key: String) -> String {
        let value = self[key] as? Double ?? 0
        
        if let formatted = format {
            return String(format: formatted, value)
        } else {
            return String(format: "%f", value)
        }
    }
    
    func int64ToString(key: String) -> String {
        let value = self[key] as? Int64 ?? 0
        return String(format: "%d", value)
    }
    
    func stringValue(key: String) -> String{
        return self[key] ?? ""
    }
    
    func intValue(key: String) -> Int {
        let value = self[key] as? Int64 ?? 0
        return Int(value)
    }
    
    func uint8Value(key: String) -> UInt8 {
        if let dbValue = self[key] {
            switch dbValue.databaseValue.storage {
            case .string(let stringValue):
                return UInt8(stringValue) ?? 0
            case .int64(let intValue):
                return UInt8(clamping: intValue)
            default:
                return 0
            }
        }
        return 0
    }
    
    func uint16Value(key: String) -> UInt16 {
        if let dbValue = self[key] {
            switch dbValue.databaseValue.storage {
            case .string(let stringValue):
                return UInt16(stringValue) ?? 0
            case .int64(let intValue):
                return UInt16(clamping: intValue)
            default:
                return 0
            }
        }
        return 0
    }
}

extension Optional where Wrapped == String {
    func isNilOrEmpty() -> Bool {
        return self?.isEmpty ?? true
    }
}

extension UILabel {
    /// Đặt văn bản với giá trị và số mũ
    /// - Parameters:
    ///   - value: Giá trị chính
    ///   - exponent: Số mũ
    ///   - valueFontSize: Kích thước font chữ cho giá trị chính
    ///   - exponentFontSize: Kích thước font chữ cho số mũ
    func setTextWithExponent(value: Int,
                             exponent: String,
                             valueFont: UIFont = .systemFont(ofSize: 16),
                             exponentFont: UIFont = .systemFont(ofSize: 16)) {
        let valueString = "\(value)"
        let exponentString = "\(exponent)"
        
        // Tạo NSMutableAttributedString cho giá trị chính
        let attributedText = NSMutableAttributedString(string: valueString, attributes: [
            .font: valueFont
        ])
        
        // Tạo NSAttributedString cho số mũ
        let exponentAttributedString = NSAttributedString(string: exponentString, attributes: [
            .font: exponentFont,
            .baselineOffset: exponentFont.pointSize * 0.4 // Đẩy số mũ lên trên
        ])
        
        // Gắn chuỗi số mũ vào chuỗi chính
        attributedText.append(exponentAttributedString)
        
        // Gán vào UILabel
        self.attributedText = attributedText
    }
    
    /// Sets specific characters or substring to a smaller font size
    /// - Parameters:
    ///   - substring: The substring to apply the smaller font size
    ///   - fontSize: The font size to apply to the substring
    func setLowerSize(for substring: String, font: UIFont) {
        guard let fullText = self.text else { return }
        let range = (fullText as NSString).range(of: substring)
        guard range.location != NSNotFound else { return }
        
        // Create an attributed string
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // Apply smaller font to the substring
        attributedString.addAttribute(.font, value:font, range: range)
        
        // Assign the attributed string to the label
        self.attributedText = attributedString
    }
    
    /// Set viền (stroke) cho text của UILabel
    func setTextStroke(text: String, textColor: UIColor, strokeColor: UIColor, strokeWidth: CGFloat = -2.0) {
        let attributes: [NSAttributedString.Key: Any] = [
            .strokeColor: strokeColor,
            .foregroundColor: textColor,
            .strokeWidth: strokeWidth
        ]
        self.attributedText = NSAttributedString(string: text, attributes: attributes)
    }
    
    /// Set viền xung quanh label (viền khung)
    func setLabelBorder(color: UIColor, width: CGFloat, cornerRadius: CGFloat = 0) {
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth = width
        self.layer.cornerRadius = cornerRadius
        self.clipsToBounds = true
    }
    
    /// Tuỳ chọn: Thêm bóng cho chữ
    func setTextShadow(color: UIColor = .black, offset: CGSize = CGSize(width: 1, height: 1), radius: CGFloat = 2, opacity: Float = 0.8) {
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOffset = offset
        self.layer.shadowRadius = radius
        self.layer.shadowOpacity = opacity
        self.layer.masksToBounds = false
    }
}

extension Dictionary where Key == String {
    /*
    subscript(key: DCSettingColumnCode) -> Any? {
        
        let key = key.rawValue.lowercased()
        let value = self[key]
        
        if let stringValue = value as? String {
            return stringValue.removingSurroundingSingleQuotes()
        } else {
            return value
        }
    }
    */
    
    func uint16(for key: String, default defaultValue: UInt16 = 0) -> UInt16 {
        if let intValue = self[key] as? Int, intValue >= 0 && intValue <= UInt16.max {
            return UInt16(intValue)
        }
        return defaultValue
    }
    
    func uint8(for key: String, default defaultValue: UInt8 = 0) -> UInt8 {
        if let intValue = self[key] as? Int, intValue >= 0 && intValue <= 255 {
            return UInt8(intValue)
        }
        return defaultValue
    }
    
    func int(for key: String, default defaultValue: Int = 0) -> Int {
        return self[key] as? Int ?? defaultValue
    }
    
    func string(for key: String, default defaultValue: String = "") -> String {
        if let value = self[key] as? String {
            return value.removingSurroundingSingleQuotes()
        } else {
            return defaultValue
        }
    }
    
    func bool(for key: String, default defaultValue: Bool = false) -> Bool {
        return self[key] as? Bool ?? defaultValue
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension String {
    func autoCast() -> Any {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let bool = Bool(trimmed.lowercased()) {
            return bool
        } else if let int = Int(trimmed) {
            return int
        } else if let double = Double(trimmed) {
            return double
        }
        return self // fallback là String
    }
    
    func toInt() -> Int {
        // Nếu chuỗi là "OFF", trả về 0
        if self.uppercased() == OFF {
            return 0
        }
        
        // Loại bỏ tất cả ký tự không phải là số
        let cleanedString = self.trimmingCharacters(in: .whitespaces)  // Loại bỏ khoảng trắng
            .replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)  // Loại bỏ các ký tự không phải số
        
        return Int(cleanedString) ?? 0
    }
    
    func toDouble() -> Double {
        return Double(self) ?? 0.0
    }
    
    func removingSurroundingSingleQuotes() -> String {
        guard self.count >= 2 else { return self }
        if self.hasPrefix("'") && self.hasSuffix("'") {
            return String(self.dropFirst().dropLast())
        }
        return self
    }
    
    /// Format device name: Prefix + số → Prefix-000xx
    /// Ví dụ: "DAVINCI1" -> "DAVINCI-00001"
    func formattedDeviceName() -> String {
        // Tìm vị trí bắt đầu của phần số từ cuối
        var index = self.endIndex
        while index > self.startIndex {
            let prevIndex = self.index(before: index)
            if !self[prevIndex].isNumber {
                break
            }
            index = prevIndex
        }
        
        // Tách prefix và number
        let prefix = String(self[self.startIndex..<index])
        let numberPart = String(self[index..<self.endIndex])
        
        guard let num = Int(numberPart) else {
            return self // nếu không parse được số → trả về nguyên
        }
        
        return String(format: "\(prefix)-%05d", num)
    }
}

// MARK: - DOUBLE
extension Double {
    var cleanString: String {
        return self == floor(self) ? String(Int(self)) : String(format: "%.1f", self)
    }
}

// MARK: - CHART
extension LineChartView {
    func cloneChart() -> LineChartView {
        let cloned = LineChartView()
        
        cloned.data = self.data
        
        cloned.chartDescription.enabled = self.chartDescription.enabled
        cloned.legend.enabled = self.legend.enabled
        
        self.xAxis.cloneTo(cloned.xAxis)
        self.leftAxis.cloneTo(cloned.leftAxis)
        self.rightAxis.cloneTo(cloned.rightAxis)
        
        cloned.scaleXEnabled = self.scaleXEnabled
        cloned.scaleYEnabled = self.scaleYEnabled
        cloned.doubleTapToZoomEnabled = self.doubleTapToZoomEnabled
        cloned.pinchZoomEnabled = self.pinchZoomEnabled
        cloned.highlightPerDragEnabled = self.highlightPerDragEnabled
        cloned.highlightPerTapEnabled = self.highlightPerTapEnabled
        
        cloned.backgroundColor = self.backgroundColor
        
        
        cloned.drawGridBackgroundEnabled = drawGridBackgroundEnabled
        cloned.gridBackgroundColor = gridBackgroundColor
        
        cloned.dragEnabled = self.dragEnabled
        cloned.setScaleEnabled(self.isScaleXEnabled || self.isScaleYEnabled)
        
        // Copy marker if available
        if let marker = self.marker {
            cloned.marker = marker
        }
        
        return cloned
    }
}

extension XAxis {
    func cloneTo(_ target: XAxis) {
        target.enabled = self.enabled
        target.labelCount = self.labelCount
        target.forceLabelsEnabled = self.forceLabelsEnabled
        target.drawLabelsEnabled = self.drawLabelsEnabled
        target.drawAxisLineEnabled = self.drawAxisLineEnabled
        target.drawGridLinesEnabled = self.drawGridLinesEnabled
        target.drawLimitLinesBehindDataEnabled = self.drawLimitLinesBehindDataEnabled
        target.axisLineWidth = self.axisLineWidth
        target.axisLineColor = self.axisLineColor
        target.gridColor = self.gridColor
        target.gridLineWidth = self.gridLineWidth
        target.gridLineDashLengths = self.gridLineDashLengths
        target.gridLineDashPhase = self.gridLineDashPhase
        target.axisMinimum = self.axisMinimum
        target.axisMaximum = self.axisMaximum
        target.spaceMin = self.spaceMin
        target.spaceMax = self.spaceMax
        target.labelFont = self.labelFont
        target.labelTextColor = self.labelTextColor
        target.labelPosition = self.labelPosition
        target.xOffset = self.xOffset
        target.yOffset = self.yOffset
        target.valueFormatter = self.valueFormatter
        target.axisLineDashLengths = self.axisLineDashLengths
        target.axisLineDashPhase = self.axisLineDashPhase
        target.avoidFirstLastClippingEnabled = self.avoidFirstLastClippingEnabled
        target.granularityEnabled = self.granularityEnabled
        target.granularity = self.granularity
        target.labelRotationAngle = self.labelRotationAngle
        target.centerAxisLabelsEnabled = self.centerAxisLabelsEnabled
        target.wordWrapEnabled = self.wordWrapEnabled
        target.wordWrapWidthPercent = self.wordWrapWidthPercent
    }
}

extension YAxis {
    func cloneTo(_ target: YAxis) {
        target.enabled = self.enabled
        target.drawLabelsEnabled = self.drawLabelsEnabled
        target.drawAxisLineEnabled = self.drawAxisLineEnabled
        target.drawGridLinesEnabled = self.drawGridLinesEnabled
        target.drawZeroLineEnabled = self.drawZeroLineEnabled
        target.drawLimitLinesBehindDataEnabled = self.drawLimitLinesBehindDataEnabled
        target.axisLineWidth = self.axisLineWidth
        target.axisLineColor = self.axisLineColor
        target.gridColor = self.gridColor
        target.gridLineWidth = self.gridLineWidth
        target.gridLineDashLengths = self.gridLineDashLengths
        target.gridLineDashPhase = self.gridLineDashPhase
        target.zeroLineColor = self.zeroLineColor
        target.zeroLineWidth = self.zeroLineWidth
        target.zeroLineDashLengths = self.zeroLineDashLengths
        target.zeroLineDashPhase = self.zeroLineDashPhase
        target.labelFont = self.labelFont
        target.labelTextColor = self.labelTextColor
        target.xOffset = self.xOffset
        target.yOffset = self.yOffset
        target.axisMinimum = self.axisMinimum
        target.axisMaximum = self.axisMaximum
        target.spaceMin = self.spaceMin
        target.spaceMax = self.spaceMax
        target.inverted = self.inverted
        target.valueFormatter = self.valueFormatter
        target.axisLineDashLengths = self.axisLineDashLengths
        target.axisLineDashPhase = self.axisLineDashPhase
        target.drawTopYLabelEntryEnabled = self.drawTopYLabelEntryEnabled
        target.drawBottomYLabelEntryEnabled = self.drawBottomYLabelEntryEnabled
        target.labelPosition = self.labelPosition
        target.granularityEnabled = self.granularityEnabled
        target.granularity = self.granularity
    }
}

