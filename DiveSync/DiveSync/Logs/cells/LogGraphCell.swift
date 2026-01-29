//
//  GrabCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/6/25.
//

import UIKit
import DGCharts
import GRDB

enum DiveStrokeState {
    case normal
    case ascentFast
    case deco
    case viol
}

struct DiveChartPoint {
    let entry: ChartDataEntry
    let alarmId: UInt8
    let alarmId2: UInt8
    let errors: UInt8
    let decoStopDepth: Int
}

class LogGraphCell: UICollectionViewCell {
    
    @IBOutlet var lineChartView: LineChartView!
    
    @IBOutlet weak var depthLb: UILabel!
    @IBOutlet weak var timeLb: UILabel!
    @IBOutlet weak var tempLb: UILabel!
    @IBOutlet weak var startTankLb: UILabel!
    @IBOutlet weak var endTankLb: UILabel!
    @IBOutlet weak var msgLb: UILabel!
    
    var diveChartPoints: [DiveChartPoint] = []
    var chartEntries: [ChartDataEntry] = []
    var xAsisValueLabelArray: [Int] = []
    
    var didSelectedChartEntryPoint: ((_ row: Row) -> Void)?
    var didShowDetail:(() -> Void)?
        
    var maxTime = 0.0
    var maxDepth = 0.0
        
    var diveLog:Row!
    
    var diveProfile: [Row] = [] {
        didSet {
            updateChartFromDiveProfile()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        updateChartFromDiveProfile()
        
    }
    
    func strokeState(prev: DiveChartPoint, curr: DiveChartPoint) -> DiveStrokeState {
        
        // OR để tránh mất alarm ở biên
        //let alarm1 = AlarmId1(rawValue: prev.alarmId | curr.alarmId)
        //let alarm2 = AlarmId2(rawValue: prev.alarmId2 | curr.alarmId2)
        let alarm1 = AlarmId1(rawValue: curr.alarmId)
        let errors = DiveErrors(rawValue: prev.errors | curr.errors)
        
        // VIOLATION → ascentFast
        if errors.isViolation {
            return .viol
        }
        
        // DECO → dựa vào decoStopDepth
        if curr.decoStopDepth > 0 && curr.decoStopDepth < 0xFFFF {
            return .deco
        }
        
        
        // ASCENT SPEED → ascentFast
        if alarm1.contains(.ascentSpeed) {
            return .ascentFast
        }
        
        return .normal
    }
    
    func updateChartFromDiveProfile() {
        guard !diveProfile.isEmpty else { return }

        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        let errors = diveLog.stringValue(key: "Errors").toInt()
        
        var diveChartPoints: [DiveChartPoint] = []
        
        diveChartPoints = diveProfile.compactMap { row in
            let time = row.stringValue(key: "DiveTime").toDouble()
            var depth = row.stringValue(key: "DepthFT").toDouble() / 10
            
            if unitOfDive == FT {
                depth = convertMeter2Feet(depth)
            }
            //let depthM = depthFT * 0.3048 // Feet → meters
            
            let alarmId = row.stringValue(key: "AlarmID").toInt()
            let alarmId2 = row.stringValue(key: "AlarmID2").toInt()
            let decoStopDepth = row.stringValue(key: "DecoStopDepthFT").toInt()
            
            return DiveChartPoint(
                entry: ChartDataEntry(x: time, y: depth),
                alarmId: UInt8(alarmId),
                alarmId2: UInt8(alarmId2),
                errors: UInt8(errors),
                decoStopDepth: decoStopDepth
            )
        }
        
        /*
        diveChartPoints.sort {
            $0.entry.x < $1.entry.x
        }
         */
        
        chartEntries.removeAll()
        chartEntries = diveChartPoints.map { $0.entry }
        
        /*
        for i in 1..<chartEntries.count {
            if chartEntries[i].x < chartEntries[i - 1].x {
                print("❌ X not sorted:",
                      chartEntries[i - 1].x,
                      "→",
                      chartEntries[i].x)
            }
        }
        */
        
        maxTime = chartEntries.map(\.x).max() ?? 0
        maxDepth = chartEntries.map(\.y).max() ?? 0
        
        let fillSet = LineChartDataSet(entries: chartEntries, label: "")
        fillSet.mode = .linear
        fillSet.drawCirclesEnabled = false
        fillSet.lineWidth = 1.2
        fillSet.setColor(UIColor.B_3)
        fillSet.fillAlpha = 1
        fillSet.drawFilledEnabled = true
        fillSet.fillColor = UIColor.B_3
        fillSet.valueTextColor = .clear
        
        ///
        var dataSets: [LineChartDataSet] = []
        dataSets.append(fillSet)

        // ---- THÊM TỪ ĐÂY ----

        var currentEntries: [ChartDataEntry] = []
        var currentState: DiveStrokeState?

        func color(for state: DiveStrokeState) -> UIColor {
            switch state {
            case .normal:
                return UIColor.B_3          // giống fill
            case .ascentFast:
                return .yellow
            case .deco:
                return .red
            case .viol:
                return UIColor(red: 0.6, green: 0, blue: 0, alpha: 1) // đỏ đậm
            }
        }

        for i in 1..<diveChartPoints.count {
            let prev = diveChartPoints[i - 1]
            let curr = diveChartPoints[i]

            let state = strokeState(
                prev: prev,
                curr: curr
            )

            if currentState == nil {
                currentState = state
                currentEntries = [prev.entry, curr.entry]
                continue
            }

            if state != currentState {
                /*
                let set = LineChartDataSet(entries: currentEntries, label: "")
                set.drawCirclesEnabled = false
                set.drawValuesEnabled = false
                set.lineWidth = 1.2
                set.setColor(color(for: currentState!))
                dataSets.append(set)
                */
                let sets = makeStrokeSets(
                    entries: currentEntries,
                    baseColor: color(for: currentState!)
                )
                dataSets.append(contentsOf: sets)
                
                currentEntries = [prev.entry, curr.entry]
                currentState = state
            } else {
                currentEntries.append(curr.entry)
            }
        }

        // append đoạn cuối
        if let state = currentState {
            /*
            let set = LineChartDataSet(entries: currentEntries, label: "")
            set.drawCirclesEnabled = false
            set.drawValuesEnabled = false
            set.drawFilledEnabled = false
            set.lineWidth = 1.2
            set.setColor(color(for: state))
            dataSets.append(set)
            */
            let sets = makeStrokeSets(
                entries: currentEntries,
                baseColor: color(for: state)
            )
            dataSets.append(contentsOf: sets)
        }
        
        // Gán dữ liệu vào biểu đồ
        lineChartView.data = LineChartData(dataSets: dataSets)
        //lineChartView.data = LineChartData(dataSet: fillSet)
        
        // Add optional styling
        lineChartView.legend.enabled = false
        
        // Invert the y-axis if you want depth to increase downwards
        lineChartView.leftAxis.enabled = false
        lineChartView.leftAxis.inverted = true
        
        lineChartView.rightAxis.enabled = true
        lineChartView.rightAxis.axisMinimum = 0
        lineChartView.rightAxis.axisMaximum = ceil(maxDepth) // Adjust as per max depth
        lineChartView.rightAxis.inverted = true
        lineChartView.rightAxis.labelTextColor = .white
        
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.axisMinimum = 0
        lineChartView.xAxis.axisMaximum = maxTime
        lineChartView.xAxis.granularityEnabled = true
        lineChartView.xAxis.labelTextColor = .white
        lineChartView.xAxis.setLabelCount(6, force: true)
        lineChartView.xAxis.valueFormatter = DefaultAxisValueFormatter { [maxTime] (value, _) -> String in
            let time = Int(value.rounded())
            
            // Ẩn nhãn tại x = 0 và x = maxTime (cuối)
            if time <= 0 || time >= Int(maxTime) {
                return ""
            }
            
            if maxTime <= 3600 {
                return String(format: "%02d:%02d", time / 60, time % 60)
            } else {
                return String(format: "%02d:%02d", time / 3600, (time % 3600) / 60)
            }
        }
        
        // Zoom
        lineChartView.scaleXEnabled = false        // Cho phép zoom theo trục X
        lineChartView.scaleYEnabled = false        // Cho phép zoom theo trục Y
        lineChartView.doubleTapToZoomEnabled = false // Cho phép zoom khi double-tap
        lineChartView.pinchZoomEnabled = false      // Cho phép zoom bằng 2 ngón tay
        lineChartView.highlightPerDragEnabled = true // Cho phép highlight khi kéo
        //
        
        // Hide vertical grid lines (X-axis)
        lineChartView.xAxis.drawGridLinesEnabled = true
        lineChartView.xAxis.gridColor = .white
        
        lineChartView.delegate = self // Set delegate
        
        lineChartView.backgroundColor = UIColor.B_3
        
        lineChartView.drawGridBackgroundEnabled = true
        lineChartView.gridBackgroundColor = UIColor.B_1
        
        // Cấu hình trục phải
        lineChartView.rightAxis.enabled = true
        lineChartView.rightAxis.drawLabelsEnabled = true
        lineChartView.rightAxis.drawGridLinesEnabled = true
        lineChartView.rightAxis.gridColor = .white
        
        lineChartView.dragEnabled = false
        lineChartView.highlightPerDragEnabled = false
        
        // Tạo đường đứt nét
        let xAxis = lineChartView.xAxis
        xAxis.drawGridLinesEnabled = true
        xAxis.gridColor = .white
        xAxis.gridLineWidth = 1
        xAxis.gridLineDashLengths = [4, 2] // 4pt nét, 2pt khoảng trắng
        
        // Đứt nét trục Y trái
        /*
        let yAxis = lineChartView.leftAxis
        yAxis.drawGridLinesEnabled = true
        yAxis.gridColor = .white
        yAxis.gridLineWidth = 1
        yAxis.gridLineDashLengths = [4, 2]
        */
        
        // Set Maximum/Minimum zoom
        lineChartView.viewPortHandler.setMinimumScaleX(1.0) // Minimum zoom level for X-axis
        lineChartView.viewPortHandler.setMaximumScaleX(5.0) // Maximum zoom in the X direction
        
        // Create and set the custom marker
        let marker = CustomHighLightMarkerView()
        marker.chartView = lineChartView
        lineChartView.marker = marker
        
        /*
        let marker = DiveMarkerView()
        marker.chartView = lineChartView
        marker.diveRows = diveProfile
        marker.diveLog = diveLog
        marker.chartEntries = chartEntries
        lineChartView.marker = marker
        */
        
        // Custom chổ này để bỏ đường đứt nét tại vị trí zero, thay vào đó là đường bình thường không đứt nét.
        lineChartView.xAxisRenderer = CustomXAxisRenderer(viewPortHandler: lineChartView.viewPortHandler, axis: lineChartView.xAxis, transformer: lineChartView.getTransformer(forAxis: .left))
    }
    
    func roundedGranularity(_ value: Double) -> Double {
        for scale in stride(from: 10, through: 3600, by: 10) {
            if value <= Double(scale) {
                return Double(scale)
            }
        }
        return 3600
    }
}

// MARK - CHART
extension LogGraphCell: ChartViewDelegate {
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        PrintLog("Final zoom levels - X: \(chartView.viewPortHandler.scaleX), Y: \(chartView.viewPortHandler.scaleY)")
        
        lineChartView.xAxis.granularity = 60 * chartView.viewPortHandler.scaleX
        
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if let index = chartEntries.firstIndex(where: { $0.x == entry.x && $0.y == entry.y }) {
            PrintLog("Selected data index: \(index)")
            let selectedRow = diveProfile[index]
            
            let alarmString = buildAlarmString(
                alarmId1: selectedRow.stringValue(key: "ALARMID"),
                alarmId2: selectedRow.stringValue(key: "ALARMID2")
            )
            
            msgLb.text = alarmString
            
            let unit = diveLog.stringValue(key: "Units").toInt()
            let DepthFT = selectedRow.stringValue(key: "DepthFT").toDouble() / 10
            if unit == FT {
                depthLb.text = formatNumber(convertMeter2Feet(DepthFT), decimalIfNeeded: 0) + " " + "FT"
            } else {
                depthLb.text = formatNumber(DepthFT) + " " + "M"
            }
            
            let DiveTime = selectedRow.stringValue(key: "DiveTime").toInt()
            if DiveTime <= 3600 {
                timeLb.text = String(format: "%02d:%02d", DiveTime / 60, DiveTime % 60)
            } else {
                timeLb.text = String(format: "%02d:%02d", DiveTime / 3600, (DiveTime % 3600) / 60)
            }
            
            
            let TemperatureF = selectedRow.stringValue(key: "TemperatureF").toDouble() / 10
            if unit == FT {
                tempLb.text = formatNumber(convertMeter2Feet(TemperatureF), decimalIfNeeded: 0) + " " + "°F"
            } else {
                tempLb.text = formatNumber(TemperatureF) + " " + "°C"
            }
            
            var TankPSI = selectedRow.stringValue(key: "TankPSI").toInt()
            if TankPSI == 0xFFFF {
                TankPSI = 0
            }
            if unit == FT {
                startTankLb.text = String(format: "%d PSI", TankPSI)
            } else {
                startTankLb.text = String(format: "%.1f BAR", convertPSI2BAR(Double(TankPSI)))
            }
            
            didSelectedChartEntryPoint?(selectedRow)
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        
        depthLb.text = "---"
        timeLb.text = "---"
        tempLb.text = "---"
        startTankLb.text = "---"
        endTankLb.text = "---"
        
    }
}

extension LogGraphCell {
    func makeStrokeSets(
        entries: [ChartDataEntry],
        baseColor: UIColor
    ) -> [LineChartDataSet] {

        // Line nền (nhạt – dày → giả bóng)
        let soft = LineChartDataSet(entries: entries, label: "")
        soft.drawCirclesEnabled = false
        soft.drawValuesEnabled = false
        soft.drawFilledEnabled = false
        soft.lineWidth = 3.0
        soft.mode = .cubicBezier
        soft.setColor(baseColor.withAlphaComponent(0.33))
        
        // Line chính (đậm – mỏng)
        let sharp = LineChartDataSet(entries: entries, label: "")
        sharp.drawCirclesEnabled = false
        sharp.drawValuesEnabled = false
        sharp.drawFilledEnabled = false
        sharp.lineWidth = 1.2
        soft.mode = .cubicBezier
        sharp.setColor(baseColor)

        return [soft, sharp]
    }
}

class CustomXAxisRenderer: XAxisRenderer {
    override func renderGridLines(context: CGContext) {
        guard axis.isEnabled,
              axis.drawGridLinesEnabled,
              !axis.entries.isEmpty else { return }

        context.saveGState()
        context.setShouldAntialias(axis.gridAntialiasEnabled)
        context.setStrokeColor(axis.gridColor.cgColor)
        context.setLineWidth(axis.gridLineWidth)

        let positions = axis.entries.map { entry in
            transformer?.pixelForValues(x: entry, y: 0) ?? .zero
        }

        for (i, position) in positions.enumerated() {
            let entry = axis.entries[i]

            let yStart = viewPortHandler.contentTop
            let yEnd = viewPortHandler.contentBottom

            // ✅ Nếu là trục X tại 0 → vẽ đường liền
            if entry == 0 {
                context.setLineDash(phase: 0, lengths: []) // đường liền
            } else {
                context.setLineDash(phase: 0, lengths: axis.gridLineDashLengths ?? [])
            }

            context.beginPath()
            context.move(to: CGPoint(x: position.x, y: yStart))
            context.addLine(to: CGPoint(x: position.x, y: yEnd))
            context.strokePath()
        }

        context.restoreGState()
    }
}

// MARK: - Custom Tooltip Marker
class DiveMarkerView: MarkerView {
    private var text: String = ""
    private var attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: UIColor.white
    ]
    
    var diveLog: Row!
    var diveRows: [Row] = []
    var chartEntries: [ChartDataEntry] = []
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        if let index = chartEntries.firstIndex(where: { $0.x == entry.x && $0.y == entry.y }) {
            let row = diveRows[index]
            
            let unitOfDive = diveLog.stringValue(key: "Units").toInt()
            let time = row.stringValue(key: "DiveTime").toInt()
            var depth = row.stringValue(key: "DepthFT").toDouble()/10
            var depthString = ""
            var tempString = ""
            
            if unitOfDive == FT {
                depth = convertMeter2Feet(depth)
            }
            
            if unitOfDive == M {
                depthString = formatNumber(depth)
            } else {
                depthString = formatNumber(depth, decimalIfNeeded: 0)
            }
            
            depthString = depthString + " " + ((unitOfDive == FT) ? "FT":"M")
            
            
            let temp  = row.stringValue(key: "TemperatureF").toDouble()
            
            let min = time / 60
            let sec = time % 60
            
            text =
                        """
                        ⏱ \(String(format: "%02d:%02d", min, sec))
                        ⬇️ Depth: \(depthString)
                        🌡 Temp: \(temp/10) °C
                        """
        } else {
            text = ""
        }
        setNeedsDisplay()
    }
    
    // Tìm điểm gần nhất trên viền rect để nối line
        private func nearestPointOnRectEdge(from point: CGPoint, rect: CGRect) -> CGPoint {
            let clampedX = min(max(point.x, rect.minX), rect.maxX)
            let clampedY = min(max(point.y, rect.minY), rect.maxY)
            
            let left   = CGPoint(x: rect.minX, y: clampedY)
            let right  = CGPoint(x: rect.maxX, y: clampedY)
            let top    = CGPoint(x: clampedX, y: rect.minY)
            let bottom = CGPoint(x: clampedX, y: rect.maxY)
            
            let candidates = [left, right, top, bottom]
            return candidates.min(by: {
                hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y)
            }) ?? rect.origin
        }
        
        // Vẽ tooltip + line
        override func draw(context: CGContext, point: CGPoint) {
            guard !text.isEmpty else { return }
            
            let padding: CGFloat = 6
            let textSize = (text as NSString).boundingRect(
                with: CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: attributes,
                context: nil
            ).size
            
            let boxSize = CGSize(width: textSize.width + padding * 2,
                                 height: textSize.height + padding * 2)
            
            guard let chart = chartView else { return }
            let chartWidth = chart.bounds.width
            let chartHeight = chart.bounds.height
            
            var origin = CGPoint(x: point.x + 8, y: point.y - boxSize.height - 8) // mặc định: trên-phải
            
            // Điều chỉnh nếu tooltip bị tràn chart
            if origin.x + boxSize.width > chartWidth {
                origin.x = point.x - boxSize.width - 8
            }
            if origin.y < 0 {
                origin.y = point.y + 8
            }
            if origin.x < 0 {
                origin.x = point.x + 8
            }
            if origin.y + boxSize.height > chartHeight {
                origin.y = point.y - boxSize.height - 8
            }
            
            let rect = CGRect(origin: origin, size: boxSize)
            let tooltipColor = UIColor.black.withAlphaComponent(0.7)
            
            // Tooltip background
            context.setFillColor(tooltipColor.cgColor)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
            context.addPath(path.cgPath)
            context.fillPath()
            
            // Connector line
            let anchor = nearestPointOnRectEdge(from: point, rect: rect)
            context.setStrokeColor(tooltipColor.cgColor)
            context.setLineWidth(1.0)
            context.beginPath()
            context.move(to: point)
            context.addLine(to: anchor)
            context.strokePath()
            
            // Optional: vẽ dot ở point cho rõ
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            
            // Text
            (text as NSString).draw(
                in: rect.insetBy(dx: padding, dy: padding),
                withAttributes: attributes
            )
        }


    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        // mặc định nằm trên điểm chạm
        return CGPoint(x: -50, y: -60)
    }
}
