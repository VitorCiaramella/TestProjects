//
//  IOSTouchPencilManager.m
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/18/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#define EPSILON 1.0e-4
#import "../Public/IOSTouchPencilManager.h"
#import "../Public/UIStrokeLib.h"

@implementation IOSTouch

//MARK: IOSTouch Methods

NS_INLINE bool IsCGFloatEqual(CGFloat float1, CGFloat float2, CGFloat epsilon)
{
    return ABS(float1-float2) < epsilon;
}

NS_INLINE bool IsCGPointEqual(CGPoint point1, CGPoint point2, CGFloat epsilon)
{
    return IsCGFloatEqual(point1.x,point2.x,epsilon) && IsCGFloatEqual(point1.y,point2.y,epsilon);
}

NS_INLINE bool IsCGPointDifferent(CGPoint point1, CGPoint point2, CGFloat epsilon)
{
    return !IsCGFloatEqual(point1.x,point2.x,epsilon) || !IsCGFloatEqual(point1.y,point2.y,epsilon);
}

+ (NSString*)descriptionWithPadding:(UIStroke*)stroke padding:(NSUInteger)padding
{
    auto paddingString = [[NSMutableString alloc] initWithString:@""];
    for (NSUInteger i=0; i<padding; i++) {
        [paddingString appendString:@" "];
    }

    auto text = [[NSMutableString alloc] initWithString:paddingString];

    switch (stroke->InputType) {
        case UIStrokeInputType::Direct:
            [text appendString:@"Direct "];
            break;
        case UIStrokeInputType::Pencil:
            [text appendString:@"Pencil "];
            break;
        case UIStrokeInputType::Indirect:
            [text appendString:@"Indirect "];
            break;
        case UIStrokeInputType::Unknown:
            [text appendString:@"Unknown "];
            break;
    }

    /*
    switch (_TouchKind) {
        case IOSTouchKindActual:
            [text appendString:@"Actual "];
            break;
        case IOSTouchKindPredicted:
            [text appendString:@"Predicted "];
            break;
        case IOSTouchKindCoalesced:
            [text appendString:@"Coalesced "];
            break;
        default:
            [text appendString:@"Unknown "];
            break;
    }
    */
    
    switch (stroke->StrokePhase) {
        case UIStrokePhase::Active:
            [text appendString:@"Active "];
            break;
        case UIStrokePhase::Cancelled:
            [text appendString:@"Cancelled "];
            break;
        case UIStrokePhase::Completed:
            [text appendString:@"Completed "];
            break;
        case UIStrokePhase::Unknown:
            [text appendString:@"Unknown "];
            break;
    }

    [text appendFormat:@"Taps:(%.0f) ", (float)stroke->TapCount];
    if (stroke->Positions != nullptr)
    {
        auto positionsCount = stroke->Positions->size();
        [text appendFormat:@"Positions:(%lu) ",(unsigned long)positionsCount];
    }
    if (stroke->PredictedPositions != nullptr)
    {
        auto positionsCount = stroke->PredictedPositions->size();
        [text appendFormat:@"PredictedPositions:(%lu) ",(unsigned long)positionsCount];
    }

    auto lastPosition = stroke->GetLastPosition();
    if (lastPosition != nullptr)
    {
        [text appendFormat:@"Location:(%.1f,%.1f) ",(float)lastPosition->Position.x, (float)lastPosition->Position.y];
        [text appendFormat:@"Force:(%.1f,%.1f) ",(float)lastPosition->Properties.Force, (float)stroke->MaxPossibleForce];
        [text appendFormat:@"Radius:(%.1f,%.1f) ",(float)lastPosition->Properties.MajorRadius, (float)stroke->MajorRadiusTolerance];
        [text appendFormat:@"Altitude/AzimuthAngle:(%.1f,%.1f) ",(float)lastPosition->Properties.AltitudeAngle, (float)lastPosition->Properties.AzimuthAngle];
    }
    
    return text;
}

//MARK: NSObject Methods
+ (NSString*)description:(UIStroke*)stroke;
{
    return [IOSTouch descriptionWithPadding:stroke padding:0];
}

@end

@interface UIStrokeUITouch : NSObject
@property(nonatomic, weak, readonly) UITouch* UITouch;
@property(nonatomic, assign, readonly) NSInteger UIStrokeId;
- (id)initWithUITouch:(UITouch*)uiTouch withUIStrokeId:(NSInteger)strokeId;
@end
@implementation UIStrokeUITouch
- (id)initWithUITouch:(UITouch*)uiTouch withUIStrokeId:(NSInteger)strokeId
{
    self = [super init];
    _UITouch = uiTouch;
    _UIStrokeId = strokeId;
    return self;
}
@end

@interface IOSTouchPencilGestureRecognizer:UIGestureRecognizer<UIPencilInteractionDelegate, UIGestureRecognizerDelegate>
{
    UIStrokeManagerShared _StrokeManager;
}
- (UIStrokeManagerShared)StrokeManager;

//MARK: UIGestureRecognizer
- (id)initWithTarget:(id)target action:(SEL)action;
- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event;
- (void)touchesEstimatedPropertiesUpdated:(NSSet<UITouch*>*)touches;
- (void)reset;

//MARK: UIGestureRecognizerDelegate
- (bool)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceive:(UITouch*)touch;
- (bool)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldRecognizeSimultaneouslyWith:(UIGestureRecognizer*)otherGestureRecognizer;

//MARK: UIPencilInteractionDelegate
- (void)pencilInteractionDidTap:(UIPencilInteraction*)interaction;

//MARK: IOSTouchPencilGestureRecognizer Properties
@property(nonatomic, strong) UIView* CoordinateSpaceView;
@property(nonatomic, copy) OnLogBlock OnLog;
@property(nonatomic, copy) OnTouchesChanged OnTouchesChanged;

@property(nonatomic, strong, readonly) NSMutableSet<UIStrokeUITouch*>* ActiveUIStrokeUITouch;

//MARK: IOSTouchPencilGestureRecognizer Methods
- (void)Log:(nonnull NSString*)log;
- (void)TouchesChanged;
- (void)UpdateTouches:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event;

@end

@implementation IOSTouchPencilGestureRecognizer
{
    NSInteger _StrokeIdTracker;
}

- (UIStrokeManagerShared)StrokeManager
{
    return _StrokeManager;
}

//MARK: UIGestureRecognizer
- (id)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    
    _StrokeIdTracker = 0;
    _StrokeManager = std::make_shared<UIStrokeManager>();
    _ActiveUIStrokeUITouch = [[NSMutableSet<UIStrokeUITouch*> alloc] initWithCapacity:20];
    return self;
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event
{
    [self Log:[NSString stringWithFormat:@"Touches Began. Touches:%lu/%lu \n", (unsigned long)touches.count, (unsigned long)event.allTouches.count]];
    self.state = UIGestureRecognizerStateBegan;
    
    [self UpdateTouches:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event
{
    [self Log:[NSString stringWithFormat:@"Touches Moved. Touches:%lu/%lu \n", (unsigned long)touches.count, (unsigned long)event.allTouches.count]];
    
    [self UpdateTouches:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event
{
    [self Log:[NSString stringWithFormat:@"Touches Ended. Touches:%lu/%lu \n", (unsigned long)touches.count, (unsigned long)event.allTouches.count]];

    [self UpdateTouches:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event
{
    [self Log:[NSString stringWithFormat:@"Touches Cancelled. Touches:%lu/%lu \n", (unsigned long)touches.count, (unsigned long)event.allTouches.count]];
    self.state = UIGestureRecognizerStateCancelled;

    [self UpdateTouches:touches withEvent:event];
}

- (void)touchesEstimatedPropertiesUpdated:(NSSet<UITouch*>*)touches
{
    [self Log:[NSString stringWithFormat:@"Touches Updated. TouchCount:%lu \n", (unsigned long)touches.count]];

    //[self UpdateTouchesEstimatedProperties:touches];
}

- (void)reset
{
    [super reset];
    _StrokeManager->ActiveStrokes.clear();
    [self TouchesChanged];
}

//MARK: UIGestureRecognizerDelegate
- (bool)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceive:(UITouch*)touch
{
    return true;
}

- (bool)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldRecognizeSimultaneouslyWith:(UIGestureRecognizer*)otherGestureRecognizer
{
    return true;
}

//MARK: UIPencilInteractionDelegate
- (void)pencilInteractionDidTap:(UIPencilInteraction*)interaction
{
    
}

//MARK: IOSTouchPencilGestureRecognizer Properties

//MARK: IOSTouchPencilGestureRecognizer Methods
- (void)Log:(nonnull NSString*)log
{
    if (self.OnLog != nil)
    {
        self.OnLog(log);
    }
}

- (void)TouchesChanged
{
    if (self.OnTouchesChanged != nil)
    {
        self.OnTouchesChanged(_StrokeManager);
    }
}

NS_INLINE UIStroke NewUIStrokeFromUITouch(UITouch* touch, NSInteger strokeId)
{
    UIStrokeInputType inputType;
    switch (touch.type) {
        case UITouchTypeDirect:
            inputType = UIStrokeInputType::Direct;
            break;
        case UITouchTypeIndirect:
            inputType = UIStrokeInputType::Indirect;
            break;
        case UITouchTypePencil:
            inputType = UIStrokeInputType::Pencil;
            break;
    }
    return UIStroke(strokeId, touch.timestamp, inputType, UIStrokePhase::Active);
}

- (bool)UITouchBegan:(UITouch*)uiTouch
{
    auto stroke = NewUIStrokeFromUITouch(uiTouch,_StrokeIdTracker++);

    stroke.TapCount = uiTouch.tapCount;
    if (_StrokeManager->Settings->CollectForce) stroke.MaxPossibleForce = uiTouch.maximumPossibleForce;
    if (_StrokeManager->Settings->CollectTouchRadius) stroke.MajorRadiusTolerance = uiTouch.majorRadiusTolerance;
    stroke.StrokeManager = _StrokeManager;

    _StrokeManager->AddActiveStroke(stroke);

    [_ActiveUIStrokeUITouch addObject:[[UIStrokeUITouch alloc] initWithUITouch:uiTouch withUIStrokeId:stroke.StrokeId]];
    return true;
}

- (NSInteger)GetUIStrokeId:(UITouch*)uiTouch
{
    for (UIStrokeUITouch* uiStrokeUITouch in _ActiveUIStrokeUITouch)
    {
        if (uiStrokeUITouch.UITouch == uiTouch)
        {
            return uiStrokeUITouch.UIStrokeId;
        }
    }
    return -1;
}

- (void)RemoveUIStrokeId:(NSInteger)strokeId
{
    for (UIStrokeUITouch* uiStrokeUITouch in _ActiveUIStrokeUITouch)
    {
        if (uiStrokeUITouch.UIStrokeId == strokeId)
        {
            [_ActiveUIStrokeUITouch removeObject:uiStrokeUITouch];
            return;
        }
    }
}

- (bool)ProcessTouchPosition:(UITouch*)uiTouch uiView:(UIView*)uiView strokeId:(NSInteger)strokeId stroke:(UIStroke*)stroke sourceType:(UIStrokePositionSourceType)sourceType
{
    auto collectPreciseLocation = _StrokeManager->Settings->CollectPreciseLocation;
    auto keepPropertyChangeLog = false;

    auto isDifferentPosition = false;
    auto newPosition = collectPreciseLocation ? [uiTouch preciseLocationInView:uiView] : [uiTouch locationInView:uiView];

    auto strokePosition = stroke->GetLastPosition();
    if (strokePosition != nullptr)
    {
        auto currentPosition = strokePosition->Position;
        isDifferentPosition = IsCGPointDifferent(currentPosition, newPosition, _StrokeManager->Settings->LocationSensitivity);
    }
    else
    {
        isDifferentPosition = true;
    }

    auto newProperties = UIStrokePositionProperties();
    newProperties.Timestamp = uiTouch.timestamp;
    if (_StrokeManager->Settings->CollectTouchRadius) newProperties.MajorRadius = uiTouch.majorRadius;
    if (_StrokeManager->Settings->CollectForce) newProperties.Force = uiTouch.force;
    if (_StrokeManager->Settings->CollectAltitudeAngle) newProperties.AltitudeAngle = uiTouch.altitudeAngle;
    if (_StrokeManager->Settings->CollectAzimuthAngle) newProperties.AzimuthAngle = [uiTouch azimuthAngleInView:uiView];

    if (isDifferentPosition)
    {
        auto newStrokePosition = UIStrokePosition(uiTouch.timestamp, newPosition, sourceType, newProperties, keepPropertyChangeLog);
        stroke->AddPosition(newStrokePosition);
        return true;
    }
    else
    {
        auto propertiesChanged =
            (_StrokeManager->Settings->CollectTouchRadius && !IsCGFloatEqual(strokePosition->Properties.MajorRadius, newProperties.MajorRadius, _StrokeManager->Settings->TouchRadiusSensitivity))
            || (_StrokeManager->Settings->CollectForce && !IsCGFloatEqual(strokePosition->Properties.Force, newProperties.Force, _StrokeManager->Settings->ForceSensitivity))
            || (_StrokeManager->Settings->CollectAltitudeAngle && !IsCGFloatEqual(strokePosition->Properties.AltitudeAngle, newProperties.AltitudeAngle, _StrokeManager->Settings->AltitudeAngleSensitivity))
            || (_StrokeManager->Settings->CollectAzimuthAngle && !IsCGFloatEqual(strokePosition->Properties.AzimuthAngle, newProperties.AzimuthAngle, _StrokeManager->Settings->AzimuthAngleSensitivity));
        if (propertiesChanged)
        {
            strokePosition->SetProperties(newProperties, keepPropertyChangeLog);            
        }
        return true;
    }
    return false;
}

- (bool)UITouchUpdated:(UITouch*)uiTouch uiEvent:(UIEvent*)uiEvent
{
    auto strokeId = [self GetUIStrokeId:uiTouch];
    if (strokeId == -1)
    {
        return false;
    }
    
    auto view = self.CoordinateSpaceView;

    //auto isPositionEstimated = (uiTouch.estimatedProperties & UITouchPropertyLocation) != 0;

    auto stroke = _StrokeManager->GetActiveStroke(strokeId);

    auto positionHasChanged = false;
    
    if (_StrokeManager->Settings->CollectCoalescedTouches)
    {
        auto coalescedTouches = [uiEvent coalescedTouchesForTouch:uiTouch];
        if (coalescedTouches != nil && coalescedTouches.count > 0)
        {
            //skip the last one, as it's the same as the current touch
            for (NSInteger i=0; i<coalescedTouches.count-1; i++) {
                auto coalescedTouch = coalescedTouches[i];
                positionHasChanged = [self ProcessTouchPosition:coalescedTouch uiView:view strokeId:strokeId stroke:stroke sourceType:UIStrokePositionSourceType::Coalesced] || positionHasChanged;
            }
        }
    }
    
    positionHasChanged = [self ProcessTouchPosition:uiTouch uiView:view strokeId:strokeId stroke:stroke sourceType:UIStrokePositionSourceType::Actual] || positionHasChanged;
    
    if (_StrokeManager->Settings->CollectPredictedTouches)
    {
        stroke->PurgePredictedPositions();
        auto predictedTouches = [uiEvent predictedTouchesForTouch:uiTouch];
        if (predictedTouches != nil && predictedTouches.count > 0)
        {
            //skip the last one, as it's the same as the current touch
            for (NSInteger i=0; i<predictedTouches.count; i++) {
                auto predictedTouch = predictedTouches[i];
                positionHasChanged = [self ProcessTouchPosition:predictedTouch uiView:view strokeId:strokeId stroke:stroke sourceType:UIStrokePositionSourceType::Predicted] || positionHasChanged;
            }
        }
    }

    if (uiTouch.phase == UITouchPhaseEnded)
    {
        _StrokeManager->EndActiveStroke(strokeId);
        [self RemoveUIStrokeId:strokeId];
        positionHasChanged = true;
    }
    
    return positionHasChanged;
}

- (bool)UITouchCancelled:(UITouch*)uiTouch
{
    auto strokeId = [self GetUIStrokeId:uiTouch];
    if (strokeId == -1)
    {
        return false;
    }
    [self RemoveUIStrokeId:strokeId];
    return _StrokeManager->CancelActiveStroke(strokeId);
}

- (void)UpdateTouches:(NSSet<UITouch*>*)touches withEvent:(UIEvent *)event
{
    auto touchesChanged = false;
    for (UITouch* touch in touches) {
        if (!((touch.type == UITouchTypeDirect && _StrokeManager->Settings->CollectDirectInput)
              || (touch.type == UITouchTypePencil && _StrokeManager->Settings->CollectPencilInput)
              || (touch.type == UITouchTypeIndirect && _StrokeManager->Settings->CollectIndirectInput))) continue;
        
        auto iosTouchHasChanged = false;
        switch (touch.phase) {
            case UITouchPhaseBegan:
                iosTouchHasChanged = [self UITouchBegan:touch] || iosTouchHasChanged;
                iosTouchHasChanged = [self UITouchUpdated:touch uiEvent:event] || iosTouchHasChanged;
                break;
            case UITouchPhaseMoved:
            case UITouchPhaseStationary:
            case UITouchPhaseEnded:
                iosTouchHasChanged = [self UITouchUpdated:touch uiEvent:event] || iosTouchHasChanged;
                break;
            case UITouchPhaseCancelled:
                iosTouchHasChanged = [self UITouchCancelled:touch] || iosTouchHasChanged;
                break;
        }
        
        touchesChanged = touchesChanged || iosTouchHasChanged;
    }
    
    if (touchesChanged)
    {
        [self TouchesChanged];
    }
    
    auto activeStrokesCount = _StrokeManager->ActiveStrokes.size();
    if (activeStrokesCount > 0 && self.state == UIGestureRecognizerStatePossible)
    {
        self.state = UIGestureRecognizerStateBegan;
    }
    else if (activeStrokesCount > 0 && self.state == UIGestureRecognizerStateBegan)
    {
        self.state = UIGestureRecognizerStateChanged;
    }
    else if (activeStrokesCount == 0 &&
             (self.state == UIGestureRecognizerStateBegan || UIGestureRecognizerStateChanged))
    {
        self.state = UIGestureRecognizerStateRecognized;
    }
}

@end

@interface IOSTouchPencilManager()

@end

@implementation IOSTouchPencilManager
{
    IOSTouchPencilGestureRecognizer* _GestureRecognizer;
}

//MARK: IOSTouchPencilManager Properties
- (UIStrokeSettingsShared)Settings
{
    return _GestureRecognizer.StrokeManager->Settings;
}

//MARK: IOSTouchPencilManager Initializers
- (id)initWithView:(UIView*)view
{
    self = [super init];

    view.multipleTouchEnabled = true;
    view.userInteractionEnabled = true;
    
    auto gestureRecognizer = [[IOSTouchPencilGestureRecognizer alloc]initWithTarget:self action:@selector(GestureRecognized:)];
    gestureRecognizer.delegate = gestureRecognizer;
    gestureRecognizer.cancelsTouchesInView = false;
    [view addGestureRecognizer:gestureRecognizer];
    gestureRecognizer.CoordinateSpaceView = view;
    __weak auto weakSelf = self;
    gestureRecognizer.OnLog = ^(NSString *log)
    {
        auto strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.OnLog != nil)
        {
            strongSelf.OnLog(log);
        }
    };
    gestureRecognizer.OnTouchesChanged = ^(UIStrokeManagerShared strokes)
    {
        auto strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.OnTouchesChanged != nil)
        {
            strongSelf.OnTouchesChanged(strokes);
        }
    };

    _GestureRecognizer = gestureRecognizer;
    
    return self;
}

//MARK: IOSTouchPencilManager Methods
- (void)GestureRecognized:(IOSTouchPencilGestureRecognizer*)gestureRecognizer {
    
}

@end
