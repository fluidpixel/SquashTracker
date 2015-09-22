//
//  ViewController.swift
//  SquashTracker
//
//  Created by Stuart Varrall on 01/07/2015.
//  Copyright © 2015 Stuart Varrall. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    @IBOutlet weak var caloriesBurned: UILabel!
    @IBOutlet weak var stepsLabel: UILabel!
    @IBOutlet weak var heartRateLabel: UILabel!
    @IBOutlet weak var minHeartRateLabel: UILabel!
    @IBOutlet weak var maxHeartRateLabel: UILabel!
    
    @IBOutlet weak var EditButton: UIBarButtonItem!
    @IBOutlet weak var chartScrollView: UIScrollView! {
        didSet {
            chartScrollView.delegate = self
        }
    }
    
    @IBOutlet weak var chartView: UIView!
    private var charts = [Chart]() // arc
    private var chart: Chart? // arc
    private var data = [(dataPoints:[Double], type:String, duration:NSTimeInterval)]()
    
    @IBOutlet weak var pageControl: UIPageControl! {
        didSet {
            pageControl.numberOfPages = 0
        }
    }
    
    var latestWorkout: HKWorkout?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if latestWorkout?.sourceRevision.source.name == "SquashTracker" {
            EditButton.title = "Delete"
            EditButton.tintColor = UIColor.redColor()
        } else {
            EditButton.title = "Edit"
            EditButton.tintColor = self.view.tintColor
        }
        
            updateWorkout()
    }

    @IBAction func editAction(sender: UIBarButtonItem) {
        if latestWorkout?.workoutActivityType != HKWorkoutActivityType.Squash {
            
            Workouts().changeWorkoutType(latestWorkout!, newType: HKWorkoutActivityType.Squash)  {(success:Bool, error:NSError?)  in
                if success {
                    print("removed")
                } else {
                    print(error?.localizedDescription)
                }
            }
        } else {
            let alert = UIAlertController(title: "Remove Workout?", message: "This will perminately delete this squash match", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: {(alert:UIAlertAction) in
                
                Workouts().removeWorkout(self.latestWorkout!) {(success:Bool, error:NSError?)  in
                        if success {
                            print("removed")
                            dispatch_async(dispatch_get_main_queue(), {
                             self.navigationController?.popViewControllerAnimated(true)
                            })
                            
                        } else {
                            print(error?.localizedDescription)
                        }
                    }
                }))
                
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Cancel, handler: nil))
            
            presentViewController(alert, animated:true, completion: nil)
            
        }
        
    }
    
    @IBAction func pageChanged(sender: UIPageControl) {
        let offset = CGFloat(pageControl.currentPage) * chartScrollView.frame.size.width
        chartScrollView.setContentOffset(CGPointMake(offset, 0), animated: true)
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        let pageNumber = (chartScrollView.contentOffset.x / chartScrollView.frame.size.width)
        pageControl.currentPage = Int(pageNumber)
    }
    
    func updateWorkout(){
        if let workout = latestWorkout {
            
            Workouts().totalStepsDuringWorkout(workout)  {
                (result: Double) in
                dispatch_async(dispatch_get_main_queue(), {
                    self.stepsLabel.text = "\(Int(result)) steps"
                })
            }

            Workouts().heartRateForWorkout(workout, completion: { (average, min, max) -> Void in
                dispatch_async(dispatch_get_main_queue(), {
                    self.heartRateLabel.text = "Average: \(Int(average))"
                    self.minHeartRateLabel.text = "Min: \(Int(min))"
                    self.maxHeartRateLabel.text = "Max: \(Int(max))"
                })
            })
            
            Workouts().detailForWorkout(workout, type: HKQuantityTypeIdentifierStepCount)  {(result: [Double]) in
                if result.count > 0 {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.pageControl.numberOfPages++
                        self.data.append((result, type:HKQuantityTypeIdentifierStepCount, duration:workout.duration/60))
                        self.addChartView(result, type:HKQuantityTypeIdentifierStepCount, duration:workout.duration/60)
                    })
                    
                }
            }
            
            Workouts().detailForWorkout(workout, type: HKQuantityTypeIdentifierHeartRate)  {(result: [Double]) in
                if result.count > 0 {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.pageControl.numberOfPages++
                        self.data.append((result, type:HKQuantityTypeIdentifierHeartRate, duration:workout.duration/60))
                        self.addChartView(result, type:HKQuantityTypeIdentifierHeartRate, duration:workout.duration/60)
                    })
                    
                }
            }
            
            let formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.ShortStyle
            formatter.timeStyle = NSDateFormatterStyle.ShortStyle
            
            startTimeLabel.text = "\(formatter.stringFromDate(workout.startDate))"
            lengthLabel.text = "\(Int(workout.duration/60)) minutes"
            caloriesBurned.text = "\(workout.totalEnergyBurned!)"
        }
    }
    
    func addChartView(dataPoints:[Double], type:String, duration:NSTimeInterval){
        // map model data to chart points
        
        var chartPoints = [ChartPoint]()
        
        var maxValue = 0
        
        let xInterval = duration/Double(dataPoints.count)
        
        for (index, data) in dataPoints.enumerate() {
            
            if Int(data) > maxValue {
                maxValue = Int(data)
            }
            
            chartPoints.append(ChartPoint(x: ChartAxisValue(scalar: CGFloat(xInterval*Double(index))), y: ChartAxisValue(scalar: CGFloat(data))))
        }
        
        let labelSettings = ChartLabelSettings(font: ExamplesDefaults.labelFont)
       
        let interval = Int(maxValue / 10)
        let total = maxValue + interval
        
        let xValues = Array(0.stride(through: Int(duration), by: 5)).map {ChartAxisValueInt($0, labelSettings: labelSettings)}
        let yValues = Array(0.stride(through: total, by: interval)).map {ChartAxisValueInt($0, labelSettings: labelSettings)}
        
        var xLabel = "Minutes"
        var yLabel = "Steps/m"
        var offset = 0
        
        if type == HKQuantityTypeIdentifierHeartRate {
            xLabel = "Minutes"
            yLabel = "BPM"
            offset = 1
        }
        
        // create axis models with axis values and axis title
        let xModel = ChartAxisModel(axisValues: xValues, axisTitleLabel: ChartAxisLabel(text: xLabel, settings: labelSettings))
        let yModel = ChartAxisModel(axisValues: yValues, axisTitleLabel: ChartAxisLabel(text: yLabel, settings: labelSettings))
        
        let chartFrame = CGRectOffset(chartView.bounds, CGFloat(offset)*chartView.frame.size.width, 0)
        
        // generate axes layers and calculate chart inner frame, based on the axis models
        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: ExamplesDefaults.chartSettings, chartFrame: chartFrame, xModel: xModel, yModel: yModel)
        let (xAxis, yAxis, innerFrame) = (coordsSpace.xAxis, coordsSpace.yAxis, coordsSpace.chartInnerFrame)
        
        // create layer with guidelines
        let guidelinesLayerSettings = ChartGuideLinesDottedLayerSettings(linesColor: UIColor.blackColor(), linesWidth: ExamplesDefaults.guidelinesWidth)
        let guidelinesLayer = ChartGuideLinesDottedLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, settings: guidelinesLayerSettings)
        
        let barViewGenerator = {(chartPointModel: ChartPointLayerModel, layer: ChartPointsViewsLayer, chart: Chart) -> UIView? in
            let bottomLeft = CGPointMake(layer.innerFrame.origin.x, layer.innerFrame.origin.y + layer.innerFrame.height)
            
            let barWidth: CGFloat = Env.iPad ? 60 : 2
            
            let (p1, p2): (CGPoint, CGPoint) = {
                    return (CGPointMake(chartPointModel.screenLoc.x, bottomLeft.y), CGPointMake(chartPointModel.screenLoc.x, chartPointModel.screenLoc.y))
                }()
            
            var colour = UIColor.blueColor()
            if offset == 1 {
                colour = UIColor.redColor()
            }
            return ChartPointViewBar(p1: p1, p2: p2, width: barWidth, bgColor: colour.colorWithAlphaComponent(0.6))
        }
        
        // create layer that uses viewGenerator to display chartpoints
        let chartPointsLayer = ChartPointsViewsLayer(xAxis: xAxis, yAxis: yAxis, innerFrame: innerFrame, chartPoints: chartPoints, viewGenerator: barViewGenerator)
        
        // create chart instance with frame and layers
        let chart = Chart(
            frame: chartFrame,
            layers: [
                coordsSpace.xAxis,
                coordsSpace.yAxis,
                guidelinesLayer,
                chartPointsLayer
            ]
        )
        
        self.chartScrollView.addSubview(chart.view)
        self.chartScrollView.contentSize = CGSizeMake(self.chartView.bounds.size.width*CGFloat(pageControl.numberOfPages), 0)
//        self.chart = chart
        chart.view.tag = offset
        self.charts.append(chart)
    }
    
//    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
//        for subview in self.chartScrollView.subviews {
//            if let chart = subview as? ChartBaseView {
//                chart.frame = CGRectOffset(chartView.bounds, CGFloat(chart.tag)*chartView.frame.size.width, 0)
//            }
//        }
//    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        coordinator.animateAlongsideTransition({ (UIViewControllerTransitionCoordinatorContext) -> Void in
            
//            let oldCharts = self.charts
            for chart in self.charts {
                chart.clearView()
            }
            
            self.charts.removeAll()
            self.chartScrollView.subviews.forEach { $0.removeFromSuperview() }
            
            for chartData in self.data {
                self.addChartView(chartData.0, type: chartData.1, duration: chartData.2)
            }
            
            let offset = CGFloat(self.pageControl.currentPage) * size.width
            self.chartScrollView.setContentOffset(CGPointMake(offset, 0), animated: true)
            
//            for chart in oldCharts {
//                let frame = CGRectOffset(CGRectMake(0, 0, size.width, size.height), CGFloat(chart.view.tag)*size.width, 0)
//                chart.clearView()
//                let newChart = Chart(frame: frame, layers: chart.layers)
//                newChart.view.tag = chart.view.tag
//                self.chartScrollView.addSubview(newChart.view)
//                self.charts.append(newChart)
//            }
//            
//            self.chartScrollView.contentSize = CGSizeMake(self.chartView.bounds.size.width*CGFloat(self.pageControl.numberOfPages), 0)
            
        }, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
                print("rotation completed")
        })
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    }
}

