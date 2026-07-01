//
//  LogViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/5/25.
//

import UIKit
import GRDB
import ProgressHUD

class LogViewController: BaseViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var pageControl: UIPageControl!
    
    @IBOutlet weak var favoriteBtn: UIButton!
    
    @IBOutlet weak var diveOfTheDayLb: UILabel!
    @IBOutlet weak var spotNameLb: UILabel!
    @IBOutlet weak var diveNameLb: UILabel!
    
    @IBOutlet weak var diveDateLb: UILabel!
    @IBOutlet weak var altLevelLb: UILabel!
    @IBOutlet weak var modeLb: UILabel!
    @IBOutlet weak var diveStatusLb: UILabel!
    @IBOutlet weak var consValueLb: UILabel!
    @IBOutlet weak var siValueLb: UILabel!
    @IBOutlet weak var sdvaLueLb: UILabel!
    @IBOutlet weak var dtValueLb: UILabel!
    @IBOutlet weak var mdepthValueLb: UILabel!
    @IBOutlet weak var ltbgValueLb: UILabel!
    @IBOutlet weak var ascValueLb: UILabel!
    @IBOutlet weak var minTempValueLb: UILabel!
    @IBOutlet weak var maxTempValueLb: UILabel!
    @IBOutlet weak var oxtoxValueLb: UILabel!
    @IBOutlet weak var maxPo2ValueLb: UILabel!
    @IBOutlet weak var startGasValueLb: UILabel!
    @IBOutlet weak var endGasValueLb: UILabel!
    
    @IBOutlet weak var topView: UIView!
    
    @IBOutlet weak var gasDetailsView: UIView!
    @IBOutlet weak var settingsUsedView: UIView!
    
    @IBOutlet weak var startEndGasStackView: UIStackView!
    @IBOutlet weak var conservatismStackView: UIStackView!
    
    @IBOutlet weak var graphHeightContraints: NSLayoutConstraint!
    
    //
    @IBOutlet weak var dateLb: UILabel!
    @IBOutlet weak var altitudeLb: UILabel!
    @IBOutlet weak var modeTitleLb: UILabel!
    @IBOutlet weak var diveStatusTitleLb: UILabel!
    @IBOutlet weak var siTitleLb: UILabel!
    @IBOutlet weak var startDiveTitleLb: UILabel!
    @IBOutlet weak var diveTimeLb: UILabel!
    @IBOutlet weak var mdepthLb: UILabel!
    @IBOutlet weak var tlbgLb: UILabel!
    @IBOutlet weak var maxAscLb: UILabel!
    @IBOutlet weak var minTempLb: UILabel!
    @IBOutlet weak var maxTempLb: UILabel!
    @IBOutlet weak var oxtoxLb: UILabel!
    @IBOutlet weak var maxPo2Lb: UILabel!
    @IBOutlet weak var startGasLb: UILabel!
    @IBOutlet weak var endGasLb: UILabel!
    @IBOutlet weak var conservatismLb: UILabel!
    @IBOutlet weak var gasDetailLb: UILabel!
    @IBOutlet weak var settingsUsedLb: UILabel!
    @IBOutlet weak var diveSpotLb: UILabel!
    @IBOutlet weak var photosLb: UILabel!
    @IBOutlet weak var memoLb: UILabel!
    @IBOutlet weak var shareLb: UILabel!
    @IBOutlet weak var exportLb: UILabel!
    
    @IBOutlet weak var mainMetricsStackView: UIStackView!
    
    //
    
    enum MetricType: Int {
        case diveDate = 1, altitude = 2, mode = 3, conservatism = 4, surfaceInterval = 5
        case startDive = 6, diveTime = 7, maxDepth = 8, tlbg = 9, maxAscRate = 10
        case minTemp = 11, maxTemp = 12, oxtox = 13, maxPo2 = 14, startGas = 15, endGas = 16
        case diveStatus = 17, maxDescRate = 18, avgDepth = 19
    }

    struct MetricModel {
        let type: MetricType
        let title: String
        let value: String
        let iconName: String
    }
    
    
    //let fullVC = ChartFullScreenViewController()
    
    lazy var fullVC: ChartFullScreenViewController = {
        let storyboard = UIStoryboard(name: "FullView", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ChartFullScreenViewController") as! ChartFullScreenViewController
        return vc
    }()
    
    var numberOfPages = 3
    
    var isFavorite = false
    
    var diveLog: Row!
    var diveProfile:[Row] = []
    
    var photos: [URL] = []
    
    var onUpdated: ((Bool) -> Void)?
    
    var manualDive: Bool = false
    
    private var modelId = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Log".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        topView.layer.shadowColor = UIColor.black.cgColor
        topView.layer.shadowOpacity = 0.3   // độ mờ (0 → 1)
        topView.layer.shadowOffset = CGSize(width: 0, height: 2) // đổ bóng xuống dưới
        topView.layer.shadowRadius = 4      // độ tán bóng
        topView.layer.masksToBounds = false
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            graphHeightContraints.constant = (UIScreen.main.bounds.height / 2)
        }
        
        pageControl.addTarget(self, action: #selector(pageControlTapped(_:)), for: .valueChanged)
        
        let diveMode = diveLog.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 {
            manualDive = true
            startEndGasStackView.isHidden = true
            conservatismStackView.backgroundColor = .clear
        }
        
        modelId = diveLog.stringValue(key: "ModelID").toInt()
        
        switch modelId {
        case C_CEN, C_GRA, C_LOG, C_LOGPLUS:
            gasDetailsView.isHidden = true
            settingsUsedView.isHidden = true
            
            maxAscLb.text = "Max Ascent Rate".localized
        default:
            maxAscLb.text = "Max Ascent Bar".localized
            break
        }
        
        fillDiveData()
        
        if manualDive {
            numberOfPages = 2
            settingsUsedView.isHidden = true
        } else {
            loadDiveProfile(diveId: diveLog.intValue(key: "DiveID"))
        }
        
        loadPhotos()
        
        setupCollectionVIew()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        self.setupFlexibleMetrics()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? LogGraphCell else {
            return
        }
        
        fullVC.modalPresentationStyle = .custom
        
        // Clone chart view
        let clonedChart = cell.lineChartView.cloneChart()
        fullVC.chartView = clonedChart // Cần đảm bảo chartView trong ChartFullScreenViewController là `public`
        fullVC.chartEntries = cell.chartEntries
        fullVC.diveProfile = diveProfile
        fullVC.diveLog = diveLog
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        enlargePageControlDots(pageControl, scale: 1.5)
    }
    
    override func updateTexts() {
        super.updateTexts()
        
        dateLb.text = "Date".localized
        altitudeLb.text = "Altitude Level".localized
        modeTitleLb.text = "Mode".localized
        diveStatusTitleLb.text = "Dive Status".localized
        siTitleLb.text = "Surface Interval".localized
        startDiveTitleLb.text = "Start Dive".localized
        diveTimeLb.text = "Dive Time".localized
        mdepthLb.text = "Max Depth".localized
        tlbgLb.text = "TLBG Bar".localized
        maxAscLb.text = "Max Ascent Bar".localized
        minTempLb.text = "Min Temperature".localized
        maxTempLb.text = "Max Temperature".localized
        oxtoxLb.text = "OXTOX end dive".localized
        maxPo2Lb.text = "Max PPO2".localized
        startGasLb.text = "Start Gas".localized
        endGasLb.text = "End Gas".localized
        conservatismLb.text = "Conservatism".localized
        gasDetailLb.text = "Gas Details".localized
        settingsUsedLb.text = "Settings Used".localized
        diveSpotLb.text = "Dive Spot".localized
        photosLb.text = "Photos".localized
        memoLb.text = "Memo".localized
        shareLb.text = "Share".localized
        exportLb.text = "Export".localized
    }
    
    
    private func getActiveMetrics() -> [MetricModel] {
        var list: [MetricModel] = []
        
        let _date = MetricModel(type: .diveDate, title: "Date".localized, value: getFormattedDate(), iconName: "date")
        let _alt = MetricModel(type: .altitude, title: "Altitude Level".localized, value: getAltitudeLevel(), iconName: "altitude")
        let _mode = MetricModel(type: .mode, title: "Mode".localized, value: self.getMode(), iconName: "mode")
        let _diveStatus = MetricModel(type: .diveStatus, title: "Dive Status".localized, value: self.getDiveStatus(), iconName: "dive_status")
        let _surfaceInterval = MetricModel(type: .surfaceInterval, title: "Surface Interval".localized, value: getSurfaceInterval(), iconName: "serface_interval")
        let _startDive = MetricModel(type: .startDive, title: "Start Dive".localized, value: getFormattedStartDiveTime(), iconName: "start_dive")
        let _diveTime = MetricModel(type: .diveTime, title: "Dive Time".localized, value: getDiveTime(), iconName: "dive_time")
        let _maxDepth = MetricModel(type: .maxDepth, title: "Max Depth".localized, value: getMaxDepth(), iconName: "max_depth")
        let _avgDepth = MetricModel(type: .avgDepth, title: "Avg Depth".localized, value: getAvgDepth(), iconName: "max_depth")
        let _tlbg = MetricModel(type: .tlbg, title: "Max TLBG".localized, value: getMaxTLBG(), iconName: "tlbg")
        let _maxAsc = MetricModel(type: .maxAscRate, title: "Max Ascent Rate".localized, value: getMaxAscRate(), iconName: "max_accent_rate")
        let _maxAscBar = MetricModel(type: .maxAscRate, title: "Max Ascent Bar".localized, value: getMaxAscBar(), iconName: "max_accent_rate")
        let _maxDesc = MetricModel(type: .oxtox, title: "Max Descent Rate".localized, value: getMaxDescRate(), iconName: "max_accent_rate")
        let _minTemp = MetricModel(type: .minTemp, title: "Min Temperature".localized, value: getMinTemp(), iconName: "min_temp")
        let _maxTemp = MetricModel(type: .maxTemp, title: "Max Temperature".localized, value: getMaxTemp(), iconName: "max_temp")
        let _oxtox = MetricModel(type: .oxtox, title: "OXTOX end dive".localized, value: getOXTOX(), iconName: "o2")
        let _maxPPO2 = MetricModel(type: .maxPo2, title: "Max PPO2".localized, value: getMaxPPO2(), iconName: "max_po2")
        let _startGas = MetricModel(type: .startGas, title: "Start Gas".localized, value: getStartGas(), iconName: "start_gas")
        let _endGas = MetricModel(type: .endGas, title: "End Gas".localized, value: getEndGas(), iconName: "end_gas")
        let _conservatism = MetricModel(type: .conservatism, title: "Conservatism".localized, value: getConservatism(), iconName: "conservatism")
        
        switch modelId {
            
        case C_LOG, C_LOGPLUS:
            
            list.append(contentsOf: [
                _date,
                _mode,
                _diveStatus,
                _conservatism,
                _surfaceInterval,
                _startDive,
                _diveTime,
                _maxDepth,
                _avgDepth,
                _maxAsc,
                _maxDesc,
                _minTemp,
                _maxTemp
            ])
            
        case C_GRA:
            
            list.append(contentsOf: [
                _date,
                _mode,
                _diveStatus,
                _conservatism,
                _surfaceInterval,
                _startDive,
                _diveTime,
                _maxDepth,
                _avgDepth,
                _maxAsc,
                _maxDesc,
                _minTemp
            ])
            
        case C_CEN:
            
            list.append(contentsOf: [
                _date,
                _mode,
                _diveStatus,
                _conservatism,
                _surfaceInterval,
                _startDive,
                _diveTime,
                _maxDepth,
                _avgDepth,
                _minTemp
            ])
            
        default:
            
            list.append(contentsOf: [
                _date,
                _alt,
                _mode,
                _diveStatus,
                _surfaceInterval,
                _startDive,
                _diveTime,
                _maxDepth,
                _avgDepth,
                _tlbg,
                _maxAscBar,
                _minTemp,
                _maxTemp,
                _oxtox,
                _maxPPO2,
                _startGas,
                _endGas,
                _conservatism
            ])
        }
        
        if manualDive {
            list = list.filter { $0.type != .avgDepth }
        }
        
        return list
        /*
        // Luôn hiển thị Date (Tag 1)
        list.append(MetricModel(type: .diveDate, title: "Date".localized, value: getFormattedDate(), iconName: "date"))
        
        // Altitude (Tag 2) - Ẩn nếu là model cũ
        if ![C_LOG, C_LOGPLUS, C_GRA, C_CEN].contains(modelId) {
            list.append(MetricModel(type: .altitude, title: "Altitude Level".localized, value: getAltitudeLevel(), iconName: "altitude"))
        }
        
        // Mode (Tag 3) & Dive Status (Tag 17)
        list.append(MetricModel(type: .mode, title: "Mode".localized, value: self.getMode(), iconName: "mode"))
        list.append(MetricModel(type: .diveStatus, title: "Dive Status".localized, value: self.getDiveStatus(), iconName: "dive_status"))
        
        
        // Surface Interval (Tag 5) & Start Dive (Tag 6)
        list.append(MetricModel(type: .surfaceInterval, title: "Surface Interval".localized, value: getSurfaceInterval(), iconName: "serface_interval"))
        list.append(MetricModel(type: .startDive, title: "Start Dive".localized, value: getFormattedStartDiveTime(), iconName: "start_dive"))
        
        // Dive Time (Tag 7) & Max Depth (Tag 8)
        list.append(MetricModel(type: .diveTime, title: "Dive Time".localized, value: getDiveTime(), iconName: "dive_time"))
        list.append(MetricModel(type: .maxDepth, title: "Max Depth".localized, value: getMaxDepth(), iconName: "max_depth"))
        
        if ![C_LOG, C_LOGPLUS, C_GRA, C_CEN].contains(modelId) {
            list.append(MetricModel(type: .tlbg, title: "Max TLBG".localized, value: getMaxTLBG(), iconName: "tlbg"))
        }
        
        if [C_LOG, C_LOGPLUS, C_GRA].contains(modelId) {
            list.append(MetricModel(type: .maxAscRate, title: "Max Ascent Rate".localized, value: getMaxAscRate(), iconName: "max_accent_rate"))
            list.append(MetricModel(type: .oxtox, title: "Max Descent Rate".localized, value: getMaxDescRate(), iconName: "max_accent_rate"))
        } else {
            if modelId != C_CEN {
                list.append(MetricModel(type: .maxAscRate, title: "Max Ascent Bar".localized, value: getMaxAscBar(), iconName: "max_accent_rate"))
            }
        }
        
        list.append(MetricModel(type: .minTemp, title: "Min Temperature".localized, value: getMinTemp(), iconName: "min_temp"))
        
        // Chỉ add maxTemp nếu KHÔNG PHẢI là C_CEN hoặc C_GRA (vì C_LOG và C_LOGPLUS vẫn có maxTemp)
        if ![C_CEN, C_GRA].contains(modelId) {
            list.append(MetricModel(type: .maxTemp, title: "Max Temperature".localized, value: getMaxTemp(), iconName: "max_temp"))
        }
        
        if ![C_LOG, C_LOGPLUS, C_GRA, C_CEN].contains(modelId) {
            list.append(MetricModel(type: .oxtox, title: "OXTOX end dive".localized, value: getOXTOX(), iconName: "o2"))
        }
        
        if ![C_LOG, C_LOGPLUS, C_GRA, C_CEN].contains(modelId) {
            list.append(MetricModel(type: .maxPo2, title: "Max PPO2".localized, value: getMaxPPO2(), iconName: "max_po2"))
        }
        
        if ![C_LOG, C_LOGPLUS, C_GRA, C_CEN].contains(modelId) {
            list.append(MetricModel(type: .startGas, title: "Start Gas".localized, value: getStartGas(), iconName: "start_gas"))
            list.append(MetricModel(type: .endGas, title: "End Gas".localized, value: getEndGas(), iconName: "end_gas"))
        }
        
        list.append(MetricModel(type: .conservatism, title: "Conservatism".localized, value: getConservatism(), iconName: "conservatism"))
        
        return list
        */
    }
    
    private func getFormattedDate() -> String {
        let diveDateTime = diveLog.stringValue(key: "DiveStartLocalTime")
        
        let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
        
        let datePattern = (dateFormatId == 0) ? "dd.MM.yy" : "MM.dd.yy"
        
        let diveDate = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: datePattern)
        
        return diveDate
    }
    
    private func getFormattedStartDiveTime() -> String {
        let diveDateTime = diveLog.stringValue(key: "DiveStartLocalTime")
        
        let timeFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
        
        let timePattern = (timeFormatId == 0) ? "hh:mm a" : "HH:mm"
        
        let diveTime = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: timePattern)
        
        return diveTime
    }
    
    private func getSurfaceInterval() -> String {
        let surfTime = diveLog.stringValue(key: "SurfTime").toInt()
        if surfTime == 0 {
            return "-:--"
        } else {
            let hours = surfTime / 3600
            let minutes = (surfTime % 3600) / 60
            let seconds = surfTime % 60
            
            // Trả về định dạng Giờ:Phút:Giây (luôn hiển thị 2 chữ số)
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
    
    private func getDiveTime() -> String {
        let totalDiveTime = diveLog.stringValue(key: "TotalDiveTime").toInt()
        
        // Tính toán giờ, phút, giây từ tổng số giây
        let hours = totalDiveTime / 3600
        let minutes = (totalDiveTime % 3600) / 60
        let seconds = totalDiveTime % 60
        
        // Kiểm tra điều kiện thời gian lặn
        /*
        if hours >= 1 {
            // Lớn hơn hoặc bằng 1 giờ -> hiển thị Giờ:Phút:Giây
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            // Nhỏ hơn 1 giờ -> hiển thị Phút:Giây
            return String(format: "%02d:%02d", minutes, seconds)
        }
        */
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func getMaxDepth() -> String {
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let unitString = unitOfDive == M ? "M":"FT"
        
        var mdepth = diveLog.stringValue(key: "MaxDepthFT")
        
        if unitOfDive == M {
            mdepth = formatNumber(converFeet2Meter(mdepth.toDouble()))
        } else {
            mdepth = formatNumber(mdepth.toDouble(), decimalIfNeeded: 0)
        }
        return String(format: "%@ %@", mdepth, unitString)
    }
    
    private func getAvgDepth() -> String {
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let unitString = unitOfDive == M ? "M":"FT"
        
        // Nếu profile trống, trả về giá trị mặc định là 0
        guard !diveProfile.isEmpty else {
            return String(format: "0 %@", unitString)
        }
        
        // 1. Tính tổng tất cả DepthFT từ diveProfile
        let totalDepthFT = diveProfile.reduce(0.0) { sum, row in
            let depthFT = row.stringValue(key: "DepthFT").toDouble() / 10.0
            return sum + depthFT
        }
        
        // 2. Tính độ sâu trung bình bằng Feet (FT)
        let avgDepthFT = totalDepthFT / Double(diveProfile.count)
        
        // 3. Chuyển đổi đơn vị và định dạng hiển thị theo thiết lập Units
        var avgDepthString = ""
        if unitOfDive == FT {
            avgDepthString = formatNumber(convertMeter2Feet(avgDepthFT), decimalIfNeeded: 0)
        } else {
            avgDepthString = formatNumber(avgDepthFT)
        }
        
        return String(format: "%@ %@", avgDepthString, unitString)
    }
    
    private func getMaxTLBG() -> String {
        let isDeco = diveLog.stringValue(key: "IsDecoDive").toInt()
        var limitOfTLBG = 0
        switch modelId {
        case C_WIS5:
            limitOfTLBG = 8
        default:
            limitOfTLBG = 5
        }
        
        var maxTlbg = diveLog.stringValue(key: "MaxTLBG").toInt()
        if maxTlbg == 0 { maxTlbg = 1 }
        var value = String(format: "%d/%d", maxTlbg, limitOfTLBG)
        if isDeco == 1 || maxTlbg > limitOfTLBG {
            maxTlbg = limitOfTLBG
            value = String(format: "%d/%d", maxTlbg, limitOfTLBG)
        }
        
        var mode = diveLog.stringValue(key: "DiveMode").toInt()
        if mode >= 100 { mode = mode % 100 }
        if mode == 3 || hasViolationMode() { // GAUGE
            value = "---"
        }
        
        return value
    }
    
    private func getMaxAscBar() -> String {
        let MaxAscentSpeedLev = diveLog.stringValue(key: "MaxAscentSpeedLev")
        
        var value =  String(format: "%@", MaxAscentSpeedLev.isEmpty ? "---" : MaxAscentSpeedLev)
        if (manualDive) {
            value = String(format: "%@", MaxAscentSpeedLev.isEmpty ? "1" : MaxAscentSpeedLev)
        }
        
        return value
    }
    
    private func getMaxAscRate() -> String {
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let unitString = unitOfDive == M ? "M":"FT"
        
        var ascentSpeedAlarm = diveLog.stringValue(key: "AscentSpeedAlarm")
        if unitOfDive == M {
            ascentSpeedAlarm = formatNumber(converFeet2Meter(ascentSpeedAlarm.toDouble()))
        } else {
            ascentSpeedAlarm = formatNumber(ascentSpeedAlarm.toDouble(), decimalIfNeeded: 0)
        }
        
        return String(format: "%@ %@/MIN", ascentSpeedAlarm, unitString)
    }
    
    private func getMaxDescRate() -> String {
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let unitString = unitOfDive == M ? "M":"FT"
        
        var descentSpeedAlarm = diveLog.stringValue(key: "DescentSpeedAlarm")
        if unitOfDive == M {
            descentSpeedAlarm = formatNumber(converFeet2Meter(descentSpeedAlarm.toDouble()))
        } else {
            descentSpeedAlarm = formatNumber(descentSpeedAlarm.toDouble(), decimalIfNeeded: 0)
        }
        
        return String(format: "%@ %@/MIN", descentSpeedAlarm, unitString)
    }
    
    private func getMinTemp() -> String {
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let tempUnitString = unitOfDive == M ? "°C":"°F"
        
        var minTemp = diveLog.stringValue(key: "MinTemperatureF")
        if unitOfDive == M {
            minTemp = formatNumber(convertF2C(minTemp.toDouble()))
        } else {
            minTemp = formatNumber(minTemp.toDouble(), decimalIfNeeded: 0)
        }
        return String(format: "%@ %@", minTemp, tempUnitString)
    }
    
    private func getMaxTemp() -> String {
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let tempUnitString = unitOfDive == M ? "°C":"°F"
        
        var maxTemp = diveLog.stringValue(key: "MaxTemperatureF")
        if unitOfDive == M {
            maxTemp = formatNumber(convertF2C(maxTemp.toDouble()))
        } else {
            maxTemp = formatNumber(maxTemp.toDouble(), decimalIfNeeded: 0)
        }
        return String(format: "%@ %@", maxTemp, tempUnitString)
    }
    
    private func getOXTOX() -> String {
        return String(format: "%d %%", diveLog.stringValue(key: "EndingOxToxPercent").toInt())
    }
    
    private func getMaxPPO2() -> String {
        return String(format: "%.2f", diveLog.stringValue(key: "MaxPpo2").toDouble())
    }
    
    private func getStartGas() -> String {
        var startingMixIdx = diveLog.stringValue(key: "StartingMixIdx").toInt()
        if startingMixIdx == 0 { startingMixIdx = 1 }
        
        var endingMixIdx = diveLog.stringValue(key: "EndingMixIdx").toInt()
        if endingMixIdx == 0 { endingMixIdx = 1 }
        
        let mix1Fo2Percent = diveLog.stringValue(key: "Mix1Fo2Percent").toInt()
        let mix2Fo2Percent = diveLog.stringValue(key: "Mix2Fo2Percent").toInt()
        let mix3Fo2Percent = diveLog.stringValue(key: "Mix3Fo2Percent").toInt()
        let mix4Fo2Percent = diveLog.stringValue(key: "Mix4Fo2Percent").toInt()
        
        var startingFo2Percent = 0
        if startingMixIdx <= 4 && endingMixIdx <= 4 {
            switch startingMixIdx {
            case 1:
                startingFo2Percent = mix1Fo2Percent
            case 2:
                startingFo2Percent = mix2Fo2Percent
            case 3:
                startingFo2Percent = mix3Fo2Percent
            case 4:
                startingFo2Percent = mix4Fo2Percent
            default:
                break
            }
        }
        
        return "Gas".localized + " \(startingMixIdx) - " + Utilities.fo2GasValue(gasNo: startingMixIdx, fo2: startingFo2Percent)
    }
    
    private func getEndGas() -> String {
        var startingMixIdx = diveLog.stringValue(key: "StartingMixIdx").toInt()
        if startingMixIdx == 0 { startingMixIdx = 1 }
        
        var endingMixIdx = diveLog.stringValue(key: "EndingMixIdx").toInt()
        if endingMixIdx == 0 { endingMixIdx = 1 }
        
        let mix1Fo2Percent = diveLog.stringValue(key: "Mix1Fo2Percent").toInt()
        let mix2Fo2Percent = diveLog.stringValue(key: "Mix2Fo2Percent").toInt()
        let mix3Fo2Percent = diveLog.stringValue(key: "Mix3Fo2Percent").toInt()
        let mix4Fo2Percent = diveLog.stringValue(key: "Mix4Fo2Percent").toInt()
        
        var endingFo2Percent = 0
        if startingMixIdx <= 4 && endingMixIdx <= 4 {
            switch endingMixIdx {
            case 1:
                endingFo2Percent = mix1Fo2Percent
            case 2:
                endingFo2Percent = mix2Fo2Percent
            case 3:
                endingFo2Percent = mix3Fo2Percent
            case 4:
                endingFo2Percent = mix4Fo2Percent
            default:
                break
            }
        }
        
        return "Gas".localized + " \(endingMixIdx) - " + Utilities.fo2GasValue(gasNo: endingMixIdx, fo2: endingFo2Percent)
    }
    
    private func setupFlexibleMetrics() {
        // 1. Reset StackView chính
        mainMetricsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        mainMetricsStackView.axis = .vertical
        mainMetricsStackView.spacing = 0
        
        let metrics = getActiveMetrics()
        
        // 2. Chia cặp dữ liệu
        let chunks = stride(from: 0, to: metrics.count, by: 2).map {
            Array(metrics[$0..<min($0 + 2, metrics.count)])
        }
        
        for (index, pair) in chunks.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fill // Để tự định nghĩa độ rộng line
            rowStack.alignment = .fill
            
            // 3. Đổ màu xen kẽ chuẩn theo ảnh bạn gửi
            // Hàng 0, 2, 4... màu xám nhạt | Hàng 1, 3, 5... màu trắng
            if index % 2 == 0 {
                rowStack.backgroundColor = .G_2
            }
            
            // Cột bên trái
            let leftItem = createMetricView(data: pair[0])
            rowStack.addArrangedSubview(leftItem)
            
            if pair.count > 1 {
                // 4. Tạo đường line giữa 2 column (Siêu mảnh)
                let line = UIView()
                line.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
                line.translatesAutoresizingMaskIntoConstraints = false
                rowStack.addArrangedSubview(line)
                
                // Cột bên phải
                let rightItem = createMetricView(data: pair[1])
                rowStack.addArrangedSubview(rightItem)
                
                // 5. Thiết lập Constraints để line mỏng và 2 cột bằng nhau
                NSLayoutConstraint.activate([
                    line.widthAnchor.constraint(equalToConstant: 1.0), // Độ rộng line là 1px
                    leftItem.widthAnchor.constraint(equalTo: rightItem.widthAnchor) // Chia đôi 50/50
                ])
            } else {
                // Trường hợp hàng cuối chỉ có 1 item
                let spacer = UIView()
                spacer.backgroundColor = .clear
                rowStack.addArrangedSubview(spacer)
                leftItem.widthAnchor.constraint(equalTo: spacer.widthAnchor).isActive = true
            }
            
            // 6. Chiều cao row là 70 theo yêu cầu
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            mainMetricsStackView.addArrangedSubview(rowStack)
            rowStack.heightAnchor.constraint(equalToConstant: 70).isActive = true
        }
    }

    private func createMetricView(data: MetricModel) -> MetricItemView {
        let view = MetricItemView.loadFromNib()
        view.titleLabel.text = data.title
        view.valueLabel.text = data.value
        
        // Sử dụng icon từ Assets hoặc SF Symbols tùy dự án của bạn
        view.iconImageView.image = UIImage(named: data.iconName) ?? UIImage(systemName: data.iconName)
        
        // QUAN TRỌNG: Phải để clear để thấy được màu của hàng (rowStack)
        view.backgroundColor = .clear
        
        view.actionButton.tag = data.type.rawValue
        view.actionButton.addTarget(self, action: #selector(addManualInfoTapped(_:)), for: .touchUpInside)
        
        return view
    }
    
    private func fillDiveData() {
        
        PrintLog(diveLog)
        
        diveOfTheDayLb.text = "#" + diveLog.stringValue(key: "DiveOfTheDay")
        if (diveLog.stringValue(key: "DiveOfTheDay").isEmpty) {
            diveOfTheDayLb.text = ""
        }
        
        spotNameLb.text = diveLog.stringValue(key: "SpotName")
        if diveLog.stringValue(key: "SpotName").isEmpty {
            spotNameLb.text = "---"
        }
        
        if manualDive == false {
            var deviceSerialNo = ""
            switch modelId {
            case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
                deviceSerialNo = diveLog.stringValue(key: "SerialNo")
            default:
                deviceSerialNo = String(format: "%05d", diveLog.stringValue(key: "SerialNo").toInt())
                break
            }
            diveNameLb.text = String(format: "%@, %@: %@", diveLog.stringValue(key: "DeviceName"), "SN".localized, deviceSerialNo)
        } else {
            diveNameLb.text = String(format: "%@", diveLog.stringValue(key: "DeviceName"))
        }
        if (diveLog.stringValue(key: "DeviceName").isEmpty) {
            diveNameLb.text = "Dive Computer Name".localized
        }
        
        // Favorite
        isFavorite = (diveLog.intValue(key: "IsFavorite") != 0)
        favoriteBtn.setImage(UIImage(named: isFavorite ? "favorite" : "un_favorite"), for: .normal)
    }
    
    private func loadDiveProfile(diveId: Int) {
        do {
            diveProfile = try DatabaseManager.shared.fetchData(from: "DiveProfile",
                                                               where: "DiveID=?",
                                                               arguments: [diveId])
            //PrintLog(diveProfile)
        } catch {
            PrintLog("Failed to fetch certificates data: \(error)")
        }
    }
    
    private func loadPhotos() {
        
        do {
            let urls = try DivePhotoManager.shared.loadPhotoPaths(forDiveID: diveLog.intValue(key: "DiveID"),
                                                                  modelID: diveLog.stringValue(key: "ModelID"),
                                                                  serialNo: diveLog.stringValue(key: "SerialNo"))
            photos = urls
        } catch {}
    }
    
    @IBAction func favoriteTapped(_ sender: Any) {
        isFavorite.toggle()
        self.saveDiveData(key: "IsFavorite", value: isFavorite ? 1:0)
        favoriteBtn.setImage(UIImage(named: isFavorite ? "favorite" : "un_favorite"), for: .normal)
    }
    
    @objc func pageControlTapped(_ sender: UIPageControl) {
        let page = sender.currentPage
        let indexPath = IndexPath(item: page, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
    @objc func deviceDidRotate() {
        guard pageControl.currentPage == 0 else {
            return
        }
        
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            showChartInFullScreen()
        default:
            break
        }
    }
    
    func showChartInFullScreen() {
        self.present(fullVC, animated: false);
    }
    
    private func setupCollectionVIew() {
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(UINib(nibName: "LogGraphCell", bundle: nil), forCellWithReuseIdentifier: "LogGraphCell")
        collectionView.register(UINib(nibName: "LogSpotCell", bundle: nil), forCellWithReuseIdentifier: "LogSpotCell")
        collectionView.register(UINib(nibName: "LogGalleryCell", bundle: nil), forCellWithReuseIdentifier: "LogGalleryCell")
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
        }
        
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        
        // PageControl setup
        pageControl.numberOfPages = numberOfPages
        pageControl.currentPage = 0
    }
    
    @IBAction func doAction(_ sender: Any) {
        if let button = sender as? UIButton {
            let buttonTag = button.tag
            switch buttonTag {
            case 0:
                /*
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogGasViewController") as! LogGasViewController
                vc.diveLog = diveLog
                vc.onUpdated = {[weak self] in
                    guard let self = self else { return }
                    do {
                        let rs = try DatabaseManager.shared.fetchDiveLog(where: "DiveID=\(self.diveLog.intValue(key: "DiveID"))")
                        if rs.count > 0 {
                            diveLog = rs[0]
                            self.onUpdated?(true)
                        }
                    } catch {
                        PrintLog("Failed to load divelog data: \(error)")
                    }
                }
                self.navigationController?.pushViewController(vc, animated: true)
                */
                let storyboard = UIStoryboard(name: "GasDetails", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "GasDetailsViewController") as! GasDetailsViewController
                vc.diveLog = diveLog
                self.navigationController?.pushViewController(vc, animated: true)
                
            case 1:
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogSettingsUsedViewController") as! LogSettingsUsedViewController
                vc.diveLog = diveLog
                self.navigationController?.pushViewController(vc, animated: true)
            case 2:
                let storyboard = UIStoryboard(name: "DiveSpots", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "DiveSpotsViewController") as! DiveSpotsViewController
                vc.diveLog = diveLog
                vc.selectMode = true
                vc.onUpdated = {[weak self] in
                    PrintLog("ON UPDATED")
                    guard let self = self else { return }
                    do {
                        let rs = try DatabaseManager.shared.fetchDiveLog(where: "DiveID=\(self.diveLog.intValue(key: "DiveID"))")
                        if rs.count > 0 {
                            diveLog = rs[0]
                            
                            // Reload
                            fillDiveData()
                            
                            // Reload Spot Map.
                            if manualDive {
                                collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
                            } else {
                                collectionView.reloadItems(at: [IndexPath(item: 1, section: 0)])
                            }
                            self.onUpdated?(true)
                        }
                    } catch {
                        PrintLog("Failed to load divelog data: \(error)")
                    }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            case 3:
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
                vc.diveLog = diveLog
                vc.onUpdated = {[weak self] in
                    guard let self = self else { return }
                    // Reload
                    self.loadPhotos()
                    
                    // Reload Spot Map.
                    self.collectionView.reloadItems(at: [IndexPath(item: 2, section: 0)])
                }
                self.navigationController?.pushViewController(vc, animated: true)
            case 4:
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "MemoViewController") as! MemoViewController
                vc.diveLog = diveLog
                vc.onUpdated = {[weak self] in
                    guard let self = self else { return }
                    do {
                        let rs = try DatabaseManager.shared.fetchDiveLog(where: "DiveID=\(self.diveLog.intValue(key: "DiveID"))")
                        if rs.count > 0 {
                            diveLog = rs[0]
                            self.onUpdated?(true)
                        }
                    } catch {
                        PrintLog("Failed to load divelog data: \(error)")
                    }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            default:
                break
            }
        }
    }
    
    @IBAction func shareTapped(_ sender: Any) {
        /*
        // Lấy tất cả ảnh được chọn
        guard let image = scrollView.captureFullContent() else {
            return
        }
        
        // Gọi tiện ích share có sẵn
        Utilities.share(items: [image], from: self, sourceView: sender as! UIButton)
        */
        
        shareThisDive()
        
        
    }
    
    private func shareThisDive() {
        Task {
            do {
                ProgressHUD.animate()
                
                let jsonBody: [String: Any] = DatabaseManager.shared.exportDiveDataDictionary(diveID: self.diveLog.intValue(key: "DiveID")) ?? [:]
                
                // 2️⃣ Convert sang JSON string
                //jsonBody.removeAll() -> for test only
                let data = try await APIManager.shared.sendRawRequest(
                    APIRequest(path: "/get_share_link.php",
                               method: .POST,
                               parameters: jsonBody,
                               isFormEncoded: true       // 👈 để sendRawRequest tự gói “data={jsonString}”
                              )
                )
                
                ProgressHUD.dismiss()
                
                // In ra JSON string để xem nội dung
                do {
                    
                    if let rawString = String(data: data, encoding: .utf8) {
                        print("📦 Raw response:")
                        print(rawString)
                    } else {
                        print("❌ Không convert được data sang UTF-8 String")
                    }
                    
                    let obj = try JSONSerialization.jsonObject(with: data)
                    
                    guard let json = obj as? [String: Any] else {
                        print("⚠️ JSON không phải dạng dictionary")
                        return
                    }

                    let status = json["status"] as? String ?? ""

                    if status == "success" {
                        let message = json["message"] as? String ?? ""
                        let diveID = json["DiveID"] as? Int
                        let shareLink = json["share_link"] as? String

                        print("✅ Thành công:", message)
                        print("DiveID:", diveID ?? 0)
                        print("Share link:", shareLink ?? "")

                        if let shareLink = shareLink, !shareLink.isEmpty {
                            Utilities.share(items: [shareLink], from: self)
                        }
                    } else {
                        let message = json["message"] as? String ?? "Unknown error"
                        showAlert(on: self, message: message)
                    }

                } catch {
                    print("❌ JSON parse error:", error.localizedDescription)
                    showAlert(on: self, message: "Dữ liệu trả về không hợp lệ")
                }

            } catch {
                ProgressHUD.dismiss()
                print("API Error:", error.localizedDescription)
            }
        }
    }
}

// MARK: - MANUAL ENTRY
extension LogViewController {
    
    @IBAction func addManualInfoTapped(_ sender: Any) {
        
        if manualDive == false { return }
        
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let currentDiveDate = getFormattedDate() // Hàm bạn dùng trong getActiveMetrics
        let currentStartDiveTime = getFormattedStartDiveTime()
        
        if let button = sender as? UIButton {
            let buttonTag = button.tag
            if buttonTag == 0 {
                var currentValue = diveNameLb.text ?? ""
                if (currentValue == "Dive Computer Name".localized) {
                    currentValue = ""
                }
                InputAlert.show(title: "Dive Computer Name".localized, currentValue: currentValue) { action in
                    switch action {
                    case .save(let value):
                        self.diveNameLb.text = value
                        self.saveDiveData(key: "DeviceName", value: self.diveNameLb.text ?? "")
                    default:
                        break
                    }
                }
            } else {
                let type = MetricType(rawValue: button.tag);
                PrintLog("type: \(String(describing: type))")
                
                switch type {
                case .diveDate:
                    let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
                    let currentInputFormat = (dateFormatId == 0) ? "dd.MM.yy" : "MM.dd.yy"
                    
                    EditProfilePopupManager.showBirthDatePicker(
                        in: self,
                        title: "Dive Date".localized,
                        currentValue: currentDiveDate,
                        inputFormat: currentInputFormat,
                        onSave: { [weak self] newDateString in
                            guard let self = self else { return }
                            self.saveDiveDateTime(diveDate: newDateString, diveTime: currentStartDiveTime)
                        }
                    )
                    
                case .altitude:
                    let altOpts = ["SEA", "LEV1", "LEV2", "LEV3", "LEV4"]
                    ItemSelectionAlert.showMessage(
                        message: "Altitude Level".localized,
                        options: altOpts,
                        selectedValue: getAltitudeLevel()
                    ) { [weak self] action, value, index in
                        if action == .allow {
                            self?.saveDiveData(key: "AltitudeLevel", value: index ?? 0)
                        }
                    }
                    
                case .mode:
                    let opts = ["Computer".localized.uppercased(), "Gauge".localized.uppercased()]
                    ItemSelectionAlert.showMessage(
                        message: "Mode".localized,
                        options: opts,
                        selectedValue: self.getMode()
                    ) { [weak self] action, value, index in
                        if action == .allow {
                            // Nếu chọn Gauge (index 1) thì lưu 103, ngược lại lưu 100
                            let saveValue = (index == 1) ? 103 : 100
                            self?.saveDiveData(key: "DiveMode", value: saveValue)
                        }
                    }
                    
                case .diveStatus:
                    let opts = ["NO DECO".localized, "DECO".localized, "VIOLATION".localized]
                    ItemSelectionAlert.showMessage(
                        message: "Dive Status".localized,
                        options: opts,
                        selectedValue: getDiveStatus()
                    ) { [weak self] action, value, index in
                        if action == .allow {
                            var isDeco: Int = index ?? 0
                            var isViolation = 0
                            if index == 2 { // Violation
                                isViolation = 192
                                isDeco = 0
                            }
                            self?.saveDiveData(key: "IsDecoDive", value: isDeco)
                            self?.saveDiveData(key: "Errors", value: isViolation)
                        }
                    }
                    
                case .conservatism:
                    let consOpts = ["C0", "C1", "C2"]
                    ItemSelectionAlert.showMessage(
                        message: "Conservatism".localized,
                        options: consOpts,
                        selectedValue: getConservatism(),
                        notesValue: "GF"
                    ) { [weak self] action, value, index in
                        if action == .allow {
                            var gfHigh = 90, gfLow = 90
                            if index == 1 { gfHigh = 85; gfLow = 35 }
                            else if index == 2 { gfHigh = 70; gfLow = 35 }
                            self?.saveDiveData(key: "GfHighPercent", value: gfHigh)
                            self?.saveDiveData(key: "GfLowPercent", value: gfLow)
                        }
                    }
                    
                case .surfaceInterval:
                    let siValue = getSurfaceInterval()
                    let siTime = siValue.components(separatedBy: ":")
                    if siTime.count == 2 {
                        let leftOpts = (0...23).map { String(format: "%02d", $0) }
                        let rightOpts = (0...59).map { String(format: "%02d", $0) }
                        Set2ValueSettingAlert.showMessage(
                            message: "Surface Interval".localized,
                            leftValue: siTime[0],
                            rightValue: siTime[1],
                            leftOptions: leftOpts,
                            rightOptions: rightOpts
                        ) { [weak self] action, selectedValue in
                            if let selectedValue = selectedValue, action == .allow {
                                let parts = selectedValue.components(separatedBy: " - ")
                                if parts.count == 2 {
                                    let totalSeconds = (parts[0].toInt() * 3600) + (parts[1].toInt() * 60)
                                    self?.saveDiveData(key: "SurfTime", value: totalSeconds)
                                }
                            }
                        }
                    }
                    
                case .startDive:
                    let timeFormatId = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
                    let outputFormat = (timeFormatId == 0) ? "hh:mm a" : "HH:mm"
                    presentTimePicker(from: self, selectedTime: currentStartDiveTime, outputFormat: outputFormat) { [weak self] value in
                        self?.saveDiveDateTime(diveDate: currentDiveDate, diveTime: value)
                    }
                    
                case .diveTime:
                    let dtValue = getDiveTime().components(separatedBy: ":")
                    if dtValue.count == 2 {
                        let leftOpts = (0...999).map { String(format: "%02d", $0) }
                        let rightOpts = (0...59).map { String(format: "%02d", $0) }
                        Set2ValueSettingAlert.showMessage(
                            leftValue: dtValue[0],
                            rightValue: dtValue[1],
                            leftOptions: leftOpts,
                            rightOptions: rightOpts
                        ) { [weak self] action, selectedValue in
                            if let selectedValue = selectedValue, action == .allow {
                                let parts = selectedValue.components(separatedBy: " - ")
                                if parts.count == 2 {
                                    let totalSeconds = (parts[0].toInt() * 60) + parts[1].toInt()
                                    self?.saveDiveData(key: "TotalDiveTime", value: totalSeconds)
                                }
                            }
                        }
                    }
                    
                case .maxDepth:
                    let currentMdepth = getMaxDepth().components(separatedBy: " ").first ?? ""
                    let unitStr = unitOfDive == M ? "M" : "FT"
                    let notes = unitOfDive == M ? "* From 0 m to 999.9 m" : "* From 0 ft to 3300 ft"
                    MDepthInputAlert.showMessage(selectedValue: currentMdepth, notesValue: notes, unitValue: unitStr) { [weak self] action, value in
                        if action == .allow {
                            var valueDouble = value.toDouble()
                            if unitOfDive == M {
                                valueDouble = convertMeter2Feet(valueDouble)
                            }
                            self?.saveDiveData(key: "MaxDepthFT", value: valueDouble)
                        }
                    }
                    
                case .tlbg:
                    let currentTlbg = getMaxTLBG().components(separatedBy: "/").first ?? "1"
                    let opts = (1...5).map { "\($0)" }
                    ItemSelectionAlert.showMessage(message: "TLBG Bar".localized, options: opts, selectedValue: currentTlbg) { [weak self] action, value, index in
                        if action == .allow {
                            self?.saveDiveData(key: "MaxTLBG", value: (index ?? 0) + 1)
                        }
                    }
                    
                case .maxAscRate:
                    if modelId == C_WIS5 || manualDive {
                        let currentBar = getMaxAscBar()
                        let opts = (1...5).map { "\($0)" }
                        ItemSelectionAlert.showMessage(message: "Max Ascent Bar".localized, options: opts, selectedValue: currentBar) { [weak self] action, value, index in
                            if action == .allow {
                                self?.saveDiveData(key: "MaxAscentSpeedLev", value: (index ?? 0) + 1)
                            }
                        }
                    } else {
                        let currentRate = getMaxAscRate().components(separatedBy: " ").first ?? ""
                        let unitStr = unitOfDive == M ? "M/MIN" : "FT/MIN"
                        MDepthInputAlert.showMessage(message: "Max Ascent Rate".localized, selectedValue: currentRate, unitValue: unitStr) { [weak self] action, value in
                            if action == .allow {
                                var valueDouble = value.toDouble()
                                if unitOfDive == M {
                                    valueDouble = convertMeter2Feet(valueDouble )
                                }
                                self?.saveDiveData(key: "AscentSpeedAlarm", value: valueDouble)
                            }
                        }
                    }
                    
                case .minTemp, .maxTemp:
                    let isMin = (type == .minTemp)
                    let title = isMin ? "Min Temperature".localized : "Max Temperature".localized
                    let currentVal = isMin ? getMinTemp() : getMaxTemp()
                    let key = isMin ? "MinTemperatureF" : "MaxTemperatureF"
                    
                    var opts = (0...99).map { "\($0) °C" }
                    if unitOfDive == FT { opts = (32...210).map { "\($0) °F" } }
                    
                    ItemSelectionAlert.showMessage(message: title, options: opts, selectedValue: currentVal) { [weak self] action, value, index in
                        if let value = value, action == .allow {
                            var saveValue = (value.components(separatedBy: " ").first ?? "").toDouble()
                            if unitOfDive == M {
                                saveValue = convertC2F(saveValue)
                            }
                            self?.saveDiveData(key: key, value: saveValue)
                        }
                    }
                    
                case .oxtox:
                    let opts = (0...200).map { "\($0) %" }
                    ItemSelectionAlert.showMessage(message: "OXTOX".localized, options: opts, selectedValue: getOXTOX()) { [weak self] action, value, index in
                        if let value = value, action == .allow {
                            let saveValue = value.components(separatedBy: " ").first ?? "0"
                            self?.saveDiveData(key: "EndingOxToxPercent", value: saveValue)
                        }
                    }
                    
                case .maxPo2:
                    let opts = stride(from: 0.21, through: 2.0, by: 0.01).map { String(format: "%.2f", $0) }
                    ItemSelectionAlert.showMessage(message: "Max PPO2".localized, options: opts, selectedValue: getMaxPPO2()) { [weak self] action, value, index in
                        if action == .allow {
                            self?.saveDiveData(key: "MaxPpo2", value: value ?? "0.21")
                        }
                    }
                    
                default:
                    break
                }
            }
        }
        
    }
    
    private func saveDiveDateTime(diveDate: String, diveTime: String) {
        // 1. Lấy định dạng hiện tại người dùng đang dùng ở giao diện
        let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
        let timeFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
        
        let datePattern = (dateFormatId == 0) ? "dd.MM.yy" : "MM.dd.yy"
        let timePattern = (timeFormatId == 0) ? "hh:mm a" : "HH:mm"

        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.dateFormat = "\(datePattern) \(timePattern)" // Định dạng này khớp với cái UI đang hiển thị
        
        // 2. Gộp chuỗi từ giao diện
        let combinedString = "\(diveDate) \(diveTime)"
        
        // 3. Chuyển từ chuỗi UI -> đối tượng Date
        if let date = inputFormatter.date(from: combinedString) {
            // 4. Chuyển từ đối tượng Date -> Chuỗi chuẩn Database
            let dbFormatter = DateFormatter()
            dbFormatter.dateFormat = "dd/MM/yyyy HH:mm:ss" // LUÔN lưu định dạng này
            
            let finalStringForDB = dbFormatter.string(from: date)
            
            // 5. Lưu vào DB
            self.saveDiveData(key: "DiveStartLocalTime", value: finalStringForDB)
        } else {
            print("❌ Lỗi: Không thể parse ngày tháng với format: \(datePattern) \(timePattern)")
        }
    }
    
    private func saveDiveData(key: String, value: Any) {
        let diveID = self.diveLog.intValue(key: "DiveID")
        
        // 1. Update vào DB
        DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                           params: [key: value],
                                           conditions: "where DiveID=\(diveID)")
        
        // 2. Lấy lại dữ liệu MỚI NHẤT từ DB gán ngược vào diveLog
        // Bạn nên dùng hàm fetchRow hoặc fetchData để lấy lại record vừa update
        let results = try? DatabaseManager.shared.fetchData(from: "DiveLog",
                                                            where: "DiveID=?",
                                                            arguments: [diveID])
        if let updatedRow = results?.first {
            self.diveLog = updatedRow // Cập nhật biến local
        }
        
        // 3. Báo cho màn hình danh sách biết để load lại (nếu người dùng back ra)
        self.onUpdated?(true)
        
        // 4. Vẽ lại giao diện với dữ liệu đã cập nhật trong self.diveLog
        self.setupFlexibleMetrics()
    }
    
}

extension LogViewController {
    func enlargePageControlDots(_ pageControl: UIPageControl, scale: CGFloat = 1.5) {
        for (_, dotView) in pageControl.subviews.enumerated() {
            dotView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}

extension LogViewController: UIScrollViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.size.width
        let currentPage = Int((scrollView.contentOffset.x + pageWidth / 2) / pageWidth)
        pageControl.currentPage = currentPage
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfPages
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if numberOfPages == 3 {
            switch indexPath.row {
            case 0:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LogGraphCell", for: indexPath) as! LogGraphCell
                cell.diveLog = diveLog
                cell.diveProfile = diveProfile
                cell.didSelectedChartEntryPoint = { row in
                    print(row)
                }
                
                return cell
            case 1:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LogSpotCell", for: indexPath) as! LogSpotCell
                cell.diveLog = diveLog
                return cell
            case 2:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LogGalleryCell", for: indexPath) as! LogGalleryCell
                cell.configure(with: photos)
                return cell
            default:
                break
            }
        } else if numberOfPages == 2 {
            switch indexPath.row {
            case 0:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LogSpotCell", for: indexPath) as! LogSpotCell
                cell.diveLog = diveLog
                return cell
            case 1:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LogGalleryCell", for: indexPath) as! LogGalleryCell
                cell.configure(with: photos)
                return cell
            default:
                break
            }
        }
        
        return UICollectionViewCell()
    }
    
    // Size cho từng cell để nó full width của collection view
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}


extension LogViewController {
    private func getAltitudeLevel() -> String {
        switch modelId {
        case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
            return "SEA".localized
        default:
            let level = diveLog.stringValue(key: "AltitudeLevel").toInt()
            if level == 0 {
                return "SEA".localized
            } else {
                return String(format: "LEV%d", level)
            }
        }
    }
    
    private func getMode() -> String {
        var mode = diveLog.stringValue(key: "DiveMode").toInt()
        if mode >= 100 { mode = mode % 100 }
        
        let defaultMode = "Gauge".localized.uppercased()
        
        switch modelId {
        case C_LOG, C_LOGPLUS:
            let modeOptions: [String] = ["Scuba", "Nitrox", "Gauge", "Free", "Tec"]
            guard mode >= 0 && mode < modeOptions.count else { return defaultMode }
            return modeOptions[mode].localized.uppercased()
        case C_GRA, C_CEN:
            let modeOptions: [String] = ["Scuba", "Gauge", "Free", "Tec"]
            guard mode >= 0 && mode < modeOptions.count else { return defaultMode }
            return modeOptions[mode].localized.uppercased()
        default:
            switch mode {
            case 0:
                return "Computer".localized.uppercased()
            default:
                return defaultMode
            }
        }
    }
    
    private func getDiveStatus() -> String {
        if hasViolationMode() {
            return "VIOLATION".localized
        } else {
            let isDeco = diveLog.stringValue(key: "IsDecoDive").toInt()
            switch isDeco {
            case 0:
                return "NO DECO".localized
            default:
                return "DECO".localized
            }
        }
    }
    
    private func hasViolationMode() -> Bool {
        let errors = diveLog.stringValue(key: "Errors").toInt()
        return (errors & ((1 << 6) | (1 << 7))) != 0
    }
    
    private func getConservatism() -> String {
        let gfHigh = diveLog.stringValue(key: "GfHighPercent").toInt()
        let gfLow = diveLog.stringValue(key: "GfLowPercent").toInt()
        
        switch modelId {
        case C_GRA, C_LOG, C_LOGPLUS, C_CEN:
            if gfHigh >= 95 && gfLow >= 45 {
                return "CF3" // Aggressive
            } else if gfHigh <= 75 && gfLow <= 35 {
                return "CF1" // Conserve
            } else {
                return "CF2" // Normal
            }
        default:
            if gfHigh >= 90 && gfLow >= 90 {
                return "C0"
            } else if gfHigh <= 70 && gfLow <= 35 {
                return "C2"
            } else {
                return "C1"
            }
        }
    }
}
