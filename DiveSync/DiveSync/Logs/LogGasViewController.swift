//
//  LogGasViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/10/25.
//

import UIKit
import GRDB

class LogGasViewController: BaseViewController {
    @IBOutlet weak var tableView: UITableView!
    
    var diveLog: Row!
    
    var onUpdated: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Log - Gas Details",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        // Register the default cell
        tableView.backgroundColor = .clear
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Kiểm tra nếu là pop (trở lại màn hình trước) mới gọi onUpdated
        if self.isMovingFromParent {
            onUpdated?()
        }
    }
}

extension LogGasViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let diveMode = diveLog.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 {
            return 3
        }
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogGasCell", for: indexPath) as! LogGasCell
        cell.backgroundColor = .clear
        cell.bindValueAt(row: indexPath.row, fromDiveLog: diveLog)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Logs", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "GasDetailViewController") as! GasDetailViewController
        vc.diveLog = diveLog
        vc.gasNo = indexPath.row+1
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

