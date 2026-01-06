//
//  RecycleViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 1/5/26.
//

import UIKit
import GRDB
import RxSwift
import ProgressHUD

class RecycleViewController: BaseViewController {
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var restoreView: UIView!
    
    @IBOutlet weak var deleteLb: UILabel!
    @IBOutlet weak var restoreLb: UILabel!
    
    @IBOutlet weak var noDivesLb: UILabel!
    
    var diveList:[Row] = []
    
    var selectMode = false
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    
    var onUpdated: ((Bool) -> Void)?
    
    private var disposeBag = DisposeBag()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Recently deleted".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        noDivesLb.text = "No Logs".localized
        deleteLb.text = "Delete".localized
        restoreLb.text = "Restore".localized
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        
        loadData(sort: SortPreferences.load())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if selectMode == false {
            //let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            //tableView.addGestureRecognizer(longPressGesture)
        }
        
        isDeleteMode = true
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
    
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        // Đang ở chế độ chọn: thực hiện xóa
        if selectedIndexes.count > 0 {
            PrivacyAlert.showMessage(
                message: "Are you sure you want to delete selected dives?".localized,
                allowTitle: "Delete".localized.uppercased(),
                denyTitle: "Cancel".localized.uppercased()
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
    
    @IBAction func restoreButtonTapped(_ sender: UIButton) {
        // Đang ở chế độ chọn: thực hiện xóa
        if selectedIndexes.count > 0 {
            self.restoreSelectedItems()
            self.selectedIndexes.removeAll()
            self.updateUIForDeleteMode()
        }
    }
    
    private func loadData(sort: SortOptions? = nil) {
        do {
            let diveLog = try DatabaseManager.shared.fetchDiveLog(where: "Deleted=1", sort: sort)
            diveList = diveLog
        } catch {
            PrintLog("Failed to load divelog data: \(error)")
        }
        
        updateUIForDeleteMode()
    }
    
    func updateUIForDeleteMode(indexPaths:[IndexPath]? = nil) {
        if diveList.count == 0 {
            tableView.isHidden = true
            noDivesLb.isHidden = false
            isDeleteMode = false
        } else {
            tableView.isHidden = false
            noDivesLb.isHidden = true
        }
        
        if selectedIndexes.count > 0 {
            deleteLb.text = "Delete Selected".localized
        } else {
            deleteLb.text = "Delete".localized
        }
        
        if let reloadedIndexPaths = indexPaths, reloadedIndexPaths.count > 0 {
            tableView.reloadRows(at: reloadedIndexPaths,  with: .fade)
        } else {
            tableView.reloadData()
        }
    }
    
    func deleteSelectedItems() {
        let sortedIndexes = selectedIndexes.sorted(by: >)
        for index in sortedIndexes {
            let diveID = diveList[index].intValue(key: "DiveID")
            DatabaseManager.shared.deleteRows(from: "DiveLog", where: "DiveID=?", arguments: [diveID])
            DatabaseManager.shared.deleteRows(from: "DiveProfile", where: "DiveID=?", arguments: [diveID])
            
            diveList.remove(at: index)
        }
        selectedIndexes.removeAll()
        tableView.reloadData()
        
        self.onUpdated?(true)
    }
    
    func restoreSelectedItems() {
        let sortedIndexes = selectedIndexes.sorted(by: >)
        for index in sortedIndexes {
            let diveID = diveList[index].intValue(key: "DiveID")
            
            DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                               params: ["Deleted": 0],
                                               conditions: "where DiveID=\(diveID)")
            
            diveList.remove(at: index)
        }
        selectedIndexes.removeAll()
        tableView.reloadData()
        
        self.onUpdated?(true)
    }
}

extension RecycleViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return diveList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath) as! LogCell
        
        // Hiện checkbox nếu đang ở chế độ xóa
        cell.checkbox.isHidden = !isDeleteMode
        cell.checkbox.isSelected = selectedIndexes.contains(indexPath.row)
        
        cell.bindData(row: diveList[indexPath.row])
        
        cell.onFavoriteTapped = {[weak self] isFavorite in
            guard let self = self else { return }
            
            DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                               params: ["IsFavorite": isFavorite ? 1:0],
                                               conditions: "where DiveID=\(self.diveList[indexPath.row].intValue(key: "DiveID"))")
            
            self.loadData(sort: SortPreferences.load())
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
            
            updateUIForDeleteMode(indexPaths: [indexPath])
        }
        /*
        else {
            if selectMode == false {
                let storyboard = UIStoryboard(name: "Logs", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "LogViewController") as! LogViewController
                vc.diveLog = diveList[indexPath.row]
                vc.onUpdated = {[weak self] updated in
                    guard let self = self else { return }
                    if updated {
                        self.loadData(sort: SortPreferences.load())
                    }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                if selectedIndexes.contains(indexPath.row) {
                    selectedIndexes.remove(indexPath.row)
                } else {
                    selectedIndexes.removeAll()
                    selectedIndexes.insert(indexPath.row)
                }
                updateUIForDeleteMode()
            }
        }
        */
    }
}
