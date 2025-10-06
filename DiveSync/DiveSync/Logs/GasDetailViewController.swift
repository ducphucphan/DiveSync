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
                                                  title: self.title ?? "Log - Gas Detail",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
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
        
        configGasInfo()
        
        maxTime = gasData.map { $0.time }.max() ?? 0
        maxGas = gasData.map { $0.gas }.max() ?? 0
        
        configureChart(with: gasData)
        
        lineChartView.isHidden = true
        switchesView.isHidden = true
        startDiveView.isHidden = true
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
        
        gasNoLb.text = String(format: "%@ %d - %@", "GAS", gasNo, Utilities.fo2GasValue(gasNo: gasNo, fo2: fo2))
        if mixesEnabled[gasNo] == false {
            gasNoLb.text = String(format: "%@ %d - %@", "GAS", gasNo, OFF)
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
        
        let dataSet = LineChartDataSet(entries: chartEntries, label: "Gas Used")
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
