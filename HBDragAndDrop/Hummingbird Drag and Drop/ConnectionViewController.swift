//
//  ConnectionViewController.swift
//  HummingbirdLibraryTest
//
//  Created by birdbrain on 6/1/15.
//  Copyright (c) 2015 Birdbrain Technologies LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

class ConnectionViewController: UITableViewController {
    
    let sharedBluetoothDiscovery = BluetoothDiscovery.getBLEDiscovery()
    var items = [String: CBPeripheral]()
    var refreshTimer: Timer = Timer()
    var skipping = false
    
    override func viewDidLoad(){
        super.viewDidLoad()
        self.items = sharedBluetoothDiscovery.getDiscovered()
        title = "BLE Devices"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.refresh, target: self, action: #selector(ConnectionViewController.restart))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.fastForward, target: self, action: #selector(ConnectionViewController.skip))
        navigationController!.setNavigationBarHidden(false, animated:true)
        self.tableView.allowsSelection = false
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cellIdentifier")
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.allowsSelection = true
        refreshTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ConnectionViewController.refresh), userInfo: nil, repeats: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        refreshTimer.invalidate()
        if (skipping == false) {
        let array = Array(self.items.values.lazy)
        let cell = sender as! UITableViewCell
        let name = (cell.textLabel?.text)!
        let index = self.tableView.indexPath(for: cell)
        let i = index!.row
        let item = array[i]
        let hbServe = HummingbirdServices()
        sharedBluetoothDiscovery.connectToPeripheral(item, name: name)
        let mainView = segue.destination as! ViewController
        hbServe.attachToDevice(name)
        mainView.hbServes[name] = hbServe
        }
    }
    
    func refresh(){
        items = sharedBluetoothDiscovery.getDiscovered()
        self.tableView.reloadData()
    }
    func skip() {
        skipping = true
        performSegue(withIdentifier: "ShowMainSegue", sender: self)
    }
    func restart(){
        sharedBluetoothDiscovery.restartScan()
        refresh()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let keys = Array(items.keys.lazy)
        let cell: UITableViewCell = (tableView.dequeueReusableCell(withIdentifier: "cellIdentifier", for: indexPath) )
        cell.textLabel?.text = keys[indexPath.row]
        cell.updateConstraintsIfNeeded()
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell: UITableViewCell = self.tableView.cellForRow(at: indexPath)!
        performSegue(withIdentifier: "ShowMainSegue", sender: cell)
    }
    
    
}
