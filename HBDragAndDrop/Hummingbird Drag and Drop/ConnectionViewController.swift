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
    var refreshTimer: NSTimer = NSTimer()
    
    override func viewDidLoad(){
        super.viewDidLoad()
        self.items = sharedBluetoothDiscovery.getDiscovered()
        title = "BLE Devices"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: #selector(ConnectionViewController.restart))
        navigationController!.setNavigationBarHidden(false, animated:true)
        self.tableView.allowsSelection = false
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cellIdentifier")
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.allowsSelection = true
        refreshTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(ConnectionViewController.refresh), userInfo: nil, repeats: true)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        refreshTimer.invalidate()
        let array = Array(self.items.values.lazy)
        let cell = sender as! UITableViewCell
        let name = (cell.textLabel?.text)!
        let index = self.tableView.indexPathForCell(cell)
        let i = index!.row
        let item = array[i]
        let hbServe = HummingbirdServices()
        sharedBluetoothDiscovery.connectToPeripheral(item, name: name)
        let mainView = segue.destinationViewController as! ViewController
        hbServe.attachToDevice(name)
        mainView.hbServes[name] = hbServe
    }
    
    func refresh(){
        items = sharedBluetoothDiscovery.getDiscovered()
        self.tableView.reloadData()
    }
    func restart(){
        sharedBluetoothDiscovery.restartScan()
        refresh()
        
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let keys = Array(items.keys.lazy)
        let cell: UITableViewCell = (tableView.dequeueReusableCellWithIdentifier("cellIdentifier", forIndexPath: indexPath) )
        cell.textLabel?.text = keys[indexPath.row]
        cell.updateConstraintsIfNeeded()
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell: UITableViewCell = self.tableView.cellForRowAtIndexPath(indexPath)!
        performSegueWithIdentifier("ShowMainSegue", sender: cell)
    }
    
    
}