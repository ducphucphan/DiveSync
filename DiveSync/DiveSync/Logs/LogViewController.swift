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
    @IBOutlet weak var deleteLb: UILabel!
    
    //
    
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
        deleteLb.text = "Delete".localized
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
            case C_LOG, C_LOGPLUS, C_GRA:
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
        
        let diveDateTime = diveLog.stringValue(key: "DiveStartLocalTime")
        
        let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
        let timeFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
        
        let datePattern = (dateFormatId == 0) ? "dd.MM.yy" : "MM.dd.yy"
        let timePattern = (timeFormatId == 0) ? "hh:mm a" : "HH:mm"
        
        let diveDate = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: datePattern)
        let diveTime = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: timePattern)
        
        diveDateLb.text = diveDate
        sdvaLueLb.text = diveTime
        altLevelLb.text = getAltitudeLevel()
        
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
        ltbgValueLb.text = String(format: "%d/%d", maxTlbg, limitOfTLBG)
        if isDeco == 1 || maxTlbg > limitOfTLBG {
            maxTlbg = limitOfTLBG
            ltbgValueLb.text = String(format: "%d/%d", maxTlbg, limitOfTLBG)
        }
        
        var mode = diveLog.stringValue(key: "DiveMode").toInt()
        if mode >= 100 { mode = mode % 100 }
        if mode == 3 || hasViolationMode() { // GAUGE
            ltbgValueLb.text = "---"
        }
        
        modeLb.text = getMode()
        diveStatusLb.text = getDiveStatus()
        consValueLb.text = getConservatism()
        
        let totalDiveTime = diveLog.stringValue(key: "TotalDiveTime").toInt()
        dtValueLb.text = String(format: "%02d:%02d", totalDiveTime/3600, (totalDiveTime % 3600) / 60)
        
        let surfTime = diveLog.stringValue(key: "SurfTime").toInt()
        if surfTime == 0 {
            siValueLb.text = "-:--"
        } else {
            siValueLb.text = String(format: "%02d:%02d", surfTime/3600, (surfTime % 3600) / 60)
        }
        
        let unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        let unitString = unitOfDive == M ? "M":"FT"
        let tempUnitString = unitOfDive == M ? "°C":"°F"
        
        var mdepth = diveLog.stringValue(key: "MaxDepthFT")
        var maxTemp = diveLog.stringValue(key: "MaxTemperatureF")
        var minTemp = diveLog.stringValue(key: "MinTemperatureF")
        var ascentSpeedAlarm = diveLog.stringValue(key: "AscentSpeedAlarm")
        let MaxAscentSpeedLev = diveLog.stringValue(key: "MaxAscentSpeedLev")
        if unitOfDive == M {
            mdepth = formatNumber(converFeet2Meter(mdepth.toDouble()))
            maxTemp = formatNumber(convertF2C(maxTemp.toDouble()))
            minTemp = formatNumber(convertF2C(minTemp.toDouble()))
            ascentSpeedAlarm = formatNumber(converFeet2Meter(ascentSpeedAlarm.toDouble()))
        } else {
            mdepth = formatNumber(mdepth.toDouble(), decimalIfNeeded: 0)
            maxTemp = formatNumber(maxTemp.toDouble(), decimalIfNeeded: 0)
            minTemp = formatNumber(minTemp.toDouble(), decimalIfNeeded: 0)
            ascentSpeedAlarm = formatNumber(ascentSpeedAlarm.toDouble(), decimalIfNeeded: 0)
        }
        mdepthValueLb.text = String(format: "%@ %@", mdepth, unitString)
        maxTempValueLb.text = String(format: "%@ %@", maxTemp, tempUnitString)
        minTempValueLb.text = String(format: "%@ %@", minTemp, tempUnitString)
        
        oxtoxValueLb.text = String(format: "%d %%", diveLog.stringValue(key: "EndingOxToxPercent").toInt())
        
        switch modelId {
        case C_CEN, C_GRA, C_LOG, C_LOGPLUS:
            ascValueLb.text = String(format: "%@ %@/MIN", ascentSpeedAlarm, unitString)
        default:
            ascValueLb.text = String(format: "%@", MaxAscentSpeedLev.isEmpty ? "---" : MaxAscentSpeedLev)
            if (manualDive) {
                ascValueLb.text = String(format: "%@", MaxAscentSpeedLev.isEmpty ? "1" : MaxAscentSpeedLev)
            }
        }
        
        maxPo2ValueLb.text = String(format: "%.2f", diveLog.stringValue(key: "MaxPpo2").toDouble())
        
        var startingMixIdx = diveLog.stringValue(key: "StartingMixIdx").toInt()
        if startingMixIdx == 0 { startingMixIdx = 1 }
        
        var endingMixIdx = diveLog.stringValue(key: "EndingMixIdx").toInt()
        if endingMixIdx == 0 { endingMixIdx = 1 }
        
        let mix1Fo2Percent = diveLog.stringValue(key: "Mix1Fo2Percent").toInt()
        let mix2Fo2Percent = diveLog.stringValue(key: "Mix2Fo2Percent").toInt()
        let mix3Fo2Percent = diveLog.stringValue(key: "Mix3Fo2Percent").toInt()
        let mix4Fo2Percent = diveLog.stringValue(key: "Mix4Fo2Percent").toInt()
        
        var startingFo2Percent = 0
        var endingFo2Percent = 0
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
        
        startGasValueLb.text = "Gas".localized + " \(startingMixIdx) - " + Utilities.fo2GasValue(gasNo: startingMixIdx, fo2: startingFo2Percent)
        endGasValueLb.text = "Gas".localized + " \(endingMixIdx) - " + Utilities.fo2GasValue(gasNo: endingMixIdx, fo2: endingFo2Percent)
        
        // Favorite
        isFavorite = (diveLog.intValue(key: "IsFavorite") != 0)
        favoriteBtn.setImage(UIImage(named: isFavorite ? "favorite" : "un_favorite"), for: .normal)
        
        switch modelId {
        case C_CEN, C_GRA, C_LOG, C_LOGPLUS:
            ltbgValueLb.text = "---"
            oxtoxValueLb.text = "---"
        default:
            break
        }
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
        
        let diveDate = diveDateLb.text ?? ""
        let diveTime = sdvaLueLb.text ?? ""
        
        if let button = sender as? UIButton {
            let buttonTag = button.tag
            
            PrintLog("TAG: \(buttonTag)")
            switch buttonTag {
            case 0: // Device Name
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
            case 1: // Dive Date
                let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
                let currentInputFormat = (dateFormatId == 0) ? "dd.MM.yy" : "MM.dd.yy"
                
                EditProfilePopupManager.showBirthDatePicker(
                    in: self,
                    title: "Dive Date".localized,
                    currentValue: diveDate,
                    inputFormat: currentInputFormat,
                    onSave: { [weak self] newDateString in
                        guard let self = self else { return }
                        self.diveDateLb.text = newDateString
                        self.saveDiveDateTime(diveDate: newDateString, diveTime: diveTime)
                    }
                )
            case 2: // Alt Level
                let altOpts = ["SEA", "LEV1", "LEV2", "LEV3", "LEV4"]
                ItemSelectionAlert.showMessage(
                    message: "Altitude Level".localized,
                    options: altOpts,
                    selectedValue: altLevelLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.altLevelLb.text = value
                    self.saveDiveData(key: "AltitudeLevel", value: index ?? 0)
                }
            case 3: // Mode
                let opts = ["Computer".localized.uppercased(), "Gauge".localized.uppercased()]
                ItemSelectionAlert.showMessage(
                    message: "Mode".localized,
                    options: opts,
                    selectedValue: modeLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.modeLb.text = value
                    
                    var saveValue = 100
                    if index != 1 {
                        saveValue = saveValue + (index ?? 0)
                    }
                    self.saveDiveData(key: "DiveMode", value: saveValue)
                }
            case 17: // Dive Status
                let opts = ["NO DECO".localized, "DECO".localized, "VIOLATION".localized]
                ItemSelectionAlert.showMessage(
                    message: "Dive Status".localized,
                    options: opts,
                    selectedValue: diveStatusLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.diveStatusLb.text = value
                    
                    var isDeco: Int = index ?? 0
                    var isViolation = 0
                    if index == 2 { // Violation
                        isViolation = 192 // Cả bit 6 và bit 7 của Errors điều bật.
                        isDeco = 0
                    }
                    
                    self.saveDiveData(key: "IsDecoDive", value: isDeco)
                    self.saveDiveData(key: "Errors", value: isViolation)
                }
            case 4:
                let altOpts = ["C0", "C1", "C2"]
                ItemSelectionAlert.showMessage(
                    message: "Conservatism".localized,
                    options: altOpts,
                    selectedValue: consValueLb.text,
                    notesValue: "GF"
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.consValueLb.text = value
                    
                    var gfHigh = 90
                    var gfLow = 90
                    if index == 1 {
                        gfHigh = 85
                        gfLow = 35
                    } else if index == 2 {
                        gfHigh = 70
                        gfLow = 35
                    }
                    
                    self.saveDiveData(key: "GfHighPercent", value: gfHigh)
                    self.saveDiveData(key: "GfLowPercent", value: gfLow)
                }
            case 5:
                
                if let siTime = siValueLb.text?.components(separatedBy: ":"), siTime.count == 2 {
                    let leftOpts: [String] = (0...23).map { String(format: "%02d", $0) }
                    let rightOpts: [String] = (0...59).map { String(format: "%02d", $0) }
                    Set2ValueSettingAlert.showMessage(message: siTitleLb.text ?? "",
                                                      leftValue: siTime[0],
                                                      rightValue: siTime[1],
                                                      leftOptions: leftOpts,
                                                      rightOptions: rightOpts) { [weak self] action, selectedValue in
                        guard let self = self else { return }
                        if let selectedValue = selectedValue, action == .allow {
                            self.siValueLb.text = selectedValue.replacingOccurrences(of: " - ", with: ":")
                            
                            let siTimeSelected = selectedValue.components(separatedBy: " - ")
                            if siTimeSelected.count == 2 {
                                self.saveDiveData(key: "SurfTime", value: siTimeSelected[0].toInt()*3600 + siTimeSelected[1].toInt()*60)
                            }
                        }
                    }
                }
                
            case 6: // Dive Time
                // 1. Lấy định dạng thời gian từ Settings
                let timeFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
                
                // 2. Xác định định dạng trả về cho Picker (0: 12h, 1: 24h)
                let currentOutputFormat = (timeFormatId == 0) ? "hh:mm a" : "HH:mm"
                
                // 3. Truyền format động vào presentTimePicker
                presentTimePicker(from: self, selectedTime: diveTime, outputFormat: currentOutputFormat) { value in
                    self.sdvaLueLb.text = value
                    // Hàm này sẽ tự xử lý để lưu chuẩn dd/MM/yyyy HH:mm:ss vào DB như đã nói ở trên
                    self.saveDiveDateTime(diveDate: diveDate, diveTime: value)
                }
            case 7:
                if let dt = dtValueLb.text?.components(separatedBy: ":"), dt.count == 2 {
                    let leftOpts: [String] = (0...99).map { String(format: "%02d", $0) }
                    let rightOpts: [String] = (0...59).map { String(format: "%02d", $0) }
                    Set2ValueSettingAlert.showMessage(leftValue: dt[0],
                                                      rightValue: dt[1],
                                                      leftOptions: leftOpts,
                                                      rightOptions: rightOpts) { [weak self] action, selectedValue in
                        guard let self = self else { return }
                        if let selectedValue = selectedValue, action == .allow {
                            self.dtValueLb.text = selectedValue.replacingOccurrences(of: " - ", with: ":")
                            
                            let dtSelected = selectedValue.components(separatedBy: " - ")
                            if dtSelected.count == 2 {
                                self.saveDiveData(key: "TotalDiveTime", value: dtSelected[0].toInt()*3600 + dtSelected[1].toInt()*60)
                            }
                        }
                    }
                }
            case 8: // Max Depth
                var currentMdepth = mdepthValueLb.text ?? ""
                currentMdepth = currentMdepth.components(separatedBy: " ").first ?? ""
                let unitStr = unitOfDive == M ? "M":"FT"
                let notes = unitOfDive == M ? "* From 0 m to 999.9 m":"* From 0 ft to 3300 ft"
                MDepthInputAlert.showMessage(selectedValue: currentMdepth, notesValue: notes, unitValue:unitStr) { action, value in
                    self.mdepthValueLb.text = value + " " + unitStr
                    
                    var valueDouble = value.toDouble() * 10 // Dive Depth in meters x 10
                    if unitOfDive == FT {
                        valueDouble = converFeet2Meter(valueDouble)
                    }
                    self.saveDiveData(key: "MaxDepthFT", value: valueDouble )
                }
                
                break
            case 9: // TLBG BAR
                let text = ltbgValueLb.text ?? ""
                let firstNumber = text.components(separatedBy: "/").first ?? ""
                let opts:[String] = (1...5).map { String(format: "%d", $0) }
                ItemSelectionAlert.showMessage(
                    message: "TLBG Bar".localized,
                    options: opts,
                    selectedValue: firstNumber
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.ltbgValueLb.text = String(format: "%@/5", value ?? "1")
                    self.saveDiveData(key: "MaxTLBG", value: (index ?? 0) + 1)
                }
            case 10: // Max Asc Rate
                var currentAscValue = ascValueLb.text ?? ""
                
                switch modelId {
                case C_CEN, C_GRA, C_LOG, C_LOGPLUS:
                    currentAscValue = currentAscValue.components(separatedBy: " ").first ?? ""
                    let unitStr = unitOfDive == M ? "M/MIN":"FT/MIN"
                    MDepthInputAlert.showMessage(message: "Max Ascent Rate".localized, selectedValue: currentAscValue, unitValue:unitStr) { action, value in
                        self.ascValueLb.text = value + " " + unitStr
                        
                        var valueDouble = value.toDouble()
                        if unitOfDive == M {
                            valueDouble = convertMeter2Feet(valueDouble )
                        }
                        self.saveDiveData(key: "AscentSpeedAlarm", value: valueDouble )
                    }
                default:
                    let currentAscValue = ascValueLb.text ?? ""
                    let opts:[String] = (1...5).map { String(format: "%d", $0) }
                    ItemSelectionAlert.showMessage(
                        message: "Max Ascent Bar".localized,
                        options: opts,
                        selectedValue: currentAscValue
                    ) { [weak self] action, value, index in
                        guard let self = self else { return }
                        self.ascValueLb.text = value
                        self.saveDiveData(key: "MaxAscentSpeedLev", value: (index ?? 0) + 1)
                    }
                }
                
                break
            case 11: // Min Temp
                var opts: [String] = (0...99).map { String(format: "%d °C", $0) }
                if unitOfDive == FT {
                    opts = (32...210).map { String(format: "%d °F", $0) }
                }
                ItemSelectionAlert.showMessage(
                    message: "Min Temp".localized,
                    options: opts,
                    selectedValue: minTempValueLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.minTempValueLb.text = value
                    
                    if let value = value {
                        // Temperature in Celcisuis x 10
                        var saveValue = (value.components(separatedBy: " ").first ?? "").toDouble() * 10
                        if unitOfDive == FT {
                            saveValue = convertF2C(saveValue)
                        }
                        self.saveDiveData(key: "MinTemperatureF", value: saveValue)
                    }
                }
                break
            case 12: // Max Temp
                var opts: [String] = (0...99).map { String(format: "%d °C", $0) }
                if unitOfDive == FT {
                    opts = (32...210).map { String(format: "%d °F", $0) }
                }
                ItemSelectionAlert.showMessage(
                    message: "Max Temp".localized,
                    options: opts,
                    selectedValue: maxTempValueLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.maxTempValueLb.text = value
                    
                    if var value = value {
                        // Temperature in Celcisuis x 10
                        var saveValue = (value.components(separatedBy: " ").first ?? "").toDouble() * 10
                        if unitOfDive == FT {
                            saveValue = convertF2C(saveValue)
                        }
                        self.saveDiveData(key: "MaxTemperatureF", value: saveValue)
                    }
                }
                break
            case 13: // OXTOX
                let opts: [String] = (0...200).map { String(format: "%d %%", $0) }
                ItemSelectionAlert.showMessage(
                    message: "OXTOX".localized,
                    options: opts,
                    selectedValue: oxtoxValueLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.oxtoxValueLb.text = value
                    
                    let saveValue = value?.components(separatedBy: " ").first ?? "0"
                    self.saveDiveData(key: "EndingOxToxPercent", value: saveValue)
                }
                break
            case 14: // Max PPO2
                let opts: [String] = stride(from: 0.21, through: 2.0, by: 0.01)
                    .map { String(format: "%.2f", $0) }
                ItemSelectionAlert.showMessage(
                    message: "Max PPO2".localized,
                    options: opts,
                    selectedValue: maxPo2ValueLb.text
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    self.maxPo2ValueLb.text = value
                    self.saveDiveData(key: "MaxPpo2", value: value ?? 0.21)
                }
                break
            case 15: // Start GAS
                break
            case 16: // End GAS
                break
            default:
                break
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
        DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                           params: [key: value],
                                           conditions: "where DiveID=\(self.diveLog.intValue(key: "DiveID"))")
        self.onUpdated?(true)
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
            return "---"
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
        case C_GRA, C_LOG, C_LOGPLUS:
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
