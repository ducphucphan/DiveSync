//
//  LogsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/5/25.
//

import UIKit
import GRDB
import RxSwift
import ProgressHUD
import RxBluetoothKit

struct GroupedDiveLogs {
    let monthYearString: String
    let dives: [Row]
}

class LogsViewController: BaseViewController, BluetoothDeviceCoordinatorDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerTableView: UIView!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var recycleView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var cancelView: UIView!
    @IBOutlet weak var sortView: UIView!
    @IBOutlet weak var searchView: UIView!
    
    @IBOutlet weak var deleteLb: UILabel!
    
    @IBOutlet weak var noDivesLb: UILabel!
    @IBOutlet weak var addLb: UILabel!
    @IBOutlet weak var recycleLb: UILabel!
    @IBOutlet weak var cancelLb: UILabel!
    @IBOutlet weak var sortLb: UILabel!
    @IBOutlet weak var searchLb: UILabel!
    
    @IBOutlet weak var selectAllBtn: UIButton!
    @IBOutlet weak var selectAllImv: UIImageView!
    @IBOutlet weak var selectAllLb: UILabel!
    @IBOutlet weak var longPressLb: UILabel!
    
    var diveList:[Row] = []
    
    var displayMode: ListDisplayMode {
        get {
            guard isNewLook else { return .normal }
            return AppSettings.shared.logsDisplayMode
        }
        set {
            if isNewLook {
                AppSettings.shared.logsDisplayMode = newValue
            }
        }
    }
    var groupedDiveList: [GroupedDiveLogs] = []
    
    var selectMode = false
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    
    private var disposeBag = DisposeBag()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        noDivesLb.text = "No Logs".localized
        addLb.text = "Add".localized
        recycleLb.text = "Recently deleted".localized
        cancelLb.text = "Cancel".localized
        sortLb.text = "Sort".localized
        searchLb.text = "Search".localized
        selectAllLb.text = "Select All".localized
        longPressLb.text = "Long press an item to select or deselect it".localized
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDiveImport),
                name: .didImportDiveLog,
                object: nil
            )
        
        updateRightBarButton()
        
        loadData(sort: SortPreferences.load())
    }
    
    private func updateRightBarButton() {
        guard isNewLook else {
            self.navigationItem.rightBarButtonItem = nil
            return
        }
        
        let iconName = (displayMode == .normal) ? "list.bullet" : "square.grid.2x2"
        if let systemImage = UIImage(systemName: iconName)?.withRenderingMode(.alwaysOriginal).withTintColor(.white) {
            let switchButton = UIBarButtonItem(
                image: systemImage,
                style: .plain,
                target: self,
                action: #selector(toggleDisplayMode)
            )
            
            // Bạn cũng có thể gán trực tiếp tintColor riêng cho chính UIBarButtonItem này để đảm bảo an toàn
            switchButton.tintColor = .white
            
            self.navigationItem.rightBarButtonItem = switchButton
        }
    }
    
    @objc private func toggleDisplayMode() {
        displayMode = (displayMode == .normal) ? .group : .normal
        updateRightBarButton()
        tableView.reloadData()
    }
    
    @objc private func handleDiveImport() {
        print("🔄 Received import event — reload logs")
        if self.isViewLoaded && self.view.window != nil {
            loadData(sort: SortPreferences.load())
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if selectMode == false {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            tableView.addGestureRecognizer(longPressGesture)
        }
        
    }
    
    private func updateSelectAllButton() {
        let imageName = isAllSelected
            ? "checked"
            : "uncheck1"
        
        selectAllImv.image = UIImage(named: imageName)
    }
    
    private var isAllSelected: Bool {
        return !diveList.isEmpty && selectedIndexes.count == diveList.count
    }
    
    @IBAction func selectAllAction(_ sender: Any) {

        // 1. Nếu chưa vào delete mode → bật delete mode
        if !isDeleteMode {
            isDeleteMode = true
            selectedIndexes.removeAll()
        }

        // 2. Toggle select all / deselect all
        if selectedIndexes.count == diveList.count {
            // Deselect all
            selectedIndexes.removeAll()
        } else {
            // Select all
            selectedIndexes = Set(0..<diveList.count)
        }

        // 3. Update UI
        updateUIForDeleteMode()
    }
    
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }

        let point = gestureRecognizer.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }

        // --- THÊM DÒNG NÀY ĐỂ LẤY INDEX PHẲNG CHÍNH XÁC ---
        let flatIndex = getFlatIndex(from: indexPath)
        
        if !isDeleteMode {
            // 1️⃣ Bật delete mode
            isDeleteMode = true

            // 2️⃣ Clear toàn bộ selection → tất cả unchecked
            selectedIndexes.removeAll()

            // 3️⃣ Reload table để hiện checkbox (unchecked)
            tableView.reloadData()

            // 4️⃣ Chỉ check row đang long-press
            selectedIndexes.insert(flatIndex)

            // 5️⃣ Reload riêng row đó
            tableView.reloadRows(at: [indexPath], with: .fade)

            // 6️⃣ Update header / select all
            updateSelectAllButton()
        } else {
            // Đã ở delete mode → toggle bình thường
            if selectedIndexes.contains(flatIndex) {
                selectedIndexes.remove(flatIndex)
            } else {
                selectedIndexes.insert(flatIndex)
            }

            tableView.reloadRows(at: [indexPath], with: .fade)
            updateSelectAllButton()
        }
        
        updateUIForDeleteMode()
    }
    
    @IBAction func recycleAction(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Logs", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "RecycleViewController") as! RecycleViewController
        vc.onUpdated = { [weak self] updated in
            guard let self = self else { return }
            if updated {
                self.loadData(sort: SortPreferences.load())
            }
        }
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func addButtonTapped(_ sender: UIButton) {
        let sb = UIStoryboard(name: "AddDivesPopup", bundle: nil)
        guard let popup = sb.instantiateViewController(withIdentifier: "AddDivesPopupViewController") as? AddDivesPopupViewController else { return }
        popup.delegate = self
        
        if let sheet = popup.sheetPresentationController {
            if #available(iOS 16.0, *) {
                // custom detent khoảng ~60% hoặc tối đa 520
                let customDetent = UISheetPresentationController.Detent.custom(identifier: .init("half")) { context in
                    return min(520, context.maximumDetentValue * 0.65)
                }
                sheet.detents = [customDetent, .large()]
            } else if #available(iOS 15.0, *) {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        
        present(popup, animated: true)
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        // Đang ở chế độ chọn: thực hiện xóa
        if selectedIndexes.count > 0 {
            PrivacyAlert.showMessage(
                message: "Are you sure you want to delete selected dives?".localized,
                allowTitle: "Delete".localized.uppercased(),
                denyTitle: "Cancel".localized.uppercased()
            ) { action in
                switch action {
                case .allow:
                    self.deleteSelectedItems()
                    self.selectedIndexes.removeAll()
                    self.updateUIForDeleteMode()
                case .deny:
                    break
                }
            }
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        isDeleteMode = false
        selectMode = false
        
        selectedIndexes.removeAll()
        
        updateUIForDeleteMode()
    }
    
    @IBAction func sortAction(_ sender: Any) {
        let current = SortPreferences.load()
        SortAlert.showMessage(message: "Sort your logs".localized, currentOptions: current) { options in
            guard let selected = options else { return }
            
            self.loadData(sort: selected)
        }
    }
    
    @IBAction func searchAction(_ sender: Any) {
        SearchLogAlert.showMessage(message: "") { action in
            
        }
    }
    
    private func addManualEntry(unit: Int) {
        // Tạo dữ liệu mặc định cho DiveLog
        let diveData: [String: Any] = [
            "DiveNo": Int(Date().timeIntervalSince1970), // hoặc random số duy nhất
            "ModelID": 0,
            "SerialNo": 0,
            "Units": unit,
            "DiveStartLocalTime": Utilities.getDateTime(Date(), "dd/MM/yyyy HH:mm:ss"),
            "DiveEndLocalTime": Utilities.getDateTime(Date(), "dd/MM/yyyy HH:mm:ss"),
            "MaxDepthFT": 0,
            "TotalDiveTime": 0,
            "DiveMode": 100, // 100: MANUAL-COMPUTER, 103: MANUAL-GAUGE
            "EnabledMixes": 2 // [false, true, false, false, false, false, false, false] - Gas 1 always ON
        ]
        
        let result = DatabaseManager.shared.saveDiveData(diveData: diveData)
        
        guard let diveID = result.diveID else {
            PrintLog("❌ Không thể thêm dive mới.")
            return
        }
        
        // Lấy lại Row vừa thêm vào
        do {
            let results = try DatabaseManager.shared.fetchData(from: "DiveLog",
                                                               where: "DiveID=?",
                                                               arguments: [diveID])
            guard let row = results.first else { return }
            
            let storyboard = UIStoryboard(name: "Logs", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "LogViewController") as! LogViewController
            vc.diveLog = row
            vc.onUpdated = { [weak self] updated in
                guard let self = self else { return }
                if updated {
                    self.loadData(sort: SortPreferences.load())
                }
            }
            vc.onUpdated?(true)
            self.navigationController?.pushViewController(vc, animated: true)
        } catch {
            PrintLog("❌ Lỗi lấy Row DiveLog vừa tạo: \(error)")
        }
    }
    
    // --- THÊM HÀM NHÓM DỮ LIỆU THEO THÁNG NĂM ---
    private func groupDives(_ list: [Row]) -> [GroupedDiveLogs] {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yyyy"
        
        let currentLangCode = LocalizationManager.shared.currentLanguage
        displayFormatter.locale = Locale(identifier: currentLangCode)
        
        var dictGroups: [String: [Row]] = [:]
        var orderedMonths: [String] = []
        
        for row in list {
            let dateStr = row.stringValue(key: "DiveStartLocalTime")
            let monthStr: String
            
            if let date = formatter.date(from: dateStr) {
                monthStr = displayFormatter.string(from: date)
            } else {
                monthStr = "Unknown"
            }
            
            if dictGroups[monthStr] == nil {
                dictGroups[monthStr] = []
                orderedMonths.append(monthStr)
            }
            dictGroups[monthStr]?.append(row)
        }
        
        return orderedMonths.map { GroupedDiveLogs(monthYearString: $0, dives: dictGroups[$0] ?? []) }
    }
    
    // --- THÊM HÀM CHUYỂN ĐỔI INDEX PHỤC VỤ LOGIC CHỌN XÓA ---
    private func getFlatIndex(from indexPath: IndexPath) -> Int {
        if displayMode == .normal {
            return indexPath.row
        }
        var flatIndex = 0
        for i in 0..<indexPath.section {
            flatIndex += groupedDiveList[i].dives.count
        }
        flatIndex += indexPath.row
        return flatIndex
    }
    
    private func loadData(sort: SortOptions? = nil) {
        do {
            let diveLog = try DatabaseManager.shared.fetchDiveLog(where: "Deleted=0", sort: sort)
            diveList = diveLog
            
            // --- THÊM DÒNG NÀY ĐỂ CẬP NHẬT MẢNG GROUP ---
            if isNewLook {
                groupedDiveList = groupDives(diveLog)
            } else {
                groupedDiveList = []
            }
        } catch {
            PrintLog("Failed to load divelog data: \(error)")
        }
        
        updateUIForDeleteMode()
    }
    
    func updateUIForDeleteMode(indexPaths:[IndexPath]? = nil) {
        if diveList.count == 0 {
            tableView.isHidden = true
            headerTableView.isHidden = true
            noDivesLb.isHidden = false
            isDeleteMode = false
        } else {
            tableView.isHidden = false
            headerTableView.isHidden = false
            noDivesLb.isHidden = true
        }
        
        if isDeleteMode {
            addView.isHidden = true
            recycleView.isHidden = true
            sortView.isHidden = true
            searchView.isHidden = true
            deleteView.isHidden = false
            cancelView.isHidden = false
            
            if selectedIndexes.count > 0 {
                deleteLb.text = "Delete Selected".localized
            } else {
                deleteLb.text = "Delete".localized
            }
        } else {
            addView.isHidden = false
            sortView.isHidden = false
            searchView.isHidden = true
            deleteView.isHidden = true
            cancelView.isHidden = true
            
            let showRecycle = DatabaseManager.shared.hasDeletedDiveLogs()
            recycleView.isHidden = !showRecycle
            
        }
        
        if let reloadedIndexPaths = indexPaths, reloadedIndexPaths.count > 0 {
            tableView.reloadRows(at: reloadedIndexPaths,  with: .fade)
        } else {
            tableView.reloadData()
        }
        
        updateSelectAllButton()
    }
    
    func deleteSelectedItems() {
        let sortedIndexes = selectedIndexes.sorted(by: >)
        for index in sortedIndexes {
            let diveID = diveList[index].intValue(key: "DiveID")
            /*
            DatabaseManager.shared.deleteRows(from: "DiveLog", where: "DiveID=?", arguments: [diveID])
            DatabaseManager.shared.deleteRows(from: "DiveProfile", where: "DiveID=?", arguments: [diveID])
            */
            
            DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                               params: ["Deleted": 1],
                                               conditions: "where DiveID=\(diveID)")
            
            
            diveList.remove(at: index)
        }
        selectedIndexes.removeAll()
        tableView.reloadData()
    }
}

extension LogsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return displayMode == .normal ? nil : groupedDiveList[section].monthYearString
    }
    
    // --- THÊM HÀM NÀY ĐỂ TRIỆT TIÊU KHOẢNG TRỐNG FOOTER CỦA HỆ THỐNG ---
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.001
        // Trong iOS, trả về 0.001 thay vì 0 hẳn để hệ thống hiểu và xóa bỏ hoàn toàn vùng đệm Footer
    }
    
    // --- THÊM HÀM NÀY ĐỂ ĐẢM BẢO KHÔNG CÓ VIEW FOOTER NÀO XUẤT HIỆN ---
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.contentView.backgroundColor = UIColor.B_2
            
            if let textLabel = header.textLabel {
                textLabel.textColor = .white
                textLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // --- THAY ĐỔI TẠI ĐÂY: Tăng chiều cao của header (cũ là 40.0) ---
        if isNewLook && displayMode == .group {
            return 45.0
        }
        return 0.0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isNewLook && displayMode == .group {
            return groupedDiveList.count
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if displayMode == .normal {
            return diveList.count
        } else {
            return groupedDiveList[section].dives.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath) as! LogCell
        
        // Lấy index và row dữ liệu tương ứng dựa theo mode đang bật
        let flatIndex = getFlatIndex(from: indexPath)
        let currentDive = displayMode == .normal ? diveList[indexPath.row] : groupedDiveList[indexPath.section].dives[indexPath.row]
        
        // Hiện checkbox nếu đang ở chế độ xóa
        cell.checkboxImv.isHidden = !isDeleteMode
        
        cell.bindData(row: currentDive)
        cell.updateCheckbox(
            isVisible: isDeleteMode,
            isChecked: selectedIndexes.contains(flatIndex)
        )
        
        cell.onFavoriteTapped = {[weak self] isFavorite in
            guard let self = self else { return }
            
            DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                               params: ["IsFavorite": isFavorite ? 1:0],
                                               conditions: "where DiveID=\(currentDive.intValue(key: "DiveID"))")
            
            self.loadData(sort: SortPreferences.load())
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let flatIndex = getFlatIndex(from: indexPath)
        let currentDive = displayMode == .normal ? diveList[indexPath.row] : groupedDiveList[indexPath.section].dives[indexPath.row]
        
        if isDeleteMode {
            if selectedIndexes.contains(flatIndex) {
                selectedIndexes.remove(flatIndex)
            } else {
                selectedIndexes.insert(flatIndex)
            }
            
            updateUIForDeleteMode(indexPaths: [indexPath])
        } else {
            if selectMode == false {
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogViewController") as! LogViewController
                vc.diveLog = currentDive
                vc.onUpdated = {[weak self] updated in
                    guard let self = self else { return }
                    if updated {
                        self.loadData(sort: SortPreferences.load())
                    }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                if selectedIndexes.contains(flatIndex) {
                    selectedIndexes.remove(flatIndex)
                } else {
                    selectedIndexes.removeAll()
                    selectedIndexes.insert(flatIndex)
                }
                updateUIForDeleteMode()
            }
        }
    }
    
    func didConnectToDevice(message: String?) {
        if let msg = message {
            showAlert(on: self, message: msg)
        }
        
        loadData(sort: SortPreferences.load())
    }
}

extension LogsViewController: BluetoothScanDelegate {
    func didConnectToDevice(withError error: String?) {
        if let error = error, error.isEmpty == false {
            PrintLog("ERROR: \(String(describing: error))")
            return
        } else {
            PrintLog("POPPED.............")
            loadData(sort: SortPreferences.load())
        }
    }
}

extension LogsViewController: AddLogsPopupDelegate {
    func popupDidTapAddManualLog(_ vc: AddDivesPopupViewController) {
        vc.dismiss(animated: true) {
            let alert = UIAlertController(title: "Add Manual Dive Entry".localized,
                                          message: "Please select the unit for this dive log".localized,
                                          preferredStyle: .alert)
            
            // Tạo content VC để chứa segmented control
            let contentVC = UIViewController()
            contentVC.preferredContentSize = CGSize(width: 260, height: 50)
            
            let segmented = UISegmentedControl(items: ["Meters".localized, "Feet".localized])
            segmented.selectedSegmentIndex = 0
            segmented.translatesAutoresizingMaskIntoConstraints = false
            segmented.backgroundColor = .B_3 // màu giống top bar
            segmented.selectedSegmentTintColor = .B_2 // màu nền khi chọn
            
            // Màu chữ khi chưa chọn
            segmented.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
            // Màu chữ khi chọn
            segmented.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            segmented.layer.cornerRadius = 8
            segmented.layer.masksToBounds = true
            
            contentVC.view.addSubview(segmented)
            NSLayoutConstraint.activate([
                segmented.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor, constant: 8),
                segmented.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor, constant: -8),
                segmented.centerYAnchor.constraint(equalTo: contentVC.view.centerYAnchor)
            ])
            
            // Gán contentVC vào alert (thông dụng, được dùng rộng rãi)
            alert.setValue(contentVC, forKey: "contentViewController")
            
            // Actions
            let cancel = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
            let ok = UIAlertAction(title: "OK".localized, style: .default) { _ in
                let unit = segmented.selectedSegmentIndex
                self.addManualEntry(unit: unit)
            }
            
            alert.addAction(cancel)
            alert.addAction(ok)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func popup(_ vc: AddDivesPopupViewController, didSelect device: Devices) {
        vc.dismiss(animated: true) {
            searchType = .kAddDive
            syncType = .kDownloadDiveData
            
            BluetoothDeviceCoordinator.shared.delegate = self
            
            if let deviceConnected = BluetoothDeviceCoordinator.shared.activeDataManager {
                // Kiểm tra SerialNo hoặc Identity có match không
                if deviceConnected.scannedPeripheral.advertisementData.localName == device.Identity {
                    // Đúng device đang kết nối → đọc luôn
                    deviceConnected.readAllSettings()
                    return
                } else {
                    // Khác device → ngắt kết nối cũ trước khi connect mới
                    BluetoothDeviceCoordinator.shared.disconnect()
                }
            }
            
            // Thực hiện kết nối mới
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.advertisementData.localName == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                showAlert(on: self, title: "Device not found!".localized, message: "Ensure that your Device is ON and Bluetooth is opened.".localized)
                return
            }
            
            BluetoothDeviceCoordinator.shared
                .connect(to: matchedDevice, discover: true)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] session in
                    guard self != nil else { return }
                    
                    let manager: BluetoothManagerProtocol
                    switch session {
                    case .normalSession(let m): manager = m
                    case .crSession(let m): manager = m
                    case .cr4Session(let m): manager = m
                    case .cr5Session(let m): manager = m
                    }
                    
                    if let (bleName, _) = matchedDevice.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    manager.readAllSettings(completion: nil)
                    
                }, onError: { error in
                    ProgressHUD.dismiss()
                    if case BluetoothError.peripheralDisconnected = error, BluetoothDeviceCoordinator.shared.isExpectedDisconnect {
                        PrintLog("ℹ️ Peripheral disconnected (expected)")
                        BluetoothDeviceCoordinator.shared.isExpectedDisconnect = false
                    } else {
                        PrintLog("❌ Connect error: \(error.localizedDescription)")
                        BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                    }
                }).disposed(by: self.disposeBag)
        }
    }
    
    func popupDidTapAddNewDevice(_ vc: AddDivesPopupViewController) {
        vc.dismiss(animated: true) {
            searchType = .kAddDevice
            syncType = .kDownloadSetting
            
            let storyboard = UIStoryboard(name: "Device", bundle: nil)
            let bluetoothScanVC = storyboard.instantiateViewController(withIdentifier: "BluetoothScanViewController") as! BluetoothScanViewController
            self.navigationController?.pushViewController(bluetoothScanVC, animated: true)
        }
    }
}
