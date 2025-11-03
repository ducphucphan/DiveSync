//
//  BluetoothScanViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 2/20/25.
//

import UIKit
import RxSwift
import RxCocoa
import RxBluetoothKit
import ProgressHUD
import CoreBluetooth

protocol BluetoothScanDelegate: AnyObject {
    func didConnectToDevice(withError error: String?)
}

class BluetoothScanViewController: BaseViewController, BluetoothDeviceCoordinatorDelegate {
    
    @IBOutlet weak var resultTableView: UITableView!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var lookingLb: UILabel!
    @IBOutlet weak var tryagainImv: UIImageView!
    @IBOutlet weak var tryagainLb: UILabel!
    @IBOutlet weak var tryagainBtn: UIButton!
    @IBOutlet weak var headerView: UIStackView!
    
    // 1) make disposeBag mutable
    private var disposeBag = DisposeBag()
    private var peripherals = BehaviorRelay<[ScannedPeripheral]>(value: [])
    
    // BluetoothManager
    private let bluetoothCoordinator = BluetoothDeviceCoordinator.shared
    
    var selectedDevice: Devices!
    
    deinit {
        PrintLog("🧹 ScanViewController deinit")
        bluetoothCoordinator.delegate = nil
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PrintLog("👋 ScanViewController viewWillDisappear, isMovingFromParent=\(isMovingFromParent)")
        if isMovingFromParent {
            // cancel all subscriptions created by this VC
            disposeBag = DisposeBag()
            peripherals.accept([])
            // clear table view delegates to be safe
            resultTableView.dataSource = nil
            resultTableView.delegate = nil
            bluetoothCoordinator.delegate = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Scan Devices",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        lookingLb.text = "No Device Found.\nEnsure your device is ON and Bluetooth is set to ON."
        
        setupTableView()
        
        bluetoothCoordinator.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableTryAgain(tryagain: false)
        startScanning()
    }
    
    private func startScanning() {
        var foundAny = false
        
        headerView.isHidden = false
        indicatorView.startAnimating()
        resultTableView.reloadData()
        
        // Bind danh sách về UI
        //let knownDevicesSerials: Set<String> = Set(DatabaseManager.shared.fetchDevices()?.compactMap { $0.SerialNo } ?? [])
        let knownDevicesIdentities: Set<String> = Set(DatabaseManager.shared.fetchDevices()?.compactMap { $0.Identity } ?? [])
        
        // Bind danh sách về UI
        BluetoothDeviceCoordinator.shared.scannedDevices
            .map { scannedList -> [ScannedPeripheral] in
                // Filter chỉ những device chưa có trong app
                scannedList.filter { sp in
                    //guard let (_, serial) = sp.peripheral.peripheral.splitDeviceName() else { return true }
                    //return !knownDevicesSerials.contains(serial)
                    guard let IdentityName = sp.peripheral.peripheral.name else { return true } // IdentityName [DAVxxxxx, SKIxxxxx, SPIxxxxx]
                    return !knownDevicesIdentities.contains(IdentityName)
                }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] peripherals in
                guard let self = self else { return }
                
                PrintLog("unknown devices: \(peripherals.map { $0.advertisementData.localName ?? $0.peripheral.name ?? "Unknown" })")
                
                if !peripherals.isEmpty {
                    foundAny = true
                    self.resultTableView.isHidden = false
                    self.peripherals.accept(peripherals)
                }
            }, onError: { error in
                PrintLog("Scan failed with error: \(error)")
            }, onCompleted: {
                self.indicatorView.stopAnimating()
                if foundAny == false {
                    self.enableTryAgain(tryagain: true)
                }
            })
            .disposed(by: disposeBag)
        
        // Tạm dừng indicator sau timeout
        Observable<Int>.timer(.seconds(30), scheduler: MainScheduler.instance)
            .take(1)
            .subscribe(onNext: { [weak self] _ in
                self?.indicatorView.stopAnimating()
                self?.enableTryAgain(tryagain: true)
            })
            .disposed(by: disposeBag)
    }
    
    private func enableTryAgain(tryagain: Bool) {
        if tryagain {
            tryagainImv.alpha = 1.0
            tryagainLb.alpha = 1.0
            tryagainBtn.isEnabled = true
            lookingLb.text = "No Device Found.\nEnsure your device is ON and Bluetooth is set to ON."
        } else {
            tryagainImv.alpha = 0.5
            tryagainLb.alpha = 0.5
            tryagainBtn.isEnabled = false
            lookingLb.text = "Looking for devices..."
        }
    }
    
    private func setupTableView() {
        resultTableView.isHidden = true
        
        peripherals
            .bind(to: resultTableView.rx.items(cellIdentifier: "DeviceViewCell", cellType: DeviceViewCell.self)) { _, device, cell in
                cell.fillData(mDevice: device)
            }
            .disposed(by: disposeBag)
        
        resultTableView.rx.modelSelected(ScannedPeripheral.self)
            .subscribe(onNext: { [weak self] device in
                self?.indicatorView.stopAnimating()
                self?.headerView.isHidden = true
                self?.connectToDevice(device)
            })
            .disposed(by: disposeBag)
        
    }
    
    private func connectToDevice(_ scanned: ScannedPeripheral) {
        BluetoothDeviceCoordinator.shared
            .connect(to: scanned.peripheral, discover: true) // ← discover ngay
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { manager in
                // Set ModelID nếu cần
                if let (bleName, _) = scanned.peripheral.peripheral.splitDeviceName(),
                   let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                    manager.ModelID = dcInfo[2].toInt()
                }
                
                // Kết nối xong thì đọc settings luôn
                manager.readAllSettings()
            }, onError: { error in
                ProgressHUD.dismiss()
                PrintLog("❌ Error: \(error.localizedDescription)")
                BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }
    
    @IBAction func tryAgainTapped(_ sender: Any) {
        self.enableTryAgain(tryagain: false)
        //self.startScanning()
    }
    
    func didConnectToDevice(message: String?) {
        if let msg = message {
            showAlert(on: self, message: msg, okHandler: {
                self.navigationController?.popViewController(animated: true)
            })
        } else {
            print("✅ Device connected and settings downloaded")
        }
    }
    
}
