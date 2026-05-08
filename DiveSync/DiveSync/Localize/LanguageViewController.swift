//
//  LanguageViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/23/25.
//

import UIKit

class LanguageViewController: BaseViewController {
    @IBOutlet weak var tableView: UITableView!
    
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

extension LanguageViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return LocalizationManager.supportedLanguages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        let item = LocalizationManager.supportedLanguages[indexPath.row]
        let currentLang = LocalizationManager.shared.currentLanguage
        
        cell.bindCell(title: item.0, value: nil)
        
        cell.accessoryType = .none
        
        if item.1 == currentLang {
            cell.accessoryType = .checkmark
            cell.tintColor = .gray   // màu dấu check
        }
        
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedLang = LocalizationManager.supportedLanguages[indexPath.row].1
        
        // 1️⃣ Set ngôn ngữ
        LocalizationManager.shared.currentLanguage = selectedLang
        
        // 2️⃣ Back ra màn trước
        navigationController?.popViewController(animated: true)
    }
}
