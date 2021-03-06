//
//  CompanyTableViewController.swift
//  CocoaHeadsNL
//
//  Created by Bart Hoffman on 30/05/15.
//  Copyright (c) 2015 Stichting CocoaheadsNL. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

class CompanyTableViewController: UITableViewController {
    
    var sortedArray = NSMutableArray()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewWillAppear(animated: Bool) {
        self.fetchCompanies()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backItem = UIBarButtonItem(title: "Companies", style: .Plain, target: nil, action: nil)
        self.navigationItem.backBarButtonItem = backItem
    }
    
    //MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowCompanies" {
            if let indexPath = self.tableView.indexPathForCell(sender as! UITableViewCell) {
                
                let detailViewController = segue.destinationViewController as? LocatedCompaniesViewController
                detailViewController?.companyDict = sortedArray[indexPath.row] as! NSDictionary
            }
        }
    }
    
    //MARK: - UITablewViewDelegate
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedArray.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "All Companies"
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let labelRect = CGRect(x: 15, y: 2, width: 300, height: 18)
        let label = UILabel(frame: labelRect)
        label.font = UIFont.boldSystemFontOfSize(15)

        label.text = tableView.dataSource!.tableView!(tableView, titleForHeaderInSection: section)

        let viewRect = CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.sectionHeaderHeight)
        let view = UIView(frame: viewRect)
        view.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1)
        view.addSubview(label)

        return view
    }


    //MARK: - UITableViewDataSource
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("companyTableViewCell", forIndexPath: indexPath) 
        
        
        cell.textLabel!.text = sortedArray[indexPath.row].valueForKey("place") as? StringLiteralType
        
        
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 44
    }
    
    //MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier("ShowCompanies", sender: tableView.cellForRowAtIndexPath(indexPath))
    }
    
    //MARK: - Notifications
    
    func subscribe() {
        let publicDB = CKContainer.defaultContainer().publicCloudDatabase
        
        let subscription = CKSubscription(
            recordType: "Companies",
            predicate: NSPredicate(value: true),
            options: .FiresOnRecordCreation
        )
        
        let info = CKNotificationInfo()
        
        info.alertBody = "A new company has been added!"
        info.shouldBadge = true
        
        subscription.notificationInfo = info
        
        publicDB.saveSubscription(subscription) { record, error in }
    }
    
    //MARK: - fetching Cloudkit
    
    func fetchCompanies() {
        
        let pred = NSPredicate(value: true)
        let sort = NSSortDescriptor(key: "name", ascending: false)
        let query = CKQuery(recordType: "Companies", predicate: pred)
        query.sortDescriptors = [sort]
        
        let operation = CKQueryOperation(query: query)
        operation.qualityOfService = .UserInteractive
        
        var CKCompanies = [Company]()
        
        operation.recordFetchedBlock = { (record) in
            let company = Company()
            
            company.recordID = record.recordID as CKRecordID?
            company.name = record["name"] as? String
            company.place = record["place"] as? String
            company.streetAddress = record["streetAddress"] as? String
            company.website = record["website"] as? String
            company.zipCode = record["zipCode"] as? String
            company.companyDescription = record["companyDescription"] as? String
            company.emailAddress = record["emailAddress"] as? String
            company.location = record["location"] as? CLLocation
            company.logo = record["logo"] as? CKAsset
            company.hasApps = record["hasApps"] as! Bool
            company.smallLogo = record["smallLogo"] as? CKAsset
            
            CKCompanies.append(company)
        }
        
        operation.queryCompletionBlock = { [unowned self] (cursor, error) in
            dispatch_async(dispatch_get_main_queue()) {
                if error == nil {
                    
                    self.sortedArray.removeAllObjects()
                    
                    var locationSet = Set<String>()
                    
                    for company in CKCompanies {
                        
                        if let location = company.place  {
                            
                            if !locationSet.contains(location) {
                                locationSet.insert(location)
                            }
                        }
                    }
                    
                    let groupedArray = locationSet.sort()
                    
                    for group in groupedArray {
                        let companyArray = NSMutableArray()
                        let locationDict = NSMutableDictionary()
                        locationDict.setValue(group, forKey: "place")
                        
                        for company in CKCompanies {
                            
                            if let loc = company.place {
                                if loc == locationDict.valueForKey("place") as? StringLiteralType {
                                    companyArray.addObject(company)
                                }
                            }
                            
                        }
                        locationDict.setValue(companyArray, forKey: "company")
                        self.sortedArray.addObject(locationDict)
                    }

                    self.tableView.reloadData()
                    
                } else {
                    let ac = UIAlertController(title: "Fetch failed", message: "There was a problem fetching the list of companies; please try again: \(error!.localizedDescription)", preferredStyle: .Alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                    self.presentViewController(ac, animated: true, completion: nil)
                }
            }
        }
        
        CKContainer.defaultContainer().publicCloudDatabase.addOperation(operation)
        
    }
}
