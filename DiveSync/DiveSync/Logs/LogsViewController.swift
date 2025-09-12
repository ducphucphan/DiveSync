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

class LogsViewController: BaseViewController, BluetoothDeviceCoordinatorDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var downloadView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var cancelView: UIView!
    @IBOutlet weak var sortView: UIView!
    @IBOutlet weak var searchView: UIView!
    
    @IBOutlet weak var deleteLb: UILabel!
    
    @IBOutlet weak var noDivesLb: UILabel!
    
    var diveList:[Row] = []
    
    var selectMode = false
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    
    private var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        loadData(sort: SortPreferences.load())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if selectMode == false {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            tableView.addGestureRecognizer(longPressGesture)
        }
        
    }
    
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else { return }
        
        let point = gestureRecognizer.location(in: tableView)
        
        if let indexPath = tableView.indexPathForRow(at: point) {
            if !isDeleteMode {
                // Bắt đầu chế độ xóa khi long tap
                isDeleteMode = true
                selectedIndexes.removeAll()
                updateUIForDeleteMode()
            } else {
                // Nếu đang ở chế độ xóa, toggle chọn
                if selectedIndexes.contains(indexPath.row) {
                    selectedIndexes.remove(indexPath.row)
                } else {
                    selectedIndexes.insert(indexPath.row)
                }
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    @IBAction func downloadAction(_ sender: Any) {
        searchType = .kAddDive
        syncType = .kDownloadDiveData
        
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let bluetoothScanVC = storyboard.instantiateViewController(withIdentifier: "BluetoothScanViewController") as! BluetoothScanViewController
        self.navigationController?.pushViewController(bluetoothScanVC, animated: true)
        
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
                message: "Are you sure you want to delete selected dives?",
                allowTitle: "DELETE",
                denyTitle: "CANCEL"
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
        
        updateUIForDeleteMode()
    }
    
    @IBAction func sortAction(_ sender: Any) {
        let current = SortPreferences.load()
        SortAlert.showMessage(message: "Sort your logs", currentOptions: current) { options in
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
    
    private func loadData(sort: SortOptions? = nil) {
        do {
            let diveLog = try DatabaseManager.shared.fetchDiveLog(sort: sort)
            diveList = diveLog
        } catch {
            PrintLog("Failed to load divelog data: \(error)")
        }
        
        updateUIForDeleteMode()
    }
    
    func updateUIForDeleteMode(indexPaths:[IndexPath]? = nil) {
        if diveList.count == 0 {
            tableView.isHidden = true
            noDivesLb.isHidden = false
            isDeleteMode = false
        } else {
            tableView.isHidden = false
            noDivesLb.isHidden = true
        }
        
        if isDeleteMode {
            addView.isHidden = true
            downloadView.isHidden = true
            sortView.isHidden = true
            searchView.isHidden = true
            deleteView.isHidden = false
            cancelView.isHidden = false
            
            if selectedIndexes.count > 0 {
                deleteLb.text = "Delete Selected"
            } else {
                deleteLb.text = "Delete"
            }
        } else {
            addView.isHidden = false
            downloadView.isHidden = true
            sortView.isHidden = false
            searchView.isHidden = true
            deleteView.isHidden = true
            cancelView.isHidden = true
        }
        
        if let reloadedIndexPaths = indexPaths, reloadedIndexPaths.count > 0 {
            tableView.reloadRows(at: reloadedIndexPaths,  with: .fade)
        } else {
            tableView.reloadData()
        }
    }
    
    func deleteSelectedItems() {
        let sortedIndexes = selectedIndexes.sorted(by: >)
        for index in sortedIndexes {
            let diveID = diveList[index].intValue(key: "DiveID")
            DatabaseManager.shared.deleteRows(from: "DiveLog", where: "DiveID=?", arguments: [diveID])
            DatabaseManager.shared.deleteRows(from: "DiveProfile", where: "DiveID=?", arguments: [diveID])
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return diveList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath) as! LogCell
        
        // Hiện checkbox nếu đang ở chế độ xóa
        cell.checkbox.isHidden = !isDeleteMode
        cell.checkbox.isSelected = selectedIndexes.contains(indexPath.row)
        
        cell.bindData(row: diveList[indexPath.row])
        
        cell.onFavoriteTapped = {[weak self] isFavorite in
            guard let self = self else { return }
            
            DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                               params: ["IsFavorite": isFavorite ? 1:0],
                                               conditions: "where DiveID=\(self.diveList[indexPath.row].intValue(key: "DiveID"))")
            
            self.loadData(sort: SortPreferences.load())
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isDeleteMode {
            if selectedIndexes.contains(indexPath.row) {
                selectedIndexes.remove(indexPath.row)
            } else {
                selectedIndexes.insert(indexPath.row)
            }
            
            updateUIForDeleteMode(indexPaths: [indexPath])
        } else {
            if selectMode == false {
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogViewController") as! LogViewController
                vc.diveLog = diveList[indexPath.row]
                vc.onUpdated = {[weak self] updated in
                    guard let self = self else { return }
                    if updated {
                        self.loadData(sort: SortPreferences.load())
                    }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                if selectedIndexes.contains(indexPath.row) {
                    selectedIndexes.remove(indexPath.row)
                } else {
                    selectedIndexes.removeAll()
                    selectedIndexes.insert(indexPath.row)
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
            let alert = UIAlertController(title: "Add Manual Dive Entry",
                                          message: "Please select the unit for this dive log",
                                          preferredStyle: .alert)
            
            // Tạo content VC để chứa segmented control
            let contentVC = UIViewController()
            contentVC.preferredContentSize = CGSize(width: 260, height: 50)
            
            let segmented = UISegmentedControl(items: ["Meters", "Feet"])
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
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let ok = UIAlertAction(title: "OK", style: .default) { _ in
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
                if deviceConnected.peripheral.name == device.Identity {
                    // Đúng device đang kết nối → đọc luôn
                    deviceConnected.readAllSettings2()
                    return
                } else {
                    // Khác device → ngắt kết nối cũ trước khi connect mới
                    BluetoothDeviceCoordinator.shared.disconnect()
                }
            }
            
            // Thực hiện kết nối mới
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.peripheral.name == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                showAlert(on: self, message: "Device not found!")
                return
            }
            
            BluetoothDeviceCoordinator.shared
                .connect(to: matchedDevice.peripheral, discover: true)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] manager in
                    guard let self = self else { return }
                    
                    if let (bleName, _) = matchedDevice.peripheral.peripheral.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    
                    manager.readAllSettings2()
                    
                }, onError: { error in
                    ProgressHUD.dismiss()
                    PrintLog("❌ Connect error: \(error.localizedDescription)")
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
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
