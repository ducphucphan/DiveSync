//
//  StatisticsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/27/25.
//

import UIKit
import MapKit

class StatisticsViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var mapview: MKMapView!
    
    let titleData = ["Most Visited Dive Spot", "Total Number of Dives", "Total Dive Time", "Average Dive Time", "Max Depth", "Average Depth", "Min Temp", "Max Temp", "Average Temp"]
    
    var stats: DiveStatistics?
    var divespots:[DiveSpot]?
    var lastUnit = M
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        // Register the default cell
        tableView.backgroundColor = .clear
        
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
        
        mapview.delegate = self
        
        loadStatistics()
        loadDiveSpots()
        loadAnnotations()
    }
    
    private func loadDiveSpots() {
        do {
            divespots = try DatabaseManager.shared.fetchDiveSpotsWithLogs()
        } catch {
            PrintLog("❌ Failed to fetch dive spots: \(error)")
        }
    }
    
    private func loadStatistics() {
        do {
            let sort = SortOptions(
                direction: .decreasing,  // mới nhất trước
                field: .date,
                favoritesOnly: false
            )
            let diveLogs = try DatabaseManager.shared.fetchDiveLog(sort: sort)
            guard diveLogs.count > 0 else {
                return
            }
            lastUnit = diveLogs[0].stringValue(key: "Units").toInt()
            
            stats = try DatabaseManager.shared.fetchDiveStatistics()
            guard let statistic = stats else {
                return
            }
            PrintLog("🏝️ Most Visited Dive Site: \(statistic.mostVisitedDiveSpot ?? "Unknown")")
            PrintLog("🤿 Total Dives: \(statistic.totalNumberOfDives)")
            PrintLog("⏱️ Total Dive Time: \(statistic.totalDiveTime) mins")
            PrintLog("📏 Max Depth: \(statistic.maxDepthFT) ft")
            // ... các trường khác
        } catch {
            PrintLog("❌ Failed to fetch statistics: \(error)")
        }
    }
    
    private func loadAnnotations() {
        guard let divespots = divespots else {
            return
        }
        
        var annotations: [MKPointAnnotation] = []
        
        for location in divespots {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude.toDouble(),
                                                           longitude: location.longitude.toDouble())
            annotation.title = location.spotName
            annotations.append(annotation)
        }
        
        mapview.addAnnotations(annotations)
        mapview.showAnnotations(annotations, animated: true)
    }

}

extension StatisticsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        var value = "-"
        if let statistic = stats {
            switch indexPath.row {
            case 0:
                value = statistic.mostVisitedDiveSpot ?? "-"
            case 1:
                value = "\(statistic.totalNumberOfDives)"
            case 2:
                value = "\(statistic.totalDiveTime/60) MIN"
            case 3:
                value = "\(statistic.averageDiveTime/60) MIN"
            case 4:
                var maxDepthFT = statistic.maxDepthFT
                if lastUnit == M {
                    maxDepthFT = converFeet2Meter(maxDepthFT)
                }
                
                if lastUnit == M {
                    value = String(format: "%.1f M", maxDepthFT)
                } else {
                    value = String(format: "%.0f FT", maxDepthFT)
                }
            case 5:
                var averageDepthFT = statistic.averageDepthFT
                if lastUnit == M {
                    averageDepthFT = converFeet2Meter(averageDepthFT)
                }
                
                if lastUnit == M {
                    value = String(format: "%.1f M", averageDepthFT)
                } else {
                    value = String(format: "%.0f FT", averageDepthFT)
                }
            case 6:
                var minTempF = statistic.minTempF
                if lastUnit == M {
                    minTempF = convertF2C(minTempF)
                }
                
                if lastUnit == M {
                    value = String(format: "%.1f °C", minTempF)
                } else {
                    value = String(format: "%.0f °F", minTempF)
                }
            case 7:
                var maxTempF = statistic.maxTempF
                if lastUnit == M {
                    maxTempF = convertF2C(maxTempF)
                }
                
                if lastUnit == M {
                    value = String(format: "%.1f °C", maxTempF)
                } else {
                    value = String(format: "%.0f °F", maxTempF)
                }
            case 8:
                var averageTempF = statistic.averageTempF
                if lastUnit == M {
                    averageTempF = convertF2C(averageTempF)
                }
                
                if lastUnit == M {
                    value = String(format: "%.1f °C", averageTempF)
                } else {
                    value = String(format: "%.0f °F", averageTempF)
                }
            default:
                break
            }
        }
        
        cell.bindCell(title: titleData[indexPath.row], value: value)
        
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.accessoryType = .none
        
        return cell
    }
    
}

extension StatisticsViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Bỏ qua annotation mặc định của user location
        if annotation is MKUserLocation {
            return nil
        }

        let identifier = "CustomPin"

        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.image = UIImage(named: "loc_red") // thay bằng icon hình cờ bạn muốn
        } else {
            annotationView?.annotation = annotation
        }

        return annotationView
    }
}
