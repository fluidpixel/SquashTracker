//
//  WorkoutModel.swift
//  SquashTracker
//
//  Created by Stuart Varrall on 01/07/2015.
//  Copyright © 2015 Stuart Varrall. All rights reserved.
//

import Foundation
import HealthKit

class Workouts {

    let healthStore: HKHealthStore? = {
        if HKHealthStore.isHealthDataAvailable() {
            return HKHealthStore()
        } else {
            return nil
        }
        }()
    
    func permission() {

        let heartRate = HKQuantityType.quantityTypeForIdentifier(
            HKQuantityTypeIdentifierHeartRate)!
        let stepCount = HKQuantityType.quantityTypeForIdentifier(
            HKQuantityTypeIdentifierStepCount)!
        let distance = HKQuantityType.quantityTypeForIdentifier(
            HKQuantityTypeIdentifierDistanceWalkingRunning)!
        let workout = HKWorkoutType.workoutType()
        
        let dataTypesToRead: Set<HKSampleType> = [heartRate, stepCount, distance,workout]
//        let dataTypesToWrite = NSSet(object: stepsCount)
        
        healthStore?.requestAuthorizationToShareTypes(nil,
            readTypes: dataTypesToRead,
            completion: {succeeded, error in
                
                if succeeded && error == nil{
                    print("Successfully received authorization")
                } else {
                    if let theError = error{
                        print("Error occurred = \(theError)")
                    }
                }
        })
        
    }
    
    func readOtherWorkOuts(completion: (([HKWorkout]?, NSError?) -> Void)!) {
        
        let predicateOther =  HKQuery.predicateForWorkoutsWithWorkoutActivityType(HKWorkoutActivityType.Other)
        let predicateSquash =   HKQuery.predicateForWorkoutsWithWorkoutActivityType(HKWorkoutActivityType.Squash)
        let predicate = NSCompoundPredicate(type: NSCompoundPredicateType.OrPredicateType, subpredicates: [predicateOther, predicateSquash])
        
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        let sampleQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: predicate, limit: 0, sortDescriptors: [sortDescriptor])
            { (sampleQuery, results, error ) -> Void in
                
                if let queryError = error {
                    print( "There was an error while reading the samples: \(queryError.localizedDescription)")
                }
                completion(results as? [HKWorkout],error)
        }
        
        healthStore?.executeQuery(sampleQuery)
        
    }
    
    func totalStepsDuringWorkout (workout:HKWorkout, completion: (result: Double) -> Void) {
        
        let stepsCount = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!
        let predicate = HKQuery.predicateForSamplesWithStartDate(workout.startDate, endDate: workout.endDate, options: [HKQueryOptions.StrictStartDate, HKQueryOptions.StrictEndDate])
    
        let statsQuery = HKStatisticsQuery(quantityType: stepsCount, quantitySamplePredicate: predicate, options: HKStatisticsOptions.CumulativeSum) {(query:HKStatisticsQuery, statistics:HKStatistics?, error:NSError?) -> Void in
            if error != nil {
                print(error)
            }
            
            if let sum = statistics?.sumQuantity() {
                completion(result: sum.doubleValueForUnit(HKUnit.countUnit()))
            } else {
                completion(result: 0)
            }
        }
         healthStore?.executeQuery(statsQuery)
    }
    
    func averageHeartRateForWorkout (workout:HKWorkout, completion: (result: Double) -> Void) {
        
        let heartRate = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
        let predicate = HKQuery.predicateForSamplesWithStartDate(workout.startDate, endDate: workout.endDate, options: [HKQueryOptions.StrictStartDate, HKQueryOptions.StrictEndDate])
        
        let statsQuery = HKStatisticsQuery(quantityType: heartRate, quantitySamplePredicate: predicate, options: HKStatisticsOptions.DiscreteAverage) {(query:HKStatisticsQuery, statistics:HKStatistics?, error:NSError?) -> Void in
            if error != nil {
                print(error)
            }
            
            if let sum = statistics?.averageQuantity() {
                completion(result: sum.doubleValueForUnit(HKUnit(fromString: "count/min")))
            } else {
                completion(result: 0)
            }
        }
        healthStore?.executeQuery(statsQuery)
    }
    
    func detailForWorkout(workout:HKWorkout, type:String, completion:(result:[Double]) -> Void) {
        
        let stepsCount = HKQuantityType.quantityTypeForIdentifier(type)!
        let predicate = HKQuery.predicateForSamplesWithStartDate(workout.startDate, endDate: workout.endDate, options: [HKQueryOptions.StrictStartDate, HKQueryOptions.StrictEndDate])
        
        let interval = NSDateComponents()
        interval.second = 30
        
        let anchorDate = NSCalendar.currentCalendar().startOfDayForDate(workout.startDate)
        var statOptions = HKStatisticsOptions.CumulativeSum
        
        if type == HKQuantityTypeIdentifierHeartRate {
            statOptions = HKStatisticsOptions.DiscreteAverage
        }
        
        let statsCollectionQuery = HKStatisticsCollectionQuery(quantityType: stepsCount, quantitySamplePredicate: predicate, options: statOptions, anchorDate: anchorDate, intervalComponents: interval)
        
        statsCollectionQuery.initialResultsHandler = {(query:HKStatisticsCollectionQuery, collection:HKStatisticsCollection?, error:NSError?) -> Void in
            if error != nil {
                print(error)
            }
            
            var stepArray = [Double]()
            
            if let results = collection?.statistics() {
                for step in results {
                     if let sum = step.sumQuantity() {
                        stepArray.append(sum.doubleValueForUnit(HKUnit.countUnit()))
                     } else if let average = step.averageQuantity() {
                        stepArray.append(average.doubleValueForUnit(HKUnit(fromString: "count/min")))
                    }
                }
                completion(result: stepArray)
            } else {
                completion(result: [])
            }
            
        }

        healthStore?.executeQuery(statsCollectionQuery)
    }
}
