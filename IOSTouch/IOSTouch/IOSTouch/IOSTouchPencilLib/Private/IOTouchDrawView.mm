//
//  IOTouchDrawView.m
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/19/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../Public/IOSTouchPencilManager.h"
#import "../Public/IOSTouchDrawView.h"
#import "../Public/UIStrokeLib.h"

@interface IOSTouchDrawView()
@end

@implementation IOSTouchDrawView
{
    UIStrokeVector _ActiveStrokes;
    UIStrokeVector* _StrokeArchive;
    NSInteger _StrokeArchiveBookmark;
    UIColor* _WhiteColor;
    UIColor* _OrangeColor;
    UIColor* _BlackColor;
    UIColor* _GrayColor;
    UIColor* _RedColor;
    CGFloat _MinStrokeWidth;
    CGFloat _MaxStrokeWidth;
    CGFloat _MinStrokeAlpha;
    CGFloat _MaxStrokeAlpha;
    CGFloat _ForceLevels;
}

//MARK: UIView Initializers
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.layer.drawsAsynchronously = true;
    _WhiteColor = [UIColor whiteColor];
    _OrangeColor = [UIColor orangeColor];
    _BlackColor = [UIColor blackColor];
    _GrayColor = [UIColor grayColor];
    _RedColor = [UIColor redColor];
    _MinStrokeWidth = 0.5;
    _MaxStrokeWidth = 4;
    _MinStrokeAlpha = 1.0;
    _MaxStrokeAlpha = 1.0;
    _ForceLevels = 10;
    return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder {
    self = [super initWithCoder:aDecoder];
    return self;
}

/*
 Future optimization
+ (Class)layerClass
{
    return [CATiledLayer class];
}
*/

//MARK: UIView Methods

NS_INLINE void MoveTo(CGContext* context, CGPoint point)
{
    if (isnan(point.x))
    {
        return;
    }
    CGContextMoveToPoint(context, point.x, point.y);
}

NS_INLINE void DrawLineTo(CGContext* context, CGPoint point)
{
    if (isnan(point.x))
    {
        return;
    }
    CGContextAddLineToPoint(context, point.x, point.y);
}

NS_INLINE CGRect GetCGRect(CGPoint point, CGFloat margin)
{
    return CGRectMake(point.x-margin/2, point.y-margin/2, margin, margin);
}

NS_INLINE void DrawCurveTo(CGContext* context, CGPoint point, CGPoint controlPoint1, CGPoint controlPoint2)
{
    //if (isnan(point.x) || isnan(controlPoint1.x) || isnan(controlPoint2.x))
    //{
    //    return;
    //}
    CGContextAddCurveToPoint(context, controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y, point.x, point.y);
}

NS_INLINE void DrawLine(CGContext* context, CGPoint point1, CGPoint point2)
{
    CGContextBeginPath(context);
    MoveTo(context, point1);
    DrawLineTo(context, point2);
    CGContextStrokePath(context);
}

NS_INLINE void DrawCross(CGContext* context, CGPoint point, CGFloat size)
{
    size = size/2;
    DrawLine(context, CGPointMake(point.x-size, point.y), CGPointMake(point.x+size, point.y));
    DrawLine(context, CGPointMake(point.x, point.y-size), CGPointMake(point.x, point.y+size));
}

- (UIColor*)GetStrokeColor:(UIStrokePosition*)strokePosition stroke:(UIStroke*)stroke
{
    auto debugColors = false;
    auto useAlphaForce = true;
    UIColor* strokeColor = _BlackColor;
    if (debugColors)
    {
        switch (strokePosition->SourceType) {
            case UIStrokePositionSourceType::Actual:
                strokeColor = _BlackColor;
                break;
            case UIStrokePositionSourceType::Coalesced:
                strokeColor = _GrayColor;
                break;
            case UIStrokePositionSourceType::Predicted:
                strokeColor = _OrangeColor;
                break;
            default:
                strokeColor = _RedColor;
                break;
        }
    }
    if (useAlphaForce)
    {
        auto force = [self GetStrokeForce:strokePosition stroke:stroke];
        auto alpha = _MinStrokeAlpha + (_MaxStrokeAlpha-_MinStrokeAlpha)*force;
        CGFloat r,g,b,a;
        [strokeColor getRed:&r green:&g blue:&b alpha:&a];
        a = a * alpha;
        strokeColor = [UIColor colorWithRed:r green:g blue:b alpha:a];
        
    }
    return strokeColor;
}

NS_INLINE CGFloat roundUp(CGFloat number, CGFloat fixedBase) {
    if (fixedBase != 0 && number != 0) {
        CGFloat sign = number > 0 ? 1 : -1;
        number *= sign;
        number /= fixedBase;
        int fixedPoint = (int) ceil(number);
        number = fixedPoint * fixedBase;
        number *= sign;
    }
    return number;
}

- (CGFloat)GetStrokeForce:(UIStrokePosition*)strokePosition stroke:(UIStroke*)stroke
{
    auto numberOfLevels = _ForceLevels;
    auto multiple = CGFloat(1.0)/numberOfLevels;
    auto minForce = CGFloat(0.0);
    minForce = MAX(minForce, multiple);
    auto force = strokePosition->Properties.NormalizedForce(stroke->MaxPossibleForce, 20, 60, 0.2);
    force = MAX(minForce,MIN(force,1.0));
    force = roundUp(force, multiple);
    return force;
}

- (CGFloat)GetStrokeWidth:(UIStrokePosition*)strokePosition stroke:(UIStroke*)stroke
{
    auto force = [self GetStrokeForce:strokePosition stroke:stroke];
    auto strokeWidth = _MinStrokeWidth + (_MaxStrokeWidth-_MinStrokeWidth)*force;
    return strokeWidth;
}

- (void)DrawStrokePoint:(CGContext*)context strokePosition:(UIStrokePosition*)strokePosition stroke:(UIStroke*)stroke
{
    auto strokeColor = [self GetStrokeColor:strokePosition stroke:stroke];
    auto strokeWidth = [self GetStrokeWidth:strokePosition stroke:stroke];
    CGContextSetFillColorWithColor(context, strokeColor.CGColor);
    auto dotRect = GetCGRect(strokePosition->Position, strokeWidth);
    CGContextFillEllipseInRect(context, dotRect);
}


- (CGFloat)GetInterpolatedWidth:(UIStrokePositionVector*)strokePositions stroke:(UIStroke*)stroke index:(NSInteger)index
{
    auto strokePosition1 = &(*strokePositions)[index];
    auto strokePosition2 = &(*strokePositions)[index+1];
    auto strokeWidth1 = [self GetStrokeWidth:strokePosition1 stroke:stroke];
    auto strokeWidth2 = [self GetStrokeWidth:strokePosition2 stroke:stroke];
    return strokeWidth1 + (strokeWidth2 - strokeWidth1) * 0.5;
}

- (CGFloat)GetStrokeWidth:(UIStrokePositionVector*)strokePositions stroke:(UIStroke*)stroke index:(NSInteger)index
{
    auto strokePosition1 = &(*strokePositions)[index];
    return [self GetStrokeWidth:strokePosition1 stroke:stroke];
}

- (CGFloat)GetInterpolatedForce:(UIStrokePositionVector*)strokePositions stroke:(UIStroke*)stroke index:(NSInteger)index
{
    auto strokePosition1 = &(*strokePositions)[index];
    auto strokePosition2 = &(*strokePositions)[index+1];
    auto strokeWidth1 = [self GetStrokeForce:strokePosition1 stroke:stroke];
    auto strokeWidth2 = [self GetStrokeForce:strokePosition2 stroke:stroke];
    return strokeWidth1 + (strokeWidth2 - strokeWidth1) * 0.5;
}

- (UIColor*)GetInterpolatedColor:(UIStrokePositionVector*)strokePositions stroke:(UIStroke*)stroke index:(NSInteger)index
{
    auto strokePosition1 = &(*strokePositions)[index];
    auto strokePosition2 = &(*strokePositions)[index+1];
    auto strokeColor1 = [self GetStrokeColor:strokePosition1 stroke:stroke];
    auto strokeColor2 = [self GetStrokeColor:strokePosition2 stroke:stroke];
    return [self GetInterpolatedColor:strokeColor1 color2:strokeColor2 ratio:0.5];
}

- (UIColor*)GetStrokeColor:(UIStrokePositionVector*)strokePositions stroke:(UIStroke*)stroke index:(NSInteger)index
{
    auto strokePosition1 = &(*strokePositions)[index];
    return [self GetStrokeColor:strokePosition1 stroke:stroke];
}

- (UIColor*)GetInterpolatedColor:(UIColor*)color1 color2:(UIColor*)color2 ratio:(CGFloat)ratio
{
    ratio = MIN(1.0, MAX(0.0, ratio));
    CGFloat r1,r2,g1,g2,b1,b2,a1,a2;
    [color1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [color2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    auto r = r1 + (r2 - r1) * ratio;
    auto g = g1 + (g2 - g1) * ratio;
    auto b = b1 + (b2 - b1) * ratio;
    auto a = a1 + (a2 - a1) * ratio;
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

- (void)drawStroke:(CGRect)rect stroke:(UIStroke*)stroke strokePositions:(UIStrokePositionVector*)strokePositions context:(CGContext*)context
{
    CGContextSaveGState(context);
    auto positionCount = (NSInteger)strokePositions->size();
    if (positionCount > 0)
    {
        auto defaultStrokeColor = _BlackColor;
        auto defaultStrokeWidth = CGFloat(8);
        auto singleColor = false;
        auto pointsAlpha = 1.0;
        auto linesAlpha = 1.0;
        auto singleWidth = false;
        auto drawEndPoints = false;
        auto roundCaps = true;
        auto drawAllPoints = false;
        auto noCurves = false;
        auto drawLastPredictedCross = false;
        auto useAlphaForce = false;
        auto drawLines = true;
        
        //CGContextSetInterpolationQuality(layerContext, IS_RETINA_DISPLAY ? kCGInterpolationNone : kCGInterpolationLow);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        if (roundCaps)
        {
            CGContextSetLineCap(context, kCGLineCapRound);
        }
        else
        {
            CGContextSetLineCap(context, kCGLineCapButt);
        }
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        //CGContextSetFlatness(context,0.5);
        CGContextSetInterpolationQuality(context,kCGInterpolationHigh);
        CGContextSetAllowsAntialiasing(context,true);
        CGContextSetShouldAntialias(context, true);
        
        auto index = 0;
        while (drawLines && index<positionCount)
        {
            auto strokeColor = defaultStrokeColor;
            UIColor* previousColor = nil;
            auto strokeWidth = defaultStrokeWidth;
            auto previousWidth = strokeWidth;
            auto previousWidthSet = false;
            auto strokeAlpha = linesAlpha;
            auto previousStrokeAlpha = strokeAlpha;
            auto previousStrokeAlphaSet = false;

            auto layerContext = context;
            CGContextBeginPath(layerContext);
            auto previousStrokePosition = &(*strokePositions)[index++];
            MoveTo(layerContext, previousStrokePosition->Position);
            
            while (index<positionCount)
            {
                if (!singleColor)
                {
                    strokeColor = [self GetStrokeColor:strokePositions stroke:stroke index:index-1];
                    //strokeColor = [self GetInterpolatedColor:strokePositions stroke:stroke index:index-1];
                }
                if (!singleWidth)
                {
                    strokeWidth = [self GetStrokeWidth:strokePositions stroke:stroke index:index-1];
                    //strokeWidth = [self GetInterpolatedWidth:strokePositions stroke:stroke index:index-1];
                }
                if (useAlphaForce)
                {
                    strokeAlpha = [self GetInterpolatedForce:strokePositions stroke:stroke index:index-1];
                }

                auto strokePosition = &(*strokePositions)[index++];
                
                if ((!singleColor && previousColor != nil && ![previousColor isEqual:strokeColor])
                    || (!singleWidth && previousWidthSet && previousWidth != strokeWidth)
                    || (!useAlphaForce && previousStrokeAlphaSet && previousStrokeAlpha != strokeAlpha))
                {
                    strokeColor = previousColor;
                    strokeWidth = previousWidth;
                    strokeAlpha = previousStrokeAlpha;
                    index -= 2;
                    break;
                }
                previousColor = strokeColor;
                previousWidth = strokeWidth;
                previousStrokeAlpha = strokeAlpha;
                previousWidthSet = true;
                
                if (noCurves || isnan(strokePosition->SmoothControlPoint1.x))
                {
                    DrawLineTo(layerContext, strokePosition->Position);
                    //DrawCurveTo(context, strokePosition->Position, strokePosition->Position, strokePosition->Position);
                }
                else
                {
                    DrawCurveTo(layerContext, strokePosition->Position, strokePosition->SmoothControlPoint1, strokePosition->SmoothControlPoint2);
                }
            }
            CGContextSetLineWidth(layerContext, strokeWidth);
            CGContextSetStrokeColorWithColor(layerContext, strokeColor.CGColor);
            CGContextSetFillColorWithColor(layerContext, strokeColor.CGColor);
            CGContextSetAlpha(layerContext, strokeAlpha);
            CGContextStrokePath(layerContext);
        }
        
        if (drawEndPoints && positionCount > 0)
        {
            auto firstPosition = &(*strokePositions)[0];
            [self DrawStrokePoint:context strokePosition:firstPosition stroke:stroke];
            if (positionCount > 1)
            {
                auto lastPosition = &(*strokePositions)[positionCount-1];
                [self DrawStrokePoint:context strokePosition:lastPosition stroke:stroke];
            }
        }

        if (drawAllPoints)
        {
            CGContextSetAlpha(context, pointsAlpha);
            auto strokeColor = defaultStrokeColor;
            auto strokeWidth = defaultStrokeWidth;
            auto strokeAlpha = pointsAlpha;
            for (NSInteger positionIndex=0; positionIndex<positionCount; positionIndex++)
            {
                if (!singleColor)
                {
                    strokeColor = [self GetStrokeColor:strokePositions stroke:stroke index:index-1];
                }
                if (!singleWidth)
                {
                    strokeWidth = [self GetStrokeWidth:strokePositions stroke:stroke index:index-1];
                }
                if (useAlphaForce)
                {
                    strokeAlpha = [self GetInterpolatedForce:strokePositions stroke:stroke index:index-1];
                }
                
                auto strokePosition = &(*strokePositions)[positionIndex];
                auto dotRect = GetCGRect(strokePosition->Position, strokeWidth);
                CGContextSetFillColorWithColor(context, strokeColor.CGColor);
                CGContextSetAlpha(context, strokeAlpha);
                CGContextFillEllipseInRect(context, dotRect);
            }
        }
        if (drawLastPredictedCross && positionCount>0)
        {
            auto strokePosition = &(*strokePositions)[positionCount-1];
            if (strokePosition->SourceType == UIStrokePositionSourceType::Predicted)
            {
                CGContextSetAlpha(context, pointsAlpha);
                auto strokeColor = _OrangeColor;
                auto strokeWidth = 2;
                CGContextSetLineWidth(context, strokeWidth);
                CGContextSetStrokeColorWithColor(context, strokeColor.CGColor);
                DrawCross(context, strokePosition->Position, 50);
            }
        }
    }
    CGContextRestoreGState(context);
}

- (void)drawStrokes:(CGRect)rect strokes:(UIStrokeVector*)strokes strokeCount:(NSInteger)strokeCount context:(CGContext*)context
{
    for (NSInteger strokeIndex=0; strokeIndex<strokeCount; strokeIndex++)
    {
        auto stroke = &(*strokes)[strokeIndex];
        if (stroke->Positions != nullptr)
        {
            [self drawStroke:rect stroke:stroke strokePositions:stroke->Positions.get() context:context];
        }
        if (stroke->PredictedPositions != nullptr)
        {
            [self drawStroke:rect stroke:stroke strokePositions:stroke->PredictedPositions.get() context:context];
        }
    }
}

- (void)drawRect:(CGRect)rect {
    auto context = UIGraphicsGetCurrentContext();

    auto dirtyFrame = rect;
    CGContextSetFillColorWithColor(context, _WhiteColor.CGColor);
    CGContextFillRect(context, dirtyFrame);
    
    [self drawStrokes:rect strokes:&_ActiveStrokes strokeCount:_ActiveStrokes.size() context:context];
    [self drawStrokes:rect strokes:_StrokeArchive strokeCount:_StrokeArchiveBookmark context:context];
}

//MARK: IOSTouchDrawView Methods

- (void)DrawStrokes:(UIStrokeManagerShared)strokes
{
    _ActiveStrokes = strokes->ActiveStrokes;
    _StrokeArchive = &strokes->StrokeArchive;
    _StrokeArchiveBookmark = strokes->StrokeArchive.size();
    
    /*
    for (NSInteger index=_ActiveStrokes.size()-1; index>=0; index--) {
        auto stroke = &_ActiveStrokes[index];
        auto positionCount = stroke->Positions->size();
        if (positionCount > 0)
        {
            auto lastPosition = &(*stroke->Positions)[index];
            auto dirtyFrame = GetCGRect(lastPosition->Position,200);
            auto count = 0;
            for (NSInteger index=positionCount-1; index>0; index--)
            {
                auto dirtyFrame1 = GetCGRect((*stroke->Positions)[index].Position,200);
                dirtyFrame = CGRectUnion(dirtyFrame, dirtyFrame1);
                count++;
                if (count > 0) break;
            }
            [self setNeedsDisplayInRect:dirtyFrame];
        }
    }
    */
    [self setNeedsDisplay];
}

@end
