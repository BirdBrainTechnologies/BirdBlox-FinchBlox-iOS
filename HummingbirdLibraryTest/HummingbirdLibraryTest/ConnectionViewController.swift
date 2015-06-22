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
import HummingbirdLibrary

class ConnectionViewController: UITableViewController{
    
    var hbServe = HummingbirdServices()
    var items = [String: CBPeripheral]()
    var refreshTimer: NSTimer = NSTimer()
    
    override func viewDidLoad(){
        super.viewDidLoad()
        self.items = hbServe.getAvailiableDevices()
        title = "BLE Devices"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: "restart")
        self.tableView.allowsSelection = false
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cellIdentifier")
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.allowsSelection = true
        refreshTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("refresh"), userInfo: nil, repeats: true)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        refreshTimer.invalidate()
        let cell = sender as! UITableViewCell
        let index = self.tableView.indexPathForCell(cell)
        let i = index!.row
        let item = self.items.values.array[i]
        hbServe.connectToDevice(item)
        let mainView = segue.destinationViewController as! MainViewController
        mainView.hbServe = hbServe
    }
    
    func refresh(){
        items = hbServe.getAvailiableDevices()
        self.tableView.reloadData()
    }
    func restart(){
        hbServe.restartScan()
        refresh()
        
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell: UITableViewCell = (tableView.dequeueReusableCellWithIdentifier("cellIdentifier", forIndexPath: indexPath) as? UITableViewCell)!
        
        cell.textLabel?.text = items.keys.array[indexPath.row]
        cell.updateConstraintsIfNeeded()
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell: UITableViewCell = self.tableView.cellForRowAtIndexPath(indexPath)!
        performSegueWithIdentifier("ShowMainSegue", sender: cell)
    }
    
    
}