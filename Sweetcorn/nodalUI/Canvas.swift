//
//  Canvas.swift
//  Sweetcorn
//
//  Created by Simon Gladman on 09/03/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import Cocoa

class Canvas: NSView, NodeInterfaceDelegate
{
    let curvesLayer = CAShapeLayer()
    let relationshipCreationLayer = CAShapeLayer()
    
    let model: SweetcornModel
    
    let draggingWidget = TitleLabel()
    
    required init(model: SweetcornModel, frame frameRect: NSRect)
    {
        self.model = model
        
        super.init(frame: frameRect)
        
        registerForDraggedTypes(["DraggingSweetcornNodeType"])
        
        let checkerboard = CIFilter(name: "CICheckerboardGenerator",
            withInputParameters: [
                "inputColor0": CIColor(red: 0, green: 0, blue: 0),
                "inputColor1": CIColor(red: 0.05, green: 0.05, blue: 0.05),
            ])!
        
        backgroundFilters = [checkerboard]
        
        wantsLayer = true
        
        layer?.addSublayer(curvesLayer)
        curvesLayer.strokeColor = NSColor.lightGrayColor().CGColor
        curvesLayer.fillColor = nil
        curvesLayer.lineWidth = 2
        
        layer?.addSublayer(relationshipCreationLayer)
        relationshipCreationLayer.strokeColor = NSColor.magentaColor().CGColor
        relationshipCreationLayer.lineDashPattern = [5,5]
        relationshipCreationLayer.fillColor = nil
        relationshipCreationLayer.lineWidth = 2
        
        updateUI()
    }

    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    var relationshipCreationSource: (node: SweetcornNode, index: Int)?
    {
        didSet
        {
            if relationshipCreationSource == nil
            {
                relationshipCreationLayer.path = nil
            }
        }
    }
    
    var relationshipTarget: (node: SweetcornNode, index: Int)?
    
    override func mouseDragged(theEvent: NSEvent)
    {
        guard let relationshipCreationSource = relationshipCreationSource else
        {
            return
        }
        
        let mouseLocation = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        
        let path = CGPathCreateMutable()
        let sourceNode = relationshipCreationSource.node
        let sourceIndex = relationshipCreationSource.index
        
        let sourceY = NodeWidget.verticalPositionForLabel(sourceIndex, widgetType: .Output, node: sourceNode)
        

        let startPoint = CGPoint(x: mouseLocation.x,
            y: mouseLocation.y)
        let endPoint = CGPoint(x: sourceNode.position.x + 100,
            y: sourceNode.position.y + sourceY + rowHeight / 2)
        
        Canvas.appendConnectingCurveToPath(path,
            startPoint: startPoint,
            endPoint: endPoint)
        
        relationshipCreationLayer.path = path
    }
    
    // Creates the relationship. TODO - move logic to `SweetcornModel`
    override func mouseUp(theEvent: NSEvent)
    {
        guard let relationshipCreationSource = relationshipCreationSource,
            relationshipTarget = relationshipTarget else
        {
            self.relationshipCreationSource = nil
            self.relationshipTarget = nil
            return
        }
        
        for input in relationshipTarget.node.inputs where input.0.targetIndex == relationshipTarget.index
        {
            relationshipTarget.node.inputs[input.0] = nil
        }
        
        let inputIndex = InputIndex(sourceIndex: relationshipCreationSource.index,
            targetIndex: relationshipTarget.index)
        
        relationshipTarget.node.inputs[inputIndex] = relationshipCreationSource.node
    
        renderRelationships()
        
        self.relationshipCreationSource = nil
        self.relationshipTarget = nil
        
        model.updateGLSL()
    }

    func refresh()
    {
        subviews.forEach
        {
            $0.removeFromSuperview()
        }
        
        updateUI()
    }
    
    func updateUI()
    {
        for node in model.nodes
        {
            let nodeWidget = NodeWidget(canvas: self, node: node)
            
            nodeWidget.frame = CGRect(origin: node.position,
                size: nodeWidget.intrinsicContentSize)
            
            addSubview(nodeWidget)
        }
        
        renderRelationships()
    }
    
    func renderRelationships()
    {
        let path = CGPathCreateMutable()
        
        for node in model.nodes
        {
            for input in node.inputs
            {
                let sourceY = NodeWidget.verticalPositionForLabel(input.0.sourceIndex,
                    widgetType: .Output,
                    node: input.1)
                let targetY = NodeWidget.verticalPositionForLabel(input.0.targetIndex,
                    widgetType: .Input,
                    node: node)
             
                let startPoint = CGPoint(x: node.position.x,
                    y: node.position.y + targetY + rowHeight / 2)
                let endPoint = CGPoint(x: input.1.position.x + 100,
                    y: input.1.position.y + sourceY + rowHeight / 2)
                
                Canvas.appendConnectingCurveToPath(path,
                    startPoint: startPoint,
                    endPoint: endPoint)
            }
        }
        
        curvesLayer.path = path
    }
    
    class func appendConnectingCurveToPath(path: CGMutablePath, startPoint: CGPoint, endPoint: CGPoint)
    {
        let offset = abs(startPoint.x - endPoint.x) / 3.0
        
        let controlPointOne = CGPoint(x: endPoint.x + offset,
            y: startPoint.y)
        let controlPointTwo = CGPoint(x: startPoint.x - offset,
            y: endPoint.y)
        
        CGPathMoveToPoint(path, nil,
            startPoint.x, startPoint.y)
        
        CGPathAddCurveToPoint(path, nil,
            controlPointOne.x, controlPointOne.y,
            controlPointTwo.x, controlPointTwo.y,
            endPoint.x, endPoint.y)
    }
}

extension Canvas // Dropping support
{
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation
    {
        let draggingLocation = NSPoint(x: convertPoint(sender.draggingLocation(), fromView: nil).x - 50,
            y: convertPoint(sender.draggingLocation(), fromView: nil).y - 10)
        
        addSubview(draggingWidget)
        draggingWidget.hidden = false
        draggingWidget.stringValue = model.draggingNodeTypeName ?? ""
        draggingWidget.frame = CGRect(origin: draggingLocation,
            size: CGSize(width: 100, height: 20))
        
        return NSDragOperation.Generic
    }
    
    override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation
    {
        let draggingLocation = NSPoint(x: convertPoint(sender.draggingLocation(), fromView: nil).x - 50,
            y: convertPoint(sender.draggingLocation(), fromView: nil).y - 10)
        
        draggingWidget.frame = CGRect(origin: draggingLocation,
            size: CGSize(width: 100, height: 20))
        
        return NSDragOperation.Generic
    }
    
    // Creates new node after drop
    // TODO - move logic to model
    override func performDragOperation(sender: NSDraggingInfo) -> Bool
    {
        draggingWidget.hidden = true

        if let draggingNodeTypeName = model.draggingNodeTypeName,
            nodeType = model.nodeTypeForName(draggingNodeTypeName)
        {
            let node = SweetcornNode(type: nodeType, position: CGPointZero)
            
            let draggingLocation = NSPoint(x: convertPoint(sender.draggingLocation(), fromView: nil).x - 50,
                y: convertPoint(sender.draggingLocation(), fromView: nil).y + 10 - NodeWidget.widgetHeightForNode(node))
            
            node.position = draggingLocation
            
            model.nodes.append(node)
            
            let nodeWidget = NodeWidget(canvas: self, node: node)
            
            nodeWidget.frame = CGRect(origin: node.position,
                size: nodeWidget.intrinsicContentSize)
            
            addSubview(nodeWidget)
        }
        
        return true
    }
}




