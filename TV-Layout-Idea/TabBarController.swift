//
//  TabBarController.swift
//  tvTest
//
//  Created by cbcmusic on 2020-12-15.
//

import UIKit

class TabBarController: UITabBarController {
    var vc1: ViewController!
    var vc2: ViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myInit()
    }

    func myInit() {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        vc1 = sb.instantiateViewController(identifier: "vc")
        vc2 = sb.instantiateViewController(identifier: "vc")
        _ = vc1.view
        vc1.setUp(station: .r1)
        _ = vc2.view
        vc2.setUp(station: .cbcmusic)
        vc1.tabBarItem = UITabBarItem(title: "CBC Radio One", image: nil, tag: 0)
        vc2.tabBarItem = UITabBarItem(title: "CBC Music", image: nil, tag: 0)
        let tabBarList = [vc1!, vc2!]
        viewControllers = tabBarList
    }
}
