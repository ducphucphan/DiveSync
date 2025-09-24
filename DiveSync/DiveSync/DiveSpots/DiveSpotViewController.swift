//
//  DiveSportViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/3/25.
//

import UIKit
import MapKit
import CoreLocation
import GRDB

class DiveSpotViewController: BaseViewController, UISearchResultsUpdating, UISearchControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pinImageView: UIImageView!
    
    @IBOutlet weak var latValueLb: UILabel!
    @IBOutlet weak var lngValueLb: UILabel!
    
    @IBOutlet weak var spotNameValueLb: UILabel!
    @IBOutlet weak var countryValueLb: UILabel!
    
    private var searchController: UISearchController!
    private var searchButton: UIBarButtonItem!
    
    let locationManager = CLLocationManager()
    var currentLocation = CLLocationCoordinate2D(latitude: .zero, longitude: .zero)
    
    var mode: EditMode = .add(maxId: 0)
    var didSetInitialRegion = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Dive Spot",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        mapView.delegate = self
        mapView.showsUserLocation = false  // Tắt chấm xanh mặc định
        
        searchButton = UIBarButtonItem (
            barButtonSystemItem: .search,
            target: self,
            action: #selector(didTapSearchButton)
        )
        navigationItem.rightBarButtonItem = searchButton
        
        // Đặt màu cho tất cả UIBarButtonItem trong navigation bar
        navigationController?.navigationBar.tintColor = .white
        
        // Setup SearchController
        setupSearchBar()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(didDragMap(_:)))
        panGesture.delegate = self
        mapView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(didPinchMap(_:)))
        pinchGesture.delegate = self
        mapView.addGestureRecognizer(pinchGesture)
        
        if case .edit(let item) = mode {
            fillData(row: item)
        }
        
    }
    
    private func setupSearchBar() {
        let resultsController = SearchDiveSpotsResultsViewController()
        resultsController.delegate = self
        
        searchController = UISearchController(searchResultsController: resultsController)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search location"
        searchController.delegate = self
        searchController.searchBar.tintColor = .white
        definesPresentationContext = true
        
        let searchBar = searchController.searchBar
        searchBar.barStyle = .black // đảm bảo text white
        
        let textField = searchBar.searchTextField
        
        // Placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search location",
            attributes: [.foregroundColor: UIColor.white]
        )
        
        // Text color
        textField.textColor = .white
        textField.tintColor = .white  // caret (con trỏ) màu trắng
        
        // Kính lúp
        if let leftIconView = textField.leftView as? UIImageView {
            leftIconView.tintColor = .white
            leftIconView.image = leftIconView.image?.withRenderingMode(.alwaysTemplate)
        }
        
    }
    
    private func fillData(row: Row) {
        
        spotNameValueLb.text = row.stringValue(key: "spot_name")
        countryValueLb.text = row.stringValue(key: "country")
        
        if let lat = row["latitude"] as? Float64, let lng = row["longitude"] as? Float64 {
            latValueLb.text = Utilities.coordinateLatString(Float(lat))
            lngValueLb.text = Utilities.coordinateLatString(Float(lng))
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let region = MKCoordinateRegion(center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            
            mapView.setRegion(region, animated: true)
        }
    }
    
    @objc private func didTapSearchButton() {
        navigationItem.searchController = searchController
        searchController?.isActive = true
        navigationItem.rightBarButtonItem = nil // ẩn nút search khi đang search
        
        // Gọi sau một nhịp runloop để đảm bảo searchBar đã attach vào view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }
    
    @objc func didDragMap(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            updateCoordinateLocation(fromMap: true)
        }
    }
    
    @objc func didPinchMap(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            updateCoordinateLocation(fromMap: true)
        }
    }
    
    func updateCoordinateLocation(fromMap: Bool = false) {
        if fromMap {
            latValueLb.text = Utilities.coordinateLatString(Float(mapView.centerCoordinate.latitude))
            lngValueLb.text = Utilities.coordinateLongString(Float(mapView.centerCoordinate.longitude))
            mapView.setRegion(MKCoordinateRegion(center: mapView.centerCoordinate, span: mapView.region.span), animated: true)
        } else {
            latValueLb.text = Utilities.coordinateLatString(Float(currentLocation.latitude))
            lngValueLb.text = Utilities.coordinateLongString(Float(currentLocation.longitude))
        }
    }
    
    @IBAction func getLocationTapped(_ sender: Any) {
        if let location = locationManager.location {
            let span = mapView.region.span
            
            let latMeters = span.latitudeDelta * 111_000
            let lonMeters = span.longitudeDelta * 111_000
            
            let region = MKCoordinateRegion(center: location.coordinate,
                                            latitudinalMeters: latMeters,
                                            longitudinalMeters: lonMeters)
            mapView.setRegion(region, animated: true)
            
            updateCoordinateLocation()
        }
    }
    
    @IBAction func spotNameTapped(_ sender: Any) {
        let currentValue = spotNameValueLb.text ?? ""
        InputAlert.show(title: "Spot Name", currentValue: currentValue) { action in
            switch action {
            case .save(let value):
                self.spotNameValueLb.text = value
            default:
                break
            }
        }
    }
    
    @IBAction func countryTapped(_ sender: Any) {
        let currentValue = countryValueLb.text ?? ""
        InputAlert.show(title: "Country", currentValue: currentValue) { action in
            switch action {
            case .save(let value):
                self.countryValueLb.text = value
            default:
                break
            }
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func addButtonTapped(_ sender: UIButton) {
        
        updateSpot(mode: mode)
        
    }
    
    private func updateSpot(mode: EditMode) {
        guard let spotName = spotNameValueLb.text, !spotName.isEmpty, spotName != "-" else {
            showAlert(on: self, message: "Enter spot name")
            return
        }
        guard let spotCountry = countryValueLb.text, !spotCountry.isEmpty, spotCountry != "-" else {
            showAlert(on: self, message: "Enter spot country")
            return
        }
        
        var properties: [String:Any] = [:]
        properties["spot_name"] = spotName
        properties["country"] = spotCountry
        properties["latitude"] = Float(mapView.centerCoordinate.latitude)
        properties["longitude"] = Float(mapView.centerCoordinate.longitude)
        
        switch mode {
        case .add(_):
            _ = DatabaseManager.shared.insertIntoTable(tableName: "divespot", params: properties)
            self.navigationController?.popViewController(animated: true)
        case .edit(let item):
            PrivacyAlert.showMessage(
                message: "Do you want to save changes?",
                allowTitle: "SAVE",
                denyTitle: "CANCEL"
            ) { action in
                switch action {
                case .allow:
                    DatabaseManager.shared.updateTable(tableName: "divespot",
                                                       params: properties,
                                                       conditions: "where id=\(item.intValue(key: "id"))")
                    self.navigationController?.popViewController(animated: true)
                case .deny:
                    break
                }
            }
        }
    }
    
    // Search update
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text, !query.isEmpty else {
            // Nếu query rỗng thì xóa kết quả
            if let resultsVC = searchController.searchResultsController as? SearchDiveSpotsResultsViewController {
                resultsVC.results = []
                resultsVC.tableView.reloadData()
            }
            return
        }
        
        // Gọi updateQuery trên resultsController
        if let resultsVC = searchController.searchResultsController as? SearchDiveSpotsResultsViewController {
            resultsVC.updateQuery(query)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Ẩn searchController khỏi navigationItem
        navigationItem.searchController = nil
        navigationItem.rightBarButtonItem = searchButton
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        navigationItem.searchController = nil
        navigationItem.rightBarButtonItem = searchButton
    }
}

extension DiveSpotViewController: SearchDiveSpotsResultsDelegate {
    func didSelectSearchResult(_ result: MKLocalSearchCompletion) {
        let placeName = result.title
        
        // Dùng MKLocalSearch để lấy MKMapItem
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            guard let mapItem = response?.mapItems.first, error == nil else {
                print("Can not found location")
                return
            }
            
            let coordinate = mapItem.placemark.coordinate
            let latitude = coordinate.latitude
            let longitude = coordinate.longitude
            
            // Dùng MKPlacemark để lấy country chính xác
            let country = mapItem.placemark.country ?? "-"
            
            DispatchQueue.main.async {
                // Cập nhật UI
                self.spotNameValueLb.text = placeName
                self.countryValueLb.text = country
                self.latValueLb.text = Utilities.coordinateLatString(Float(latitude))
                self.lngValueLb.text = Utilities.coordinateLongString(Float(longitude))
                
                // Di chuyển map và thêm annotation
                let region = MKCoordinateRegion(center: coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                self.mapView.setRegion(region, animated: true)
                
                self.mapView.removeAnnotations(self.mapView.annotations)
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = placeName
                self.mapView.addAnnotation(annotation)
            }
        }
        
        searchController.isActive = false
        navigationItem.searchController = nil
    }
}

extension DiveSpotViewController: CLLocationManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else { return }
        
        let coordinate = userLocation.coordinate
        currentLocation = coordinate
        
        if case .add = mode, !didSetInitialRegion {
            didSetInitialRegion = true   // 👉 đảm bảo chỉ chạy 1 lần
            
            let region = MKCoordinateRegion(center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: true)
            
            // Xóa hết annotation cũ (nếu muốn chỉ có 1 marker)
            mapView.removeAnnotations(mapView.annotations)
            
            // Thêm annotation mới
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            
            updateCoordinateLocation()
        }
    }
    
    // Tùy chỉnh hình ảnh annotation
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil // Nếu bạn bật showsUserLocation, cần bỏ qua mặc định
        }
        
        let identifier = "CurrentLocation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = false
        } else {
            annotationView?.annotation = annotation
        }
        
        // Gắn hình bạn cung cấp (ví dụ: "myCustomIcon")
        annotationView?.image = UIImage(named: "flag.checkered")?.withTintColor(.red, renderingMode: .alwaysOriginal)
        
        annotationView?.frame.size = CGSize(width: 30, height: 40)  // 👈 chỉnh kích thước tại đây
        
        return annotationView
    }
}
