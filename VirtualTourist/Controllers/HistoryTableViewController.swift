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
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = { () -> NSFetchedResultsController<NSFetchRequestResult> in
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Update")
        request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
        
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
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        
        // Create the right bar button item
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear History", style: .plain, target: self, action: #selector(clearAll))
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! HistoryTableViewCell
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        let fetchedObjects = fetchedResultsController.fetchedObjects as! [Update]
        let update = fetchedObjects[indexPath.row]
        
        cell.changeType.text = update.updateType
        cell.descriptionLabel.text = "\(update.numberOfItems) \(update.updateDescription)"
        cell.dateOfChange.text = formatter.string(from: update.dateCreated)
        
        return cell
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            let fetchedObjects = fetchedResultsController.fetchedObjects as! [Update]
            let update = fetchedObjects[indexPath.row]
            
            CoreDataStackManager.sharedInstance().managedObjectContext.delete(update)
        default: break
        }
    }
    
    // MARK: - NSFetchedResultsControllerDelegate delegate
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert: tableView.insertRows(at: [IndexPath(item: 0, section: 0)], with: .fade)
        case .delete: tableView.deleteRows(at: [indexPath!], with: .fade)
        default: break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    // MARK: - Selectors
    @objc func clearAll() {
        let fetchedObjects = fetchedResultsController.fetchedObjects as! [Update]
        for update in fetchedObjects {
            CoreDataStackManager.sharedInstance().managedObjectContext.delete(update)
        }
        CoreDataStackManager.sharedInstance().saveContext()
    }
}
