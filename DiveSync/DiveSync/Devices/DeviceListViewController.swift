//
//  DeviceListViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/26/25.
//

import UIKit

class DeviceListViewController: BaseViewController {
    @IBOutlet weak var tableview: UITableView!
    
    var deviceCount = 0
    var deviceList: [Devices]?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        tableview.backgroundColor = .clear
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadDevices()
    }
    
    private func loadDevices() {
        deviceList = DatabaseManager.shared.fetchDevices()
        deviceCount = deviceList?.count ?? 0
        tableview.reloadData()
    }

    @IBAction func addTapped(_ sender: Any) {
        searchType = .kAddDevice
        syncType = .kDownloadSetting
        
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let bluetoothScanVC = storyboard.instantiateViewController(withIdentifier: "BluetoothScanViewController") as! BluetoothScanViewController
        self.navigationController?.pushViewController(bluetoothScanVC, animated: true)
    }
    
}

extension DeviceListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return deviceCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceCell
        cell.fillData(mDevice: deviceList![indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DeviceViewController") as! DeviceViewController
        vc.device = deviceList![indexPath.row]
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension DeviceListViewController: BluetoothScanDelegate {
    func didConnectToDevice(withError error: String?) {
        if let error = error, error.isEmpty == false {
            PrintLog("ERROR: \(String(describing: error))")
            return
        } else {
            self.loadDevices()
        }
    }
}
