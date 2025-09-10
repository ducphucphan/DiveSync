//
//  AboutViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/26/25.
//

import UIKit

class AboutViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let titleData = ["DiveSync", "Website", "Email", "Permissions", "Personal Data Protection", "Terms of Use"]
    let subTitleData = ["version 1.0.0", "www.farallondive.com", "info@farallondive.com", "", "", ""]
    let icons = ["", "", "", "permision", "protect", "terms"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.\
        
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
    }
    

}

extension AboutViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        cell.bindCell(title: titleData[indexPath.row], value: subTitleData[indexPath.row], imageName: icons[indexPath.row])
        
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        if (indexPath.row > 2) {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 1:
            if let url = URL(string: "www.farallondive.com") {
                UIApplication.shared.open(url)
            }
        case 2:
            if let url = URL(string: "mailto:info@farallondive.com") {
                UIApplication.shared.open(url)
            }
        case 3:
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        case 4, 5: // Personal Data Protection & Terms
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "TermsViewController") as! TermsViewController
            vc.title = titleData[indexPath.row]
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
}
