//
//  GasDetailViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/10/25.
//

import UIKit
import DGCharts
import GRDB

class GasDetailViewController: BaseViewController {
    
    @IBOutlet var lineChartView: LineChartView!
    
    @IBOutlet weak var switchesView: UIView!
    @IBOutlet weak var startDiveView: UIView!
    
    @IBOutlet weak var gasNoLb: UILabel!
    
    @IBOutlet weak var tankCapacityLb: UILabel!
    @IBOutlet weak var tankTypeLb: UILabel!
    @IBOutlet weak var startPsiLb: UILabel!
    @IBOutlet weak var endPsiLb: UILabel!
    @IBOutlet weak var breathingTimeLb: UILabel!
    @IBOutlet weak var mdepthLb: UILabel!
    @IBOutlet weak var minDepthLb: UILabel!
    @IBOutlet weak var avgDepthLb: UILabel!
    @IBOutlet weak var sacLb: UILabel!
    @IBOutlet weak var rmvLb: UILabel!
    
    @IBOutlet weak var tankCapacityValueLb: UILabel!
    @IBOutlet weak var tankTypeValueLb: UILabel!
    @IBOutlet weak var startPsiValueLb: UILabel!
    @IBOutlet weak var endPsiValueLb: UILabel!
    @IBOutlet weak var breathingTimeValueLb: UILabel!
    @IBOutlet weak var mdepthValueLb: UILabel!
    @IBOutlet weak var minDepthValueLb: UILabel!
    @IBOutlet weak var avgDepthValueLb: UILabel!
    @IBOutlet weak var sacValueLb: UILabel!
    @IBOutlet weak var rmvValueLb: UILabel!
    
    var diveLog: Row!
    var gasNo: Int!
    
    var selectable = true
    
    var chartEntries: [ChartDataEntry] = []
    var xAsisValueLabelArray: [Int] = []
    
    var didSelectedChartEntryPoint: ((_ index: Int) -> Void)?
    var didShowDetail:(() -> Void)?
    
    var maxTime = 0.0
    var maxGas = 0.0
    
    var unitOfDive = M
    
    var tankId = 0
    
    var cylinderUnit = "L"
    var workingUnit = "BAR"
    
    let gasData: [(time: Double, gas: Double)] = [
        (0, 200),
        (30, 195),
        (60, 189),
        (90, 180),
        (120, 170),
        (150, 160),
        (180, 150),
        (210, 140),
        (240, 130),
        (270, 120)
    ]
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Log - Gas Details".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        if unitOfDive == FT {
            cylinderUnit = "CUFT"
            workingUnit = "PSI"
        }
        
        tankCapacityValueLb.text = "0 L, 0 BAR"
        if unitOfDive == FT {
            tankCapacityValueLb.text = "0 CUFT, 0 PSI"
        }
        
        tankTypeValueLb.text = "---"
        startPsiValueLb.text = "---"
        endPsiValueLb.text = "---"
        breathingTimeValueLb.text = "---"
        mdepthValueLb.text = "---"
        minDepthValueLb.text = "---"
        avgDepthValueLb.text = "---"
        sacValueLb.text = "0 BAR/MIN"
        rmvValueLb.text = "0 L/MIN"
        if unitOfDive == FT {
            sacValueLb.text = "0 PSI/MIN"
            rmvValueLb.text = "0 CUFT/MIN"
        }
        
        configTankInfo()
        configGasInfo()
        
        maxTime = gasData.map { $0.time }.max() ?? 0
        maxGas = gasData.map { $0.gas }.max() ?? 0
        
        configureChart(with: gasData)
        
        lineChartView.isHidden = true
        switchesView.isHidden = true
        startDiveView.isHidden = true
    }
    
    override func updateTexts() {
        super.updateTexts()
        
        tankCapacityLb.text = "Tank Capacity".localized
        tankTypeLb.text = "Tank Type".localized
        startPsiLb.text = "Start Pressure".localized
        endPsiLb.text = "End Pressure".localized
        breathingTimeLb.text = "Breathing Time".localized
        mdepthLb.text = "Max Depth".localized
        minDepthLb.text = "Min Depth".localized
        avgDepthLb.text = "Avg Depth".localized
        sacLb.text = "SAC".localized
        rmvLb.text = "Avg RMV".localized
    }
    
    private func configTankInfo() {
        if let tankRow = DatabaseManager.shared.fetchOrCreateTankData(tankNo: gasNo, diveId: diveLog.intValue(key: "DiveID")) {
            tankId = tankRow.intValue(key: "TankID")
            
            let tankNo = tankRow.stringValue(key: "TankNo").toInt()
            let TankUnit = tankRow.stringValue(key: "TankUnit").toInt()
            let DiveID = tankRow.stringValue(key: "DiveID").toInt()
            
            var CylinderSize = tankRow.stringValue(key: "CylinderSize")
            var WorkingPressure = tankRow.stringValue(key: "WorkingPressure")
            if unitOfDive == M {
                CylinderSize = formatNumber(convertCUFT2L(CylinderSize.toDouble()))
                WorkingPressure = formatNumber(convertPSI2BAR(WorkingPressure.toDouble()))
            } else {
                CylinderSize = formatNumber(CylinderSize.toDouble(), decimalIfNeeded: 0)
                WorkingPressure = formatNumber(WorkingPressure.toDouble(), decimalIfNeeded: 0)
            }
            self.tankCapacityValueLb.text = String(format: "%@ %@, %@ %@", CylinderSize, cylinderUnit, WorkingPressure, workingUnit)
            
            var TankType = tankRow.stringValue(key: "TankType")
            if TankType == "" {TankType = "---"}
            tankTypeValueLb.text = TankType
            
            // Start PSI
            var startPressureStr = tankRow.stringValue(key: "StartPressure")
            
            // End PSI
            var endPressureStr = tankRow.stringValue(key: "EndPressure")
            
            if unitOfDive == M {
                startPressureStr = formatNumber(convertPSI2BAR(startPressureStr.toDouble()))
                endPressureStr = formatNumber(convertPSI2BAR(endPressureStr.toDouble()))
            } else {
                startPressureStr = formatNumber(startPressureStr.toDouble(), decimalIfNeeded: 0)
                endPressureStr = formatNumber(endPressureStr.toDouble(), decimalIfNeeded: 0)
            }
            
            startPsiValueLb.text = String(format: "%@ %@", startPressureStr, unitOfDive == M ? "BAR":"PSI")
            endPsiValueLb.text = String(format: "%@ %@", endPressureStr, unitOfDive == M ? "BAR":"PSI")
            
            let BreathingMinutes = tankRow.stringValue(key: "BreathingMinutes").toInt()
            let BreathingSeconds = tankRow.stringValue(key: "BreathingSeconds").toInt()
            breathingTimeValueLb.text = String(format: "%02d:%02d", BreathingMinutes, BreathingSeconds)
            
            var maxDepthFT = tankRow.stringValue(key: "MaxDepth")
            var minDepthFT = tankRow.stringValue(key: "MinDepth")
            var avgDepthFT = tankRow.stringValue(key: "AvgDepth")
            
            if unitOfDive == M {
                maxDepthFT = formatNumber(converFeet2Meter(maxDepthFT.toDouble()))
                minDepthFT = formatNumber(converFeet2Meter(minDepthFT.toDouble()))
                avgDepthFT = formatNumber(converFeet2Meter(avgDepthFT.toDouble()))
            } else {
                maxDepthFT = formatNumber(maxDepthFT.toDouble(), decimalIfNeeded: 0)
                minDepthFT = formatNumber(minDepthFT.toDouble(), decimalIfNeeded: 0)
                avgDepthFT = formatNumber(avgDepthFT.toDouble(), decimalIfNeeded: 0)
            }
            mdepthValueLb.text = String(format: "%@ %@", maxDepthFT, unitOfDive == M ? "M":"FT")
            avgDepthValueLb.text = String(format: "%@ %@", avgDepthFT, unitOfDive == M ? "M":"FT")
            minDepthValueLb.text = String(format: "%@ %@", minDepthFT, unitOfDive == M ? "M":"FT")
            
            // SAC
            func calculateSacRate() -> Double {
                var btime = BreathingMinutes * 60 + BreathingSeconds
                
                if btime < 60 {
                    btime = 0
                } else {
                    btime /= 60
                }
                                
                var result = calculateSAC(
                    diveUnit: unitOfDive,
                    startPressure: startPressureStr.toDouble(),
                    endPressure: endPressureStr.toDouble(),
                    cylinderSize: CylinderSize.toDouble(),
                    time: Double(btime),
                    avgDepth: avgDepthFT.toDouble(),
                    workingPressure: WorkingPressure.toDouble()
                )
                
                if result.isNaN || result.isInfinite {
                    result = 0
                }
                return result
            }
            
            var sacValueStr = ""
            if unitOfDive == M {
                sacValueStr = formatNumber(calculateSacRate())
            } else {
                sacValueStr = formatNumber(calculateSacRate(), decimalIfNeeded: 0)
            }
            sacValueLb.text = String(format: "%@ %@", sacValueStr, unitOfDive == M ? "BAR/MIN":"PSI/MIN")
            
            // RMV
            func calculateRmvRate() -> Double {
                var btime = BreathingMinutes * 60 + BreathingSeconds
                
                if btime < 60 {
                    btime = 0
                } else {
                    btime /= 60
                }
                                
                var result = calculateRMV(
                    diveUnit: unitOfDive,
                    startPressure: startPressureStr.toDouble(),
                    endPressure: endPressureStr.toDouble(),
                    cylinderSize: CylinderSize.toDouble(),
                    time: Double(btime),
                    avgDepth: avgDepthFT.toDouble(),
                    workingPressure: WorkingPressure.toDouble()
                )
                
                if result.isNaN || result.isInfinite {
                    result = 0
                }
                return result
            }
            
            var rmvValueStr = ""
            if unitOfDive == M {
                rmvValueStr = formatNumber(calculateRmvRate())
            } else {
                rmvValueStr = formatNumber(calculateRmvRate(), decimalIfNeeded: 0)
            }
            rmvValueLb.text = String(format: "%@ %@", rmvValueStr, unitOfDive == M ? "L/MIN":"CUFT/MIN")
            
        }
    }
    
    private func configGasInfo() {
        
        let mixes = diveLog.stringValue(key: "EnabledMixes").toInt()
        var mixesEnabled: [Bool] = []
        for i in 0..<8 {
            mixesEnabled.append((mixes & (1 << i)) != 0)
        }
        
        var fo2 = 0
        var po2 = 0
        
        switch gasNo {
        case 1:
            po2 = diveLog.stringValue(key: "Mix1PpO2Barx100").toInt()
            fo2 = diveLog.stringValue(key: "Mix1Fo2Percent").toInt()
        case 2:
            po2 = diveLog.stringValue(key: "Mix2PpO2Barx100").toInt()
            fo2 = diveLog.stringValue(key: "Mix2Fo2Percent").toInt()
        case 3:
            po2 = diveLog.stringValue(key: "Mix3PpO2Barx100").toInt()
            fo2 = diveLog.stringValue(key: "Mix3Fo2Percent").toInt()
        case 4:
            po2 = diveLog.stringValue(key: "Mix4PpO2Barx100").toInt()
            fo2 = diveLog.stringValue(key: "Mix4Fo2Percent").toInt()
        default:
            break
        }
        
        gasNoLb.text = String(format: "%@ %d - %@", "Gas".localized.uppercased(), gasNo, Utilities.fo2GasValue(gasNo: gasNo, fo2: fo2))
        if mixesEnabled[gasNo] == false {
            gasNoLb.text = String(format: "%@ %d - %@", "Gas".localized.uppercased(), gasNo, OFF)
        }
        
    }
    
    @objc func deviceDidRotate() {
        let orientation = UIDevice.current.orientation

        switch orientation {
        case .landscapeLeft, .landscapeRight:
            showChartInFullScreen()
        default:
            break
        }
    }
    
    func showChartInFullScreen() {
        let fullVC = ChartFullScreenViewController()
        fullVC.modalPresentationStyle = .custom
        
        // Clone chart view
        fullVC.chartView = cloneChart() // Cần đảm bảo chartView trong ChartFullScreenViewController là `public`
        
        self.present(fullVC, animated: false);
    }
    
    // Hàm cập nhật dữ liệu
    func configureChart(with data:[(time: Double, gas: Double)]) {
        
        // Create an array of ChartDataEntry from dive data
        chartEntries = gasData.map { ChartDataEntry(x: $0.time, y: $0.gas) }
        
        let dataSet = LineChartDataSet(entries: chartEntries, label: "Gas Used".localized)
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = false
        dataSet.lineWidth = 1.2
        dataSet.setColor(UIColor.B_3)
        dataSet.fillAlpha = 0.3
        dataSet.drawFilledEnabled = false
        dataSet.fillColor = .systemBlue
        dataSet.valueTextColor = .clear
        
        // Gán dữ liệu vào biểu đồ
        let chartData = LineChartData(dataSet: dataSet)
        lineChartView.data = chartData
        
        // Add optional styling
        lineChartView.legend.enabled = false
        
        // Invert the y-axis if you want depth to increase downwards
        lineChartView.leftAxis.enabled = false
        lineChartView.rightAxis.enabled = true
        
        lineChartView.rightAxis.axisMinimum = 0
        lineChartView.rightAxis.axisMaximum = maxGas + 10 // Adjust as per max depth
        lineChartView.rightAxis.inverted = false
        lineChartView.rightAxis.labelTextColor = .white
        
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.axisMinimum = 0
        lineChartView.xAxis.axisMaximum = maxTime
        lineChartView.xAxis.granularityEnabled = true
        lineChartView.xAxis.granularity = 60 // Mỗi nhãn cách nhau xx giây --> sample rate
        lineChartView.xAxis.valueFormatter = DefaultAxisValueFormatter { (value, axis) -> String in
            let minutes = Int(value) / 60
            return "\(minutes)"
        }
        lineChartView.xAxis.labelTextColor = .white
        
        // Zoom
        lineChartView.scaleXEnabled = true        // Cho phép zoom theo trục X
        lineChartView.scaleYEnabled = false        // Cho phép zoom theo trục Y
        lineChartView.doubleTapToZoomEnabled = false // Cho phép zoom khi double-tap
        lineChartView.pinchZoomEnabled = true      // Cho phép zoom bằng 2 ngón tay
        lineChartView.highlightPerDragEnabled = true // Cho phép highlight khi kéo
        //
        
        if selectable == false {
            lineChartView.dragEnabled = false
            lineChartView.highlightPerTapEnabled = false
            
            //topButton.isHidden = false
        } else {
            //topButton.isHidden = true
        }
        
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
        
        // Tạo đường đứt nét
        let xAxis = lineChartView.xAxis
        xAxis.drawGridLinesEnabled = true
        xAxis.gridColor = .white
        xAxis.gridLineWidth = 1
        xAxis.gridLineDashLengths = [4, 2] // 4pt nét, 2pt khoảng trắng
        
        // Đứt nét trục Y trái
        let yAxis = lineChartView.leftAxis
        yAxis.drawGridLinesEnabled = true
        yAxis.gridColor = .white
        yAxis.gridLineDashLengths = [4, 2]
        
        // Set Maximum/Minimum zoom
        lineChartView.viewPortHandler.setMinimumScaleX(1.0) // Minimum zoom level for X-axis
        lineChartView.viewPortHandler.setMaximumScaleX(5.0) // Maximum zoom in the X direction
        
        // Create and set the custom marker
        let marker = CustomHighLightMarkerView()
        marker.chartView = lineChartView
        lineChartView.marker = marker
    }
    
    private func cloneChart() -> LineChartView {
        let clonedChart = LineChartView()

        // Copy data
        clonedChart.data = self.lineChartView.data

        // Copy chart style settings
        clonedChart.chartDescription.enabled = self.lineChartView.chartDescription.enabled
        clonedChart.legend.enabled = self.lineChartView.legend.enabled
        clonedChart.xAxis.labelPosition = self.lineChartView.xAxis.labelPosition
        clonedChart.xAxis.axisMinimum = self.lineChartView.xAxis.axisMinimum
        clonedChart.xAxis.axisMaximum = self.lineChartView.xAxis.axisMaximum
        clonedChart.xAxis.granularityEnabled = self.lineChartView.xAxis.granularityEnabled
        clonedChart.xAxis.granularity = self.lineChartView.xAxis.granularity
        clonedChart.xAxis.valueFormatter = self.lineChartView.xAxis.valueFormatter
        clonedChart.xAxis.labelTextColor = self.lineChartView.xAxis.labelTextColor

        clonedChart.rightAxis.enabled = self.lineChartView.rightAxis.enabled
        clonedChart.rightAxis.inverted = self.lineChartView.rightAxis.inverted
        clonedChart.rightAxis.axisMinimum = self.lineChartView.rightAxis.axisMinimum
        clonedChart.rightAxis.axisMaximum = self.lineChartView.rightAxis.axisMaximum
        clonedChart.rightAxis.labelTextColor = self.lineChartView.rightAxis.labelTextColor
        clonedChart.rightAxis.drawGridLinesEnabled = self.lineChartView.rightAxis.drawGridLinesEnabled
        clonedChart.rightAxis.drawLabelsEnabled = self.lineChartView.rightAxis.drawLabelsEnabled

        clonedChart.leftAxis.enabled = self.lineChartView.leftAxis.enabled

        // Zoom and gesture settings
        clonedChart.scaleXEnabled = self.lineChartView.scaleXEnabled
        clonedChart.scaleYEnabled = self.lineChartView.scaleYEnabled
        clonedChart.doubleTapToZoomEnabled = self.lineChartView.doubleTapToZoomEnabled
        clonedChart.pinchZoomEnabled = self.lineChartView.pinchZoomEnabled
        clonedChart.highlightPerDragEnabled = self.lineChartView.highlightPerDragEnabled
        clonedChart.highlightPerTapEnabled = self.lineChartView.highlightPerTapEnabled

        // Style
        clonedChart.backgroundColor = self.lineChartView.backgroundColor
        
        clonedChart.drawGridBackgroundEnabled = self.lineChartView.drawGridBackgroundEnabled
        clonedChart.gridBackgroundColor = self.lineChartView.gridBackgroundColor

        // Copy marker (if needed)
        if let marker = self.lineChartView.marker as? MarkerView {
            clonedChart.marker = marker
        }

        return clonedChart
    }
    
    @IBAction func buttonTapped(_ sender: Any) {
        if let button = sender as? UIButton {
            let buttonTag = button.tag
            switch buttonTag {
            case 0: // Tank Capacity
                
                // Tách theo dấu phẩy
                let parts = tankCapacityValueLb.text?.components(separatedBy: ",")

                if parts?.count == 2 {
                    // Lấy phần đầu: "0 CUFT"
                    let cuftString = parts?[0].trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: " ").first ?? "0"
                    // Lấy phần sau: "0 PSI"
                    let psiString = parts?[1].trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: " ").first ?? "0"
                    
                    // Convert sang số
                    let size = Double(cuftString) ?? 0
                    let pressure = Double(psiString) ?? 0
                 
                    TankCapacityInputAlert.showMessage(
                        message: "Tank Capacity".localized,
                        cylinderSize: size,
                        workingPressure: pressure,
                        unitOfDive: unitOfDive
                    ) { [self] action in
                        switch action {
                        case .set(let cylinderSize, let workingPressure):
                            self.tankCapacityValueLb.text = String(format: "%d %@, %d %@", cylinderSize, cylinderUnit, workingPressure, workingUnit)
                            
                            var sizeValueDouble = Double(cylinderSize)
                            var workingValueDouble = Double(workingPressure)
                            if unitOfDive == M {
                                sizeValueDouble = convertL2CUFT(sizeValueDouble)
                                workingValueDouble = convertUBAR2PSI(workingValueDouble)
                            }
                            self.saveTankData(key: "CylinderSize", value: sizeValueDouble)
                            self.saveTankData(key: "WorkingPressure", value: workingValueDouble)
                            
                        case .cancel:
                            break
                        }
                    }
                }
                break
            case 1: // Tank Type
                var tankTypeStr = tankTypeValueLb.text
                var tankTypeIndex = 0
                if tankTypeStr == alunium {
                    tankTypeIndex = 0
                    tankTypeStr = ""
                } else if tankTypeStr == steel {
                    tankTypeIndex = 1
                    tankTypeStr = ""
                } else {
                    tankTypeIndex = 2 // Other
                    if tankTypeStr == "---" { tankTypeStr = "" }
                }
                
                TankTypeAlert.show(title: "Tank Type".localized, selectedIndex: tankTypeIndex, otherText: tankTypeStr) { [self] action in
                    switch action {
                    case .cancel:
                        break
                    case .save(var text):
                        self.saveTankData(key: "TankType", value: text ?? "")
                        if text == "" { text = "---" }
                        tankTypeValueLb.text = text
                    }
                }
                break
            case 2: // Start Pressure
                let currentSP = (startPsiValueLb.text ?? "")
                    .components(separatedBy: " ")
                    .first
                    .flatMap { $0 == "---" ? "" : $0 } ?? ""
                let unitStr = unitOfDive == M ? "BAR":"PSI"
                //let notes = unitOfDive == M ? "* From 0 m to 999.9 m":"* From 0 ft to 3300 ft"
                MDepthInputAlert.showMessage(message: startPsiLb.text, selectedValue: currentSP, unitValue:unitStr) { [self] action, value in
                    self.startPsiValueLb.text = value + " " + unitStr
                    
                    var valueDouble = value.toDouble()
                    if unitOfDive == M {
                        valueDouble = convertUBAR2PSI(valueDouble)
                    }
                    self.saveTankData(key: "StartPressure", value: valueDouble)
                }
                break
            case 3: // End Pressure
                let currentEP = (endPsiValueLb.text ?? "")
                    .components(separatedBy: " ")
                    .first
                    .flatMap { $0 == "---" ? "" : $0 } ?? ""
                let unitStr = unitOfDive == M ? "BAR":"PSI"
                //let notes = unitOfDive == M ? "* From 0 m to 999.9 m":"* From 0 ft to 3300 ft"
                MDepthInputAlert.showMessage(message: endPsiLb.text, selectedValue: currentEP, unitValue:unitStr) { [self] action, value in
                    self.endPsiValueLb.text = value + " " + unitStr
                    
                    var valueDouble = value.toDouble()
                    if unitOfDive == M {
                        valueDouble = convertUBAR2PSI(valueDouble)
                    }
                    self.saveTankData(key: "EndPressure", value: valueDouble)
                }
                break
            case 4: // Breathing Time
                let timeString = breathingTimeValueLb.text ?? "00:00"
                let components = timeString.split(separator: ":")

                let minutes = Int(components.first ?? "0") ?? 0
                let seconds = Int(components.last ?? "0") ?? 0
                
                BreathingTimeInputAlert.showMessage(
                    message: "Breathing Time".localized,
                    minutes: minutes,
                    seconds: seconds
                ) { action in
                    switch action {
                    case .set(let mins, let secs):
                        self.breathingTimeValueLb.text = String(format: "%02d:%02d", mins, secs)
                        self.saveTankData(key: "BreathingMinutes", value: mins)
                        self.saveTankData(key: "BreathingSeconds", value: secs)
                    case .cancel:
                        break
                    }
                }
                break
            case 5: // Max Depth
                let currentMdepth = (mdepthValueLb.text ?? "")
                    .components(separatedBy: " ")
                    .first
                    .flatMap { $0 == "---" ? "" : $0 } ?? ""
                let unitStr = unitOfDive == M ? "M":"FT"
                MDepthInputAlert.showMessage(message: mdepthLb.text, selectedValue: currentMdepth, unitValue:unitStr) { [self] action, value in
                    self.mdepthValueLb.text = value + " " + unitStr
                    
                    var valueDouble = value.toDouble()
                    if unitOfDive == M {
                        valueDouble = convertMeter2Feet(valueDouble)
                    }
                    self.saveTankData(key: "MaxDepth", value: valueDouble)
                }
                break
            case 6: // Min Depth
                let currentMinDepth = (minDepthValueLb.text ?? "")
                    .components(separatedBy: " ")
                    .first
                    .flatMap { $0 == "---" ? "" : $0 } ?? ""
                let unitStr = unitOfDive == M ? "M":"FT"
                //let notes = unitOfDive == M ? "* From 0 m to 999.9 m":"* From 0 ft to 3300 ft"
                MDepthInputAlert.showMessage(message: minDepthLb.text, selectedValue: currentMinDepth, unitValue:unitStr) { [self] action, value in
                    self.minDepthValueLb.text = value + " " + unitStr
                    
                    var valueDouble = value.toDouble()
                    if unitOfDive == M {
                        valueDouble = convertMeter2Feet(valueDouble)
                    }
                    self.saveTankData(key: "MinDepth", value: valueDouble)
                }
                break
            case 7: // Avg Depth
                let currentAvgDepth = (avgDepthValueLb.text ?? "")
                    .components(separatedBy: " ")
                    .first
                    .flatMap { $0 == "---" ? "" : $0 } ?? ""
                let unitStr = unitOfDive == M ? "M":"FT"
                //let notes = unitOfDive == M ? "* From 0 m to 999.9 m":"* From 0 ft to 3300 ft"
                MDepthInputAlert.showMessage(message: avgDepthLb.text, selectedValue: currentAvgDepth, unitValue:unitStr) { [self] action, value in
                    self.avgDepthValueLb.text = value + " " + unitStr
                    
                    var valueDouble = value.toDouble()
                    if unitOfDive == M {
                        valueDouble = convertMeter2Feet(valueDouble)
                    }
                    self.saveTankData(key: "AvgDepth", value: valueDouble)
                }
                break
            default:
                break
            }
        }
    }
    
    private func saveTankData(key: String, value: Any) {
        DatabaseManager.shared.updateTable(tableName: "TankData",
                                           params: [key: value],
                                           conditions: "where TankID=\(tankId)")
        self.configTankInfo()
    }
}

extension GasDetailViewController: ChartViewDelegate {
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        PrintLog("Final zoom levels - X: \(chartView.viewPortHandler.scaleX), Y: \(chartView.viewPortHandler.scaleY)")
        
        lineChartView.xAxis.granularity = 60 * chartView.viewPortHandler.scaleX
        
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if let index = chartEntries.firstIndex(where: { $0.x == entry.x && $0.y == entry.y }) {
            PrintLog("Selected data index: \(index)")
            didSelectedChartEntryPoint?(index)
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
    }
}
