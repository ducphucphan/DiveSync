//
//  PhotosViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/7/25.
//

import UIKit
import GRDB

class PhotosViewController: BaseViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var noPhotosLabel: UILabel!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var cancelView: UIView!
    
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    
    var photoColumnNumber = 3
    
    var photos: [URL] = []
    
    var diveLog: Row! {
        didSet {
        }
    }
    
    var onUpdated: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Photos",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            photoColumnNumber = 4
        }
        
        configCollectionView()
        
        loadPhotos()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Kiểm tra nếu là pop (trở lại màn hình trước) mới gọi onUpdated
        if self.isMovingFromParent {
            onUpdated?()
        }
    }
    
    private func configCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.collectionViewLayout = layout
    }
    
    @IBAction private func removeTapped(_ sender: UIButton) {
        PrivacyAlert.showMessage(message: "Are you sure to want to delete selected photos?", allowTitle: "DELETE", denyTitle: "CANCEL") { action in
            var errors: [Error] = []
            
            for index in self.selectedIndexes {
                let fileName = self.photos[index].lastPathComponent
                do {
                    try DivePhotoManager.shared.deletePhoto(
                        fileName: fileName,
                        diveID: self.diveLog.intValue(key: "DiveID"),
                        modelID: self.diveLog.stringValue(key: "ModelID"),
                        serialNo: self.diveLog.stringValue(key: "SerialNo")
                    )
                } catch {
                    errors.append(error)
                }
            }
            
            self.selectedIndexes.removeAll()
            self.loadPhotos()
            
            if !errors.isEmpty {
                // Optional: hiển thị lỗi nếu cần
                print("Có lỗi khi xoá một số ảnh:", errors)
            }
        }
    }
    
    @IBAction func addImageTapped(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let cameraPicker = UIImagePickerController()
                cameraPicker.sourceType = .camera
                cameraPicker.delegate = self
                self.present(cameraPicker, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: nil, message: "Camera could not available for this device!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        let albumsAction = UIAlertAction(title: "Albums", style: .default) { _ in
            let albumPicker = UIImagePickerController()
            albumPicker.sourceType = .photoLibrary
            albumPicker.delegate = self
            self.present(albumPicker, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(cameraAction)
        actionSheet.addAction(albumsAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func loadPhotos() {
        
        do {
            let urls = try DivePhotoManager.shared.loadPhotoPaths(forDiveID: diveLog.intValue(key: "DiveID"),
                                                                  modelID: diveLog.stringValue(key: "ModelID"),
                                                                  serialNo: diveLog.stringValue(key: "SerialNo"))
            photos = urls
        } catch {}
        
        noPhotosLabel.isHidden = !(photos.count == 0)
        
        if photos.count == 0 {
            deleteView.isHidden = true
            cancelView.isHidden = true
        }
        
        collectionView.reloadData()
    }
}

extension PhotosViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let numberOfColumns: CGFloat = CGFloat(photoColumnNumber)
        let spacing: CGFloat = 8
        let totalSpacing = spacing * (numberOfColumns - 1)
        let totalInsets: CGFloat = spacing * 2  // 8pt padding trái/phải
        let availableWidth = collectionView.bounds.width - totalSpacing - totalInsets
        let itemWidth = floor(availableWidth / numberOfColumns)
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.mainImageView.image = UIImage(contentsOfFile: photos[indexPath.item].path)
        cell.isChecked = selectedIndexes.contains(indexPath.item) // Reset lại trạng thái check đúng
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else { return }
        cell.isChecked.toggle()
        
        
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
        
    }
}

extension PhotosViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            
            /*
             var imageName = "default_name.jpg" // fallback name
             
             if let imageURL = info[.imageURL] as? URL {
             imageName = imageURL.lastPathComponent
             }
             
             _ = Utilities.saveSelectedImage(image, createImageDate: Date(), dir: PHOTOS_DIR, name: imageName)
             
             //photos.append(imageName)
             
             loadPhotos()
             */
            do {
                try DivePhotoManager.shared.addPhoto(image,
                                                     diveID: diveLog.intValue(key: "DiveID"),
                                                     modelID: diveLog.stringValue(key: "ModelID"),
                                                     serialNo: diveLog.stringValue(key: "SerialNo"))
            } catch {}
            
            loadPhotos()
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

