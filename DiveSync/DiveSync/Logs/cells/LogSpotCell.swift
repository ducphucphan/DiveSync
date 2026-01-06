//
//  LogSpotCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/6/25.
//

import UIKit
import MapKit
import GRDB

class LogSpotCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var coordinateLb: UILabel!
    
    var pinCoordinate: CLLocationCoordinate2D? // lưu vị trí pin
    
    var diveLog:Row! {
        didSet {
            loadData()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        //mapView.delegate = self
    }
    
    func loadData() {
        let spotId = diveLog.stringValue(key: "DiveSiteID").toInt()
        if spotId == 0 {
            // Load world map
            let worldCenter = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            let span = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            
            mapView.setRegion(MKCoordinateRegion(center: worldCenter, span: span), animated: false)
            coordinateLb.isHidden = true
            
        } else {
            // Get Spot Info from database.
            do {
                let spots = try DatabaseManager.shared.fetchData(from: "divespot",
                                                                where: "ID=?",
                                                            arguments: [spotId])
                
                // Spot_Name - Country - latitide - longitude
                if let row = spots.first {
                    let name = row["spot_name"] as? String ?? "---"
                    let lat = (row["latitude"] as? Double) ?? 0
                    let lng = (row["longitude"] as? Double) ?? 0
                    let latStr = Utilities.coordinateLatString(Float(lat))
                    let lngStr = Utilities.coordinateLatString(Float(lng))
                    
                    // Cập nhật giao diện như ở ví dụ trước
                    coordinateLb.isHidden = true
                    coordinateLb.setTextStroke(text: "\(latStr), \(lngStr)", textColor: .darkGray, strokeColor: .white, strokeWidth: -1)
                    
                    // Cập nhật bản đồ
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    //let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                    //mapView.setRegion(region, animated: false)
                    mapView.setCenterCoordinate(coordinate, zoomLevel: 10, animated: false)
                    
                    // Hiển thị marker
                    mapView.removeAnnotations(mapView.annotations)
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coordinate
                    annotation.title = String(format: "%@\n%@, %@", name, latStr, lngStr)
                    mapView.addAnnotation(annotation)
                    
                    pinCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
            } catch {
                PrintLog("Failed to fetch data: \(error)")
            }
        }
        
    }
}

extension LogSpotCell: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard let coordinate = pinCoordinate else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let center = mapView.centerCoordinate
            let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            
            if distance > 50 {
                mapView.setCenter(coordinate, animated: true)
            }
        }
    }
}
