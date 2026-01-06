//
//  CertificationsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/4/25.
//

import UIKit
import GRDB

class CertificationsViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noCertLb: UILabel!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var cancelView: UIView!
    
    @IBOutlet weak var deleteLb: UILabel!
    @IBOutlet weak var addLb: UILabel!
    @IBOutlet weak var cancelLb: UILabel!
    
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    
    var maxCertId = 0
    var certificates:[Row] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the default cell
        tableView.backgroundColor = .clear
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Certifications".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        addLb.text = "Add".localized
        cancelLb.text = "Cancel".localized
        noCertLb.text = "No Certification to List".localized
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPressGesture)
        
        loadData()
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
                message: "Are you sure you want to delete selected certifications?".localized,
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
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        isDeleteMode = false
        selectedIndexes.removeAll()
        updateUIForDeleteMode()
    }
    
    @IBAction func addButtonTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CertificationViewController") as! CertificationViewController
        vc.mode = .add(maxId: maxCertId)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func updateUIForDeleteMode() {
        addView.isHidden = isDeleteMode
        cancelView.isHidden = !isDeleteMode
        deleteLb.text = isDeleteMode ? "Delete Selected".localized : "Delete".localized
        
        deleteView.isHidden = true
        if certificates.count == 0 {
            tableView.isHidden = true
            noCertLb.isHidden = false
            addView.isHidden = false
            cancelView.isHidden = true
            isDeleteMode = false
        } else {
            tableView.isHidden = false
            noCertLb.isHidden = true
        }
        
        if selectedIndexes.count > 0 {
            deleteView.isHidden = false
        }
        
        tableView.reloadData()
    }
    
    func deleteSelectedItems() {
        let sortedIndexes = selectedIndexes.sorted(by: >)
        for index in sortedIndexes {
            if let id = certificates[index]["id"] as? Int64 {
                DatabaseManager.shared.deleteRows(from: "certificate", where: "id=?", arguments: [id])
                if let imageName = certificates[index]["imagepathfront"] as? String {
                    let imageNamePath = HomeDirectory().appendingFormat("%@", USERINFO_DIR) + imageName
                    if FileManager.default.fileExists(atPath: imageNamePath) {
                        try? FileManager.default.removeItem(atPath: imageNamePath)
                    }
                }
                certificates.remove(at: index)
            }
        }
        selectedIndexes.removeAll()
        tableView.reloadData()
    }
    
    private func loadData() {
        do {
            let certs = try DatabaseManager.shared.fetchData(from: "certificate")
            certificates = certs
            
            if let maxId = certificates.compactMap({ $0["id"] as? Int64 }).max() {
                maxCertId = Int(maxId)
            }
        } catch {
            PrintLog("Failed to fetch certificates data: \(error)")
        }
        
        updateUIForDeleteMode()
    }
}

extension CertificationsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return certificates.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CertificationCell", for: indexPath) as! CertificationCell
        
        // Hiện checkbox nếu đang ở chế độ xóa
        cell.checkbox.isHidden = !isDeleteMode
        cell.checkbox.isSelected = selectedIndexes.contains(indexPath.row)
        
        let row = certificates[indexPath.row]
        
        cell.certNoLb.text = "Certification".localized + " \(indexPath.row+1)"
        cell.certNameLb.text = row["levels"]
        cell.dateLb.text = row["dates"]
        
        if let imageName = row["imagepathfront"] as? String {
            let imageNamePath = HomeDirectory().appendingFormat("%@", USERINFO_DIR) + imageName
            cell.imv.image = UIImage(contentsOfFile: imageNamePath)
        } else {
            cell.imv.image = nil
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
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "CertificationViewController") as! CertificationViewController
            vc.titleText = "Certificate".localized + " \(indexPath.row+1)"
            vc.mode = .edit(item: certificates[indexPath.row])
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
