import UIKit
import GRDB
import DGCharts

class ChartFullScreenViewController: UIViewController {

    var chartView: LineChartView? // Được truyền từ GasDetailViewController
    var chartEntries: [ChartDataEntry] = []
    var diveProfile: [Row] = []
    var diveLog:Row!
    
    @IBOutlet weak var chartViewContent: UIView!
    @IBOutlet weak var bottomView: UIView!
    
    @IBOutlet weak var msgLb: UILabel!
    @IBOutlet weak var warningImv: UIImageView!
    @IBOutlet weak var depthLb: UILabel!
    @IBOutlet weak var timeLb: UILabel!
    @IBOutlet weak var tempLb: UILabel!
    @IBOutlet weak var startTankLb: UILabel!
    @IBOutlet weak var endTankLb: UILabel!
    
    private var alarmTimer: Timer?
    private var alarmIndex = 0
    private var currentAlarms: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.B_3
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        warningImv.isHidden = true

        // Add chart view if available
        if let chartView = chartView {
            chartView.delegate = self
            chartView.translatesAutoresizingMaskIntoConstraints = false
            chartViewContent.addSubview(chartView)

            NSLayoutConstraint.activate([
                chartView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
                chartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                chartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                chartView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottomView.frame.height)
            ])
        }
        
        
    }
    
    @objc func deviceDidRotate() {
        let orientation = UIDevice.current.orientation

        switch orientation {
        case .portrait, .portraitUpsideDown:
            self.dismissSelf()
        default:
            break
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true) {
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var shouldAutorotate: Bool {
        return true
    }
}

// MARK - CHART
extension ChartFullScreenViewController: ChartViewDelegate {
    
    func showAlarms(_ alarms: [String]) {
        alarmTimer?.invalidate()
        alarmTimer = nil
        alarmIndex = 0
        currentAlarms = alarms
        
        warningImv.isHidden = alarms.isEmpty

        guard !alarms.isEmpty else {
            msgLb.text = ""
            return
        }

        // Chỉ 1 alarm → hiển thị luôn
        if alarms.count == 1 {
            msgLb.text = alarms[0]
            return
        }

        // Nhiều alarm → flash mỗi 1s
        msgLb.text = alarms[0]

        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.alarmIndex = (self.alarmIndex + 1) % self.currentAlarms.count
            self.msgLb.text = self.currentAlarms[self.alarmIndex]
        }
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if let index = chartEntries.firstIndex(where: { $0.x == entry.x && $0.y == entry.y }) {
            PrintLog("Selected data index: \(index)")
            let selectedRow = diveProfile[index]
            
            let alarms = buildAlarmString(
                alarmId1: selectedRow.stringValue(key: "ALARMID"),
                alarmId2: selectedRow.stringValue(key: "ALARMID2")
            )
            showAlarms(alarms)
            
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
