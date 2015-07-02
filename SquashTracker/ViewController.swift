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
    
    @IBOutlet weak var chartScrollView: UIScrollView! {
        didSet {
            chartScrollView.delegate = self
        }
    }
    
    @IBOutlet weak var chartView: UIView!
    private var charts: [Chart]? // arc
    private var chart: Chart? // arc
    
    @IBOutlet weak var pageControl: UIPageControl! {
        didSet {
            pageControl.numberOfPages = 0
        }
    }
    
    var latestWorkout: HKWorkout?
    
    override func viewDidLoad() {
        super.viewDidLoad()
            updateWorkout()
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
            
            Workouts().averageHeartRateForWorkout(workout)  {
                (result: Double) in
                dispatch_async(dispatch_get_main_queue(), {
                    self.heartRateLabel.text = "\(Int(result)) Average BPM"
                })
            }
            
            Workouts().detailForWorkout(workout, type: HKQuantityTypeIdentifierStepCount)  {(result: [Double]) in
                if result.count > 0 {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.addChartView(result, offset:self.pageControl.numberOfPages)
                        self.pageControl.numberOfPages += 1
                    })
                    
                }
            }
            
            Workouts().detailForWorkout(workout, type: HKQuantityTypeIdentifierHeartRate)  {(result: [Double]) in
                if result.count > 0 {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.addChartView(result, offset:self.pageControl.numberOfPages)
                        self.pageControl.numberOfPages += 1
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
    
    func addChartView(dataPoints:[Double], offset:Int){
        // map model data to chart points
        
        var chartPoints = [ChartPoint]()
        
        var maxValue = 0
        
        for (index, step) in dataPoints.enumerate() {
            
            if Int(step) > maxValue {
                maxValue = Int(step)
            }
            
            chartPoints.append(ChartPoint(x: ChartAxisValue(scalar: CGFloat(index+1)), y: ChartAxisValue(scalar: CGFloat(step))))
        }
        
        let labelSettings = ChartLabelSettings(font: ExamplesDefaults.labelFont)
        
        
        let xValues = Array(stride(from: 0, through: dataPoints.count, by: max(1,Int(dataPoints.count / 10)))).map {ChartAxisValueInt($0, labelSettings: labelSettings)}
        let yValues = Array(stride(from: 0, through: maxValue + Int(maxValue / 10), by: Int(maxValue / 10))).map {ChartAxisValueInt($0, labelSettings: labelSettings)}
        
        var xLabel = "Minutes"
        var yLabel = "Steps/m"
        
        if offset == 1 {
            xLabel = "Minutes"
            yLabel = "BPM"
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
        
        // view generator - this is a function that creates a view for each chartpoint
//        let viewGenerator = {(chartPointModel: ChartPointLayerModel, layer: ChartPointsViewsLayer, chart: Chart) -> UIView? in
//            let viewSize: CGFloat = Env.iPad ? 20 : 10
//            let center = chartPointModel.screenLoc
//            let label = UILabel(frame: CGRectMake(center.x - viewSize / 2, center.y - viewSize / 2, viewSize, viewSize))
//            label.backgroundColor = UIColor.greenColor()
//            label.textAlignment = NSTextAlignment.Center
//            label.text = "\(chartPointModel.chartPoint.y.text)"
//            label.font = ExamplesDefaults.labelFont
//            return label
//        }
        
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
        self.chartScrollView.contentSize = CGSizeMake(chartFrame.size.width*CGFloat(offset+1), 0)
        self.chart = chart
//        self.charts?.append(chart)
    }
}

