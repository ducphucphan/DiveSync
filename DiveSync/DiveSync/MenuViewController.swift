//
//  MenuViewController.swift
//  DL2Demo
//
//  Created by Phan Duc Phuc on 7/12/24.
//

import UIKit

class MenuViewController: BaseViewController {

    @IBOutlet weak var tableview: UITableView!
    
    let data = ["Logs", "Devices", "Owner Info", "Dive Spots", "Statistics", "Language", "Help", "About"]
    let icons = ["log_icon", "watch_icon", "user_icon", "loc_icon", "stat_icon", "lang", "help", "about_icon"] // Replace with your actual icon names
    
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
    
    override func updateTexts() {
        super.updateTexts()
        self.tableview.reloadData()
    }
    
    

}

extension MenuViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var viewcontroller: UIViewController
        
        switch indexPath.row {
        case 0:
            let storyboard = UIStoryboard(name: "Logs", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "LogsViewController") as! LogsViewController
        case 1:
            let storyboard = UIStoryboard(name: "Device", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "DeviceViewController") as! DeviceViewController
        case 2:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "OwnerInfoViewController") as! OwnerInfoViewController
        case 3:
            let storyboard = UIStoryboard(name: "DiveSpots", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "DiveSpotsViewController") as! DiveSpotsViewController
        case 4:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "StatisticsViewController") as! StatisticsViewController
        case 5:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "LanguageViewController") as! LanguageViewController
        case 6:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        default:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            viewcontroller = storyboard.instantiateViewController(withIdentifier: "AboutViewController") as! AboutViewController
        }
        
        viewcontroller.title = data[indexPath.row].localized
        self.navigationController?.pushViewController(viewcontroller, animated: true)
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
        cell.bind(imageName: icons[indexPath.row], title: data[indexPath.row].localized)
        return cell
    }
}
