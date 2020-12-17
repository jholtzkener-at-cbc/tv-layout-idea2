//
//  ViewController.swift
//  tvTest
//
//  Created by cbcmusic on 2020-12-15.
//

import UIKit

enum Station: String {
    case r1 = "Radio One"
    case cbcmusic = "CBC Music"
}

class ViewController:  UIViewController {
    @IBOutlet weak var tableView: UITableView!
    var isDisplayingTable = true
    var swipeRight: UISwipeGestureRecognizer!
    var swipeLeft: UISwipeGestureRecognizer!
    var station: Station!
    
    @IBOutlet weak var bigButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        prepTableView()
        addSwipes()
        hideTable(animated: false)
    }
    
    
    func setUp(station: Station) {
        self.station = station
        bigButton.setTitle(station.rawValue, for: .normal)
    }
    
    func addSwipes() {
        swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(hideTable))
        swipeRight.direction = .right
        swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(showTable))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        bigButton.addGestureRecognizer(swipeLeft)
        tableView.addGestureRecognizer(swipeRight)
    }
    
    @objc func hideTable(animated: Bool = true) {
        UIView.animate(withDuration: animated ? 0.5 : 0,
                       animations: {
                        UIView.animate(withDuration: 0.5) {
                            self.tableView.frame = CGRect(x: self.tableView.frame.width * -1.5, y: 0, width: self.tableView.frame.width, height: self.tableView.frame.height)
                        }
                       }) {_ in
            self.tableView.isUserInteractionEnabled = false
        }
    }
    
    @objc func showTable() {
        self.tableView.isHidden = false
        self.tableView.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.5,
                       animations: {
                        UIView.animate(withDuration: 0.5) {
                            self.tableView.frame = CGRect(x: 0, y: 0, width: self.tableView.frame.width, height: self.tableView.frame.height)
                        }
                       })
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func prepTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .black
        view.bringSubviewToFront(tableView)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        10
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "myCell")!
        cell.textLabel?.text = "whitehorse"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        hideTable()
    }
}
