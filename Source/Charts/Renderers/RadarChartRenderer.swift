//
//  RadarChartRenderer.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

open class RadarChartRenderer: LineRadarRenderer
{
    private lazy var accessibilityXLabels: [String] = {
        guard let chart = chart else { return [] }
        guard let formatter = chart.xAxis.valueFormatter else { return [] }

        let maxEntryCount = chart.data?.maxEntryCountSet?.entryCount ?? 0
        return stride(from: 0, to: maxEntryCount, by: 1).map {
            formatter.stringForValue(Double($0), axis: chart.xAxis)
        }
    }()

    @objc open weak var chart: RadarChartView?

    @objc public init(chart: RadarChartView, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.chart = chart
    }
    
    open override func drawData(context: CGContext)
    {
        guard let chart = chart,
              let radarData = chart.data as? RadarChartData else
        {
            return
        }
        
        let mostEntries = radarData.maxEntryCountSet?.entryCount ?? 0

        // If we redraw the data, remove and repopulate accessible elements to update label values and frames
        self.accessibleChartElements.removeAll()

        // Make the chart header the first element in the accessible elements array
        let element = createAccessibleHeader(usingChart: chart,
                                             andData: radarData,
                                             withDefaultDescription: "Radar Chart")
        self.accessibleChartElements.append(element)

        for case let set as RadarChartDataSetProtocol in (radarData as ChartData) where set.isVisible
        {
            drawDataSet(context: context, dataSet: set, mostEntries: mostEntries)
        }
    }
    
    /// Draws the RadarDataSet
    ///
    /// - Parameters:
    ///   - context:
    ///   - dataSet:
    ///   - mostEntries: the entry count of the dataset with the most entries
    internal func drawDataSet(context: CGContext, dataSet: RadarChartDataSetProtocol, mostEntries: Int)
    {
        guard let chart = chart else { return }
        
        context.saveGState()
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        let sliceangle = chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = chart.factor
        
        let center = chart.centerOffsets
        let entryCount = dataSet.entryCount
        let path = CGMutablePath()
        var hasMovedToPoint = false

        let prefix: String = chart.data?.accessibilityEntryLabelPrefix ?? "Item"
        let description = dataSet.label ?? ""

        // Make a tuple of (xLabels, value, originalIndex) then sort it
        // This is done, so that the labels are narrated in decreasing order of their corresponding value
        // Otherwise, there is no non-visual logic to the data presented
        let accessibilityEntryValues =  Array(0 ..< entryCount).map { (dataSet.entryForIndex($0)?.y ?? 0, $0) }
        let accessibilityAxisLabelValueTuples = zip(accessibilityXLabels, accessibilityEntryValues).map { ($0, $1.0, $1.1) }.sorted { $0.1 > $1.1 }
        let accessibilityDataSetDescription: String = description + ". \(entryCount) \(prefix + (entryCount == 1 ? "" : "s")). "
        let accessibilityFrameWidth: CGFloat = 22.0 // To allow a tap target of 44x44

        var accessibilityEntryElements: [NSUIAccessibilityElement] = []

        for j in 0 ..< entryCount
        {
            guard let e = dataSet.entryForIndex(j) else { continue }
            
            let p = center.moving(distance: CGFloat((e.y - chart.chartYMin) * Double(factor) * phaseY),
                                  atAngle: sliceangle * CGFloat(j) * CGFloat(phaseX) + chart.rotationAngle)
            
            if p.x.isNaN
            {
                continue
            }
            
            if !hasMovedToPoint
            {
                path.move(to: p)
                hasMovedToPoint = true
            }
            else
            {
                path.addLine(to: p)
            }

            let accessibilityLabel = accessibilityAxisLabelValueTuples[j].0
            let accessibilityValue = accessibilityAxisLabelValueTuples[j].1
            let accessibilityValueIndex = accessibilityAxisLabelValueTuples[j].2

            let axp = center.moving(distance: CGFloat((accessibilityValue - chart.chartYMin) * Double(factor) * phaseY),
                                    atAngle: sliceangle * CGFloat(accessibilityValueIndex) * CGFloat(phaseX) + chart.rotationAngle)

            let axDescription = description + " - " + accessibilityLabel + ": \(accessibilityValue) \(chart.data?.accessibilityEntryLabelSuffix ?? "")"
            let axElement = createAccessibleElement(withDescription: axDescription,
                                                    container: chart,
                                                    dataSet: dataSet)
            { (element) in
                element.accessibilityFrame = CGRect(x: axp.x - accessibilityFrameWidth,
                                                    y: axp.y - accessibilityFrameWidth,
                                                    width: 2 * accessibilityFrameWidth,
                                                    height: 2 * accessibilityFrameWidth)
            }

            accessibilityEntryElements.append(axElement)
        }
        
        // if this is the largest set, close it
        if dataSet.entryCount < mostEntries
        {
            // if this is not the largest set, draw a line to the center before closing
            path.addLine(to: center)
        }
        
        path.closeSubpath()
        
        // draw filled
//        if dataSet.isDrawFilledEnabled
//        {
//            if dataSet.fill != nil
//            {
//                drawFilledPath(context: context, path: path, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
//            }
//            else
//            {
//                drawFilledPath(context: context, path: path, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
                //그래프 내부 색상
//                context.saveGState()
                context.beginPath()
                context.addPath(path)
                
                // filled is usually drawn with less alpha
                context.setAlpha(0.4)
                context.setShadow(offset: CGSize(width: 0, height: 6), blur: 12, color: #colorLiteral(red: 0, green: 0.5294117647, blue: 0.7254901961, alpha: 0.4))
                
                context.setFillColor(#colorLiteral(red: 0, green: 0.6862745098, blue: 0.7764705882, alpha: 1))
                context.fillPath()
                
//                context.restoreGState()
//            }
//        }
        
        // draw the line (only if filled is disabled or alpha is below 255)
//        if !dataSet.isDrawFilledEnabled || dataSet.fillAlpha < 1.0
//        {
            //그래프 아웃라인
            context.setStrokeColor(#colorLiteral(red: 0.003275389783, green: 0.9987329841, blue: 0.9996680617, alpha: 1))
            context.setLineWidth(1)
            context.setAlpha(1.0)

            context.beginPath()
            context.addPath(path)
            context.strokePath()

            let axElement = createAccessibleElement(withDescription: accessibilityDataSetDescription,
                                                    container: chart,
                                                    dataSet: dataSet)
            { (element) in
                element.isHeader = true
                element.accessibilityFrame = path.boundingBoxOfPath
            }

            accessibleChartElements.append(axElement)
            accessibleChartElements.append(contentsOf: accessibilityEntryElements)
//        }
        
        accessibilityPostLayoutChangedNotification()

        //그래프 내부 대각선 라인
        context.setLineWidth(1)
        context.setStrokeColor(#colorLiteral(red: 0.2425819337, green: 1, blue: 1, alpha: 1))
        context.setAlpha(0.5)
        var pointArr = [CGPoint](repeating: CGPoint(), count: entryCount)
        for j in 0 ..< entryCount{
            let accessibilityValue = accessibilityAxisLabelValueTuples[j].1
            let accessibilityValueIndex = accessibilityAxisLabelValueTuples[j].2
            let axp = center.moving(distance: CGFloat((accessibilityValue - chart.chartYMin) * Double(factor) * phaseY),
                                    atAngle: sliceangle * CGFloat(accessibilityValueIndex) * CGFloat(phaseX) + chart.rotationAngle)
            
            _webLineSegmentsBuffer[0].x = center.x
            _webLineSegmentsBuffer[0].y = center.y
            _webLineSegmentsBuffer[1].x = axp.x
            _webLineSegmentsBuffer[1].y = axp.y
            
            context.strokeLineSegments(between: _webLineSegmentsBuffer)
            
            pointArr[accessibilityValueIndex] = axp
        }

        
        //중앙 그라디언트
        let color1 = [NSUIColor.init(white: 1.0, alpha: 1).cgColor, NSUIColor.init(white: 1.0, alpha: 0).cgColor]
        let color2 = [NSUIColor.init(white: 0, alpha: 0.12).cgColor, NSUIColor.init(white: 0, alpha: 0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorLocations: [CGFloat] = [0.0, 1.0]
        guard let gradient1 = CGGradient(
          colorsSpace: colorSpace,
          colors: color1 as CFArray,
          locations: colorLocations
        ) else {
            return
        }
        guard let gradient2 = CGGradient(
          colorsSpace: colorSpace,
          colors: color2 as CFArray,
          locations: colorLocations
        ) else {
            return
        }
        
        context.beginPath()
        context.move(to: center)
        for i in 0..<pointArr.count{
            if i % 2 == 0 && !(pointArr.count % 2 == 1 && i == 0){  // pointArr.count가 홀수이고 i == 0 이면 그라디언트 PASS
                context.addLine(to: pointArr[i])
                if i == 0 {
                    context.addLine(to: pointArr[pointArr.count-1])
                }else{
                    context.addLine(to: pointArr[i-1])
                }
                context.addLine(to: center)
            }
        }
        context.clip()
        context.drawRadialGradient(gradient1, startCenter: center, startRadius: 0, endCenter: center, endRadius: 45, options: [])
//        context.restoreGState()
        
        context.beginPath()
        context.move(to: center)
        for i in 0..<pointArr.count{
            if i % 2 == 1{
                context.addLine(to: pointArr[i])
                context.addLine(to: pointArr[i-1])
                context.addLine(to: center)
            }
        }
        context.clip()
        context.drawRadialGradient(gradient2, startCenter: center, startRadius: 0, endCenter: center, endRadius: 45, options: [])
        context.restoreGState()
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let chart = chart,
            let data = chart.data
            else { return }
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        let sliceangle = chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = chart.factor
        
        let center = chart.centerOffsets
        
        let yoffset = CGFloat(5.0)
        
        for i in data.indices
        {
            guard let
                dataSet = data[i] as? RadarChartDataSetProtocol,
                shouldDrawValues(forDataSet: dataSet)
                else { continue }
            
            let angleRadians = dataSet.valueLabelAngle.DEG2RAD
            
            let entryCount = dataSet.entryCount
            
            let iconsOffset = dataSet.iconsOffset
            
            for j in 0 ..< entryCount
            {
                guard let e = dataSet.entryForIndex(j) else { continue }
                
                let p = center.moving(distance: CGFloat(e.y - chart.chartYMin) * factor * CGFloat(phaseY),
                                      atAngle: sliceangle * CGFloat(j) * CGFloat(phaseX) + chart.rotationAngle)
                
                let valueFont = dataSet.valueFont
                
                let formatter = dataSet.valueFormatter
                
                if dataSet.isDrawValuesEnabled
                {
                    context.drawText(formatter.stringForValue(e.y,
                                                              entry: e,
                                                              dataSetIndex: i,
                                                              viewPortHandler: viewPortHandler),
                                     at: CGPoint(x: p.x, y: p.y - yoffset - valueFont.lineHeight),
                                     align: .center,
                                     angleRadians: angleRadians,
                                     attributes: [.font: valueFont,
                                                  .foregroundColor: dataSet.valueTextColorAt(j)])
                }
                
                if let icon = e.icon, dataSet.isDrawIconsEnabled
                {
                    var pIcon = center.moving(distance: CGFloat(e.y) * factor * CGFloat(phaseY) + iconsOffset.y,
                                              atAngle: sliceangle * CGFloat(j) * CGFloat(phaseX) + chart.rotationAngle)
                    pIcon.y += iconsOffset.x
                    
                    context.drawImage(icon,
                                      atCenter: CGPoint(x: pIcon.x, y: pIcon.y),
                                      size: icon.size)
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        drawWeb(context: context)
    }
    
    private var _webLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc open func drawWeb(context: CGContext)
    {
        guard
            let chart = chart,
            let data = chart.data
            else { return }
        
        let sliceangle = chart.sliceAngle
        
        context.saveGState()
        
        // calculate the factor that is needed for transforming the value to
        // pixels
        let factor = chart.factor
        let rotationangle = chart.rotationAngle
        
        let center = chart.centerOffsets
        
        let xIncrements = 1 + chart.skipWebLineCount
        let maxEntryCount = chart.data?.maxEntryCountSet?.entryCount ?? 0
        let labelCount = chart.yAxis.entryCount
        
        //배경 테두리 라인
        context.setStrokeColor(chart.strokeColor.cgColor)
        context.setAlpha(1)
        for j in (0 ..< labelCount).reversed()
        {
            var pointArr:[CGPoint] = []
            for i in 0 ..< data.entryCount
            {
                let r = CGFloat(chart.yAxis.entries[j] - chart.chartYMin) * factor

                let p1 = center.moving(distance: r, atAngle: sliceangle * CGFloat(i) + rotationangle)
                let p2 = center.moving(distance: r, atAngle: sliceangle * CGFloat(i + 1) + rotationangle)
                
                _webLineSegmentsBuffer[0].x = p1.x
                _webLineSegmentsBuffer[0].y = p1.y
                _webLineSegmentsBuffer[1].x = p2.x
                _webLineSegmentsBuffer[1].y = p2.y
                
                if j == labelCount-1{
                    context.setLineWidth(1)
                    context.setLineDash(phase: 0, lengths: [])
                }else{
                    context.setLineWidth(2)
                    context.setLineDash(phase: 0, lengths: [3.0, 3.0])
                }
                
                context.strokeLineSegments(between: _webLineSegmentsBuffer)
                pointArr.append(p1)
            }
            
            //테두리 색채우기
            context.beginPath()
            context.move(to: pointArr[0])
            for k in 1..<pointArr.count{
                context.addLine(to: pointArr[k])
            }
            if j%2 == 0{
                context.setFillColor(chart.fillColor2.cgColor)
            }else{
                context.setFillColor(chart.fillColor1.cgColor)
            }
            context.fillPath()
        }
        
        //배경 대각선 라인
        context.setLineWidth(1)
        context.setStrokeColor(chart.strokeColor.cgColor)
        context.setAlpha(1)
        context.setLineDash(phase: 0, lengths: [3.0, 3.0])
        var pointArr:[CGPoint] = []
        for i in stride(from: 0, to: maxEntryCount, by: xIncrements)
        {
            let p = center.moving(distance: CGFloat(chart.yRange) * factor,
                                  atAngle: sliceangle * CGFloat(i) + rotationangle)
            
            _webLineSegmentsBuffer[0].x = center.x
            _webLineSegmentsBuffer[0].y = center.y
            _webLineSegmentsBuffer[1].x = p.x
            _webLineSegmentsBuffer[1].y = p.y
            
            context.strokeLineSegments(between: _webLineSegmentsBuffer)
            pointArr.append(p)
        }
        
        //테두리 원
        context.setLineWidth(1)
        context.setStrokeColor(chart.circleStrokeColor.cgColor)
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(chart.fillColor2.cgColor)
        let raduis:CGFloat = 4
        for i in pointArr{
            let rect = CGRect(x: i.x - raduis/2, y: i.y - raduis/2, width: raduis, height: raduis)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        }
        
        context.restoreGState()
    }
    
    private var _highlightPointBuffer = CGPoint()

    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let chart = chart,
            let radarData = chart.data as? RadarChartData
            else { return }
        
        context.saveGState()
        
        let sliceangle = chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value pixels
        let factor = chart.factor
        
        let center = chart.centerOffsets
        
        for high in indices
        {
            guard
                let set = chart.data?[high.dataSetIndex] as? RadarChartDataSetProtocol,
                set.isHighlightEnabled
                else { continue }
            
            guard let e = set.entryForIndex(Int(high.x)) as? RadarChartDataEntry
                else { continue }
            
            if !isInBoundsX(entry: e, dataSet: set)
            {
                continue
            }
            
            context.setLineWidth(radarData.highlightLineWidth)
            if radarData.highlightLineDashLengths != nil
            {
                context.setLineDash(phase: radarData.highlightLineDashPhase, lengths: radarData.highlightLineDashLengths!)
            }
            else
            {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            context.setStrokeColor(set.highlightColor.cgColor)
            
            let y = e.y - chart.chartYMin
            
            _highlightPointBuffer = center.moving(distance: CGFloat(y) * factor * CGFloat(animator.phaseY),
                                                  atAngle: sliceangle * CGFloat(high.x) * CGFloat(animator.phaseX) + chart.rotationAngle)
            
            high.setDraw(pt: _highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
            
            if set.isDrawHighlightCircleEnabled
            {
                if !_highlightPointBuffer.x.isNaN && !_highlightPointBuffer.y.isNaN
                {
                    var strokeColor = set.highlightCircleStrokeColor
                    if strokeColor == nil
                    {
                        strokeColor = set.color(atIndex: 0)
                    }
                    if set.highlightCircleStrokeAlpha < 1.0
                    {
                        strokeColor = strokeColor?.withAlphaComponent(set.highlightCircleStrokeAlpha)
                    }
                    
                    drawHighlightCircle(
                        context: context,
                        atPoint: _highlightPointBuffer,
                        innerRadius: set.highlightCircleInnerRadius,
                        outerRadius: set.highlightCircleOuterRadius,
                        fillColor: set.highlightCircleFillColor,
                        strokeColor: strokeColor,
                        strokeWidth: set.highlightCircleStrokeWidth)
                }
            }
        }
        
        context.restoreGState()
    }
    
    internal func drawHighlightCircle(
        context: CGContext,
        atPoint point: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        fillColor: NSUIColor?,
        strokeColor: NSUIColor?,
        strokeWidth: CGFloat)
    {
        context.saveGState()
        
        if let fillColor = fillColor
        {
            context.beginPath()
            context.addEllipse(in: CGRect(x: point.x - outerRadius, y: point.y - outerRadius, width: outerRadius * 2.0, height: outerRadius * 2.0))
            if innerRadius > 0.0
            {
                context.addEllipse(in: CGRect(x: point.x - innerRadius, y: point.y - innerRadius, width: innerRadius * 2.0, height: innerRadius * 2.0))
            }
            
            context.setFillColor(fillColor.cgColor)
            context.fillPath(using: .evenOdd)
        }
            
        if let strokeColor = strokeColor
        {
            context.beginPath()
            context.addEllipse(in: CGRect(x: point.x - outerRadius, y: point.y - outerRadius, width: outerRadius * 2.0, height: outerRadius * 2.0))
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(strokeWidth)
            context.strokePath()
        }
        
        context.restoreGState()
    }

    private func createAccessibleElement(withDescription description: String,
                                         container: RadarChartView,
                                         dataSet: RadarChartDataSetProtocol,
                                         modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement {

        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        element.accessibilityLabel = description

        // The modifier allows changing of traits and frame depending on highlight, rotation, etc
        modifier(element)

        
        return element
    }
}
