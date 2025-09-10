//
//  DiveSpotsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/2/25.
//

import UIKit
import GRDB

class DiveSpotsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var cancelView: UIView!
    
    @IBOutlet weak var deleteLb: UILabel!
    
    @IBOutlet weak var noSpotLb: UILabel!
    
    var selectMode = false
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    
    var divespots:[Row] = []
    var diveLog: Row?
    
    var didUpdate = false
    var onUpdated: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.\
        if selectMode {
            self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                      title: self.title ?? "Dive Spot",
                                                      pushBack: true,
                                                      backImage: "chevron.backward")
        } else {
            self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        }
        self.title = nil
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if selectMode == false {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            tableView.addGestureRecognizer(longPressGesture)
        }
        
        loadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Kiểm tra nếu là pop (trở lại màn hình trước) mới gọi onUpdated
        if self.isMovingFromParent, didUpdate {
            onUpdated?()
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
    
    private func loadData() {
        do {
            let spots = try DatabaseManager.shared.fetchData(from: "divespot")
            divespots = spots
            
            for i in 0..<divespots.count {
                let spot = divespots[i]
                if let dlog = diveLog, dlog.stringValue(key: "DiveSiteID").toInt() == spot.intValue(key: "id") {
                    selectedIndexes.insert(i)
                    break
                }
            }
        } catch {
            PrintLog("Failed to fetch certificates data: \(error)")
        }
        
        updateUIForDeleteMode()
    }
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        // Đang ở chế độ chọn: thực hiện xóa
        if selectedIndexes.count > 0 {
            PrivacyAlert.showMessage(
                message: "Are you sure you want to delete selected dive spots?",
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
        selectedIndexes.removeAll()
        updateUIForDeleteMode()
    }
    
    @IBAction func addButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "DiveSpots", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DiveSpotViewController") as! DiveSpotViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func updateUIForDeleteMode() {
        addView.isHidden = isDeleteMode
        cancelView.isHidden = !isDeleteMode
        deleteLb.text = isDeleteMode ? "Delete Selected" : "Delete"
        
        deleteView.isHidden = true
        if divespots.count == 0 {
            tableView.isHidden = true
            noSpotLb.isHidden = false
            addView.isHidden = false
            cancelView.isHidden = true
            isDeleteMode = false
        } else {
            tableView.isHidden = false
            noSpotLb.isHidden = true
        }
        
        if selectedIndexes.count > 0 {
            deleteView.isHidden = false
        }
        
        tableView.reloadData()
    }
    
    func deleteSelectedItems() {
        let sortedIndexes = selectedIndexes.sorted(by: >)
        for index in sortedIndexes {
            if let id = divespots[index]["id"] as? Int64 {
                DatabaseManager.shared.deleteRows(from: "divespot", where: "id=?", arguments: [id])
                divespots.remove(at: index)
            }
        }
        selectedIndexes.removeAll()
        tableView.reloadData()
    }
}

extension DiveSpotsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 75
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return divespots.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DiveSpotCell", for: indexPath) as! DiveSpotCell
        
        // Hiện checkbox nếu đang ở chế độ xóa
        cell.checkbox.isHidden = !isDeleteMode
        cell.checkbox.isSelected = selectedIndexes.contains(indexPath.row)
        
        let row = divespots[indexPath.row]
        cell.spotNameLb.text = row["spot_name"]
        cell.spotCountryLb.text = row["country"]
        
        // Cập nhật accessory tùy vào mode
        if selectMode {
            let checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark"))
            checkmarkImageView.tintColor = .black // Đặt màu đen
            cell.accessoryView = selectedIndexes.contains(indexPath.row) ? checkmarkImageView : nil
            cell.accessoryType = .none
        } else {
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
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
            
            if selectedIndexes.count > 0 {
                deleteView.isHidden = false
            } else {
                deleteView.isHidden = true
            }
            
            tableView.reloadRows(at: [indexPath], with: .fade)
        } else {
            if selectMode == false {
                let storyboard = UIStoryboard(name: "DiveSpots", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "DiveSpotViewController") as! DiveSpotViewController
                vc.mode = .edit(item: divespots[indexPath.row])
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                if selectedIndexes.contains(indexPath.row) {
                    selectedIndexes.remove(indexPath.row)
                } else {
                    selectedIndexes.removeAll()
                    selectedIndexes.insert(indexPath.row)
                }
                
                PrintLog("\(selectedIndexes)")
                
                var properties: [String:Any] = [:]
                if selectedIndexes.count == 0 {
                    properties["DiveSiteID"] = ""
                } else {
                    if let selectedIdx = selectedIndexes.first {
                        let row = divespots[selectedIdx]
                        let diveSpotId = row.intValue(key: "id")
                        
                        properties["DiveSiteID"] = "\(diveSpotId)"
                    }
                }
                
                DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                                   params: properties,
                                                   conditions: "where DiveID=\(diveLog!.intValue(key: "DiveID"))")
                
                self.didUpdate = true
                
                tableView.reloadData()
            }
        }
    }
}
