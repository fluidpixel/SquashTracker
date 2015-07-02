//
//  WorkoutTableViewController.swift
//  SquashTracker
//
//  Created by Stuart Varrall on 01/07/2015.
//  Copyright © 2015 Stuart Varrall. All rights reserved.
//

import UIKit
import HealthKit

class WorkoutTableViewController: UITableViewController {

    var workouts: [HKWorkout]?
    var selectedWorkout:HKWorkout?
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func viewWillAppear(animated: Bool) {
        Workouts().readOtherWorkOuts { (results, error) -> Void in
            
            self.workouts = results
            
            dispatch_async(dispatch_get_main_queue(), {
                self.tableView.reloadData()
            })
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let workouts = workouts {
            return workouts.count
        } else {
            return 0
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let workout = workouts![indexPath.row]
        
        let cell = tableView.dequeueReusableCellWithIdentifier("workout cell", forIndexPath: indexPath) as UITableViewCell
        
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.ShortStyle
        formatter.timeStyle = NSDateFormatterStyle.ShortStyle
        
        if workout.workoutActivityType == HKWorkoutActivityType.Squash {
            cell.textLabel?.text = "\(formatter.stringFromDate(workout.startDate)) SQUASH"
        } else {
            cell.textLabel?.text = "\(formatter.stringFromDate(workout.startDate))"
        }
        
        cell.detailTextLabel?.text = "\(Int(workout.duration/60)) minutes"
        
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        selectedWorkout = workouts![indexPath.row]
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        //any pre-segue stuff goes in here
        if let cell =  sender as? UITableViewCell {
            if let indexPath = tableView.indexPathForCell(cell) {
                if let pc = segue.destinationViewController as? ViewController {
                    pc.latestWorkout = workouts![indexPath.row]
                }
            }
        }
        
    }
}
