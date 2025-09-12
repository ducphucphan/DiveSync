//
//  SearchDiveSpotsResultsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/12/25.
//

import UIKit
import MapKit

protocol SearchDiveSpotsResultsDelegate: AnyObject {
    func didSelectSearchResult(_ result: MKLocalSearchCompletion)
}

class SearchDiveSpotsResultsViewController: UITableViewController, MKLocalSearchCompleterDelegate {
    
    weak var delegate: SearchDiveSpotsResultsDelegate?
    
    var completer = MKLocalSearchCompleter()
    var results = [MKLocalSearchCompletion]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        completer.delegate = self
    }
    
    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let result = results[indexPath.row]
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subtitle
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = results[indexPath.row]
        delegate?.didSelectSearchResult(selected)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

