//
//  HelpViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/23/25.
//

import UIKit
import MessageUI
import ZIPFoundation

class HelpViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let data = ["Tutorial", "FAQ", "Send to Tech Support"]
    let icons = ["tutorial", "faq", "email"] // Replace with your actual icon names
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension HelpViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        cell.bindCell(title: data[indexPath.row].localized, value: nil, imageName: icons[indexPath.row])
        
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            break
        case 1:
            break
        case 2:
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
            
            let message = NSLocalizedString("Do you want to send us the data from the DIVESYNC app for analysis?".localized, comment: "")
            let attributedMessage = NSAttributedString(
                string: message,
                attributes: [.font: UIFont.systemFont(ofSize: 13)]
            )
            alert.setValue(attributedMessage, forKey: "attributedMessage")
            let yesAction = UIAlertAction(title: "OK".localized, style: .default) { _ in
                self.sendMail()
            }
            
            let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil)
            
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
        default:
            break
        }
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
        mail.setToRecipients(["support@divesync.io"])
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

extension HelpViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
