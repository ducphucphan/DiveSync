//
//  AboutViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/26/25.
//

import UIKit

class SettingsViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
        
    let titleData = ["Language", "Date Format", "Time Format"]
    var subTitleData: [String] {
        // 1. Lấy tên hiển thị của ngôn ngữ hiện tại
        let currentLangCode = LocalizationManager.shared.currentLanguage
        let currentLanguageName = LocalizationManager.shared.getLanguageName(for: currentLangCode)
        
        // 2. Lấy định dạng ngày: Khai báo rõ kiểu ": Int" để giúp Xcode xác định T
        let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
        let dateStr = (dateFormatId == 0) ? "DD.MM.YY" : "MM.DD.YY"
        
        // 3. Lấy định dạng giờ: Tương tự khai báo rõ kiểu ": Int"
        let timeFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
        let timeStr = (timeFormatId == 0) ? "12h" : "24h"
        
        return [currentLanguageName, dateStr, timeStr]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.\
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 1. Xóa sạch left items cũ để tránh bị cache layout
        self.navigationItem.leftBarButtonItems = nil
        
        // 2. Gọi hàm gán mới
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: "Settings".localized, pushBack: true)
        
        // 3. Xóa title gốc nếu bạn không muốn nó hiển thị mặc định ở giữa
        self.title = nil
        
        tableView.reloadData()
    }

}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        cell.bindCell(title: titleData[indexPath.row].localized, value: subTitleData[indexPath.row])
        
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "LanguageViewController") as! LanguageViewController
            vc.title = titleData[indexPath.row].localized
            self.navigationController?.pushViewController(vc, animated: true)
            
        case 1:
            var currentValue = "DD.MM.YY"
            if let dateFormatIdentify:Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify),
               dateFormatIdentify == 1 {
                currentValue = "MM.DD.YY"
            }
            
            ItemSelectionAlert.showMessage(
                message: "Date Format".localized,
                options: ["MM.DD.YY", "DD.MM.YY"],
                selectedValue: currentValue
            ) { [weak self] action, value, index in
                guard let self = self else { return }
                
                if action == .allow, let value = value {
                    PrintLog("Save to backend: \(value)")
                    
                    // Decline = false, Allow = true
                    AppSettings.shared.set((index == 0) ? 1 : 0, forKey: AppSettings.Keys.dateFormatIdentify)
                    
                    self.tableView.reloadData()
                }
            }
        case 2:
            var currentValue = "12h"
            if let timeFormatIdentify:Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify),
               timeFormatIdentify == 1 {
                currentValue = "24h"
            }
            
            ItemSelectionAlert.showMessage(
                message: "Time Format".localized,
                options: ["12h".localized, "24h".localized],
                selectedValue: currentValue
            ) { [weak self] action, value, index in
                guard let self = self else { return }
                
                if action == .allow, let value = value {
                    PrintLog("Save to backend: \(value)")
                    
                    // Decline = false, Allow = true
                    AppSettings.shared.set(index, forKey: AppSettings.Keys.timeFormatIdentify)
                    
                    self.tableView.reloadData()
                }
            }
        default:
            break
        }
    }
}
