//
//  MenuViewController.swift
//  DL2Demo
//
//  Created by Phan Duc Phuc on 7/12/24.
//

import UIKit
import MessageUI
import ZIPFoundation

class MenuViewController: BaseViewController {

    @IBOutlet weak var tableview: UITableView!
    
    let data = ["Logs", "Devices", "Owner Info", "Dive Spots", "Statistics", "About", "Send to Tech Support"]
    let icons = ["log_icon", "watch_icon", "user_icon", "loc_icon", "stat_icon", "about_icon", "send_to_tech"] // Replace with your actual icon names
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegate and data source
        tableview.delegate = self
        tableview.dataSource = self
        
        // Configure navigation bar for large titles
        //title = "More"
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: "DIVESYNC")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func sendMail() {
        // 1. Lấy file database
        guard let databaseURL = try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("divesync.db") else {
            PrintLog("Không tìm thấy file database.")
            return
        }
        
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            PrintLog("File database không tồn tại.")
            return
        }
        
        // 2. Lấy file log
        let logURL = databaseURL.deletingLastPathComponent().appendingPathComponent("divesync.log")
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            PrintLog("File log không tồn tại.")
            return
        }
        
        // 3. Tạo file zip tạm
        let zipURL = databaseURL.deletingLastPathComponent().appendingPathComponent("Feedback.zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try? FileManager.default.removeItem(at: zipURL)
        }
        
        do {
            // Tạo archive mới (throwing initializer)
            let archive = try Archive(url: zipURL, accessMode: .create)
            
            // Add database
            try archive.addEntry(with: "divesync.db", fileURL: databaseURL)
            // Add log
            try archive.addEntry(with: "divesync.log", fileURL: logURL)

        } catch {
            PrintLog("Lỗi khi tạo zip: \(error)")
            return
        }
        
        // 4. Kiểm tra gửi mail
        guard MFMailComposeViewController.canSendMail() else {
            PrintLog("Thiết bị này không gửi được email.")
            return
        }
        
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = self
        mail.setSubject("Send to tech support")
        mail.setToRecipients(["phucpd@vtm-vn.com"])
        mail.setMessageBody("", isHTML: false)
        
        // 5. Đính kèm zip
        if let fileData = try? Data(contentsOf: zipURL) {
            mail.addAttachmentData(fileData,
                                   mimeType: "application/zip",
                                   fileName: "Feedback.zip")
        } else {
            PrintLog("Không đọc được dữ liệu từ zip.")
            return
        }
        
        self.present(mail, animated: true, completion: nil)
    }

}

extension MenuViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == data.count-1 {
            if !MFMailComposeViewController.canSendMail() {
                if let mailURL = URL(string: "message://"), UIApplication.shared.canOpenURL(mailURL) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(mailURL, options: [:]) { success in
                            if success {
                                PrintLog("Opened Mail app successfully.")
                            } else {
                                PrintLog("Failed to open Mail app.")
                            }
                        }
                    } else {
                        UIApplication.shared.openURL(mailURL)
                    }
                }
                return
            }
            
            let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
            
            let alert = UIAlertController(title: "", message: "", preferredStyle: style)
            
            let attributedTitle = NSAttributedString(
                string: NSLocalizedString(title ?? "", comment: ""),
                attributes: [.font: UIFont(name: "HelveticaNeue-Medium", size: 17.0)!]
            )
            alert.setValue(attributedTitle, forKey: "attributedTitle")
            
            let message = NSLocalizedString("Do you want to send us the data from the DIVESYNC app for analysis?", comment: "")
            let attributedMessage = NSAttributedString(
                string: message,
                attributes: [.font: UIFont.systemFont(ofSize: 13)]
            )
            alert.setValue(attributedMessage, forKey: "attributedMessage")
            let yesAction = UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default) { _ in
                self.sendMail()
            }
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
            
            alert.addAction(yesAction)
            alert.addAction(cancelAction)
            
            if let popover = alert.popoverPresentationController, UIDevice.current.userInterfaceIdiom == .pad {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                            y: self.view.bounds.midY,
                                            width: 0,
                                            height: 0)
                popover.permittedArrowDirections = []
            }
            
            self.present(alert, animated: true, completion: nil)
        } else {
            var viewcontroller: UIViewController
            
            switch indexPath.row {
            case 0:
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                viewcontroller = storyboard.instantiateViewController(withIdentifier: "LogsViewController") as! LogsViewController
            case 1:
                let storyboard = UIStoryboard(name: "Device", bundle: nil)
                viewcontroller = storyboard.instantiateViewController(withIdentifier: "DeviceListViewController") as! DeviceListViewController
            case 2:
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                viewcontroller = storyboard.instantiateViewController(withIdentifier: "OwnerInfoViewController") as! OwnerInfoViewController
            case 3:
                let storyboard = UIStoryboard(name: "DiveSpots", bundle: nil)
                viewcontroller = storyboard.instantiateViewController(withIdentifier: "DiveSpotsViewController") as! DiveSpotsViewController
            case 4:
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                viewcontroller = storyboard.instantiateViewController(withIdentifier: "StatisticsViewController") as! StatisticsViewController
            default:
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                viewcontroller = storyboard.instantiateViewController(withIdentifier: "AboutViewController") as! AboutViewController
            }
            
            viewcontroller.title = data[indexPath.row]
            self.navigationController?.pushViewController(viewcontroller, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource

extension MenuViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuCell", for: indexPath) as! MenuCell
        cell.bind(imageName: icons[indexPath.row], title: data[indexPath.row])
        return cell
    }
}
        
extension MenuViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
