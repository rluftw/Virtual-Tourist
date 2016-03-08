//
//  HistoryTableViewController.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/8/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import UIKit
import CoreData

class HistoryTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {

    // MARK: - Core Data
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let request = NSFetchRequest(entityName: "Update")
        request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: true)]
        
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    }()
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // MARK: - Viewcontroller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the fetchresultcontrollers delegate to self
        fetchedResultsController.delegate = self
        
        // Fetch the results
        do {
            try fetchedResultsController.performFetch()
        } catch { }
        
        // Don't want the extra space below the table
        tableView.tableFooterView = UIView(frame: CGRectZero)
    }

    // MARK: - Table view data source

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("HistoryCell", forIndexPath: indexPath) as! HistoryTableViewCell
        
        let formatter = NSDateFormatter()
        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .MediumStyle
        
        // Reverse the fetched results and place it in
        let fetchedObjects = fetchedResultsController.fetchedObjects as! [Update]
        let reversedFetchedObjects: [Update] = fetchedObjects.reverse()
        let update = reversedFetchedObjects[indexPath.row]
        
        cell.changeType.text = update.updateType
        cell.descriptionLabel.text = "\(update.numberOfItems) \(update.updateDescription)"
        cell.dateOfChange.text = formatter.stringFromDate(update.dateCreated)
        
        return cell
    }
    
    // MARK: - NSFetchedResultsControllerDelegate delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert: tableView.insertRowsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)], withRowAnimation: .Fade)
        default: break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
}
