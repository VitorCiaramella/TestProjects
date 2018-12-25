//
//  IOSTouchPencilManager.m
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/18/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#ifndef IOSTouchPencilManager_h
#define IOSTouchPencilManager_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#import "UIStrokeLib.h"

typedef NS_ENUM(NSInteger, IOSTouchKind) {
    IOSTouchKindActual,
    IOSTouchKindCoalesced,
    IOSTouchKindPredicted,
};

@interface IOSTouchChange:NSObject
{
    bool _NeedsToDraw;
}
@property(nonatomic,assign, readonly) NSTimeInterval Timestamp;
@property(nonatomic,assign, readonly) CGPoint BestLocation;
@property(nonatomic,assign, readonly) CGFloat MajorRadius;
@property(nonatomic,assign, readonly) CGFloat Force;
@property(nonatomic,assign, readonly) CGFloat AltitudeAngle;
@property(nonatomic,assign, readonly) CGFloat AzimuthAngle;
@property(nonatomic,assign, readonly) CGFloat NormalizedForce;
@property(nonatomic,assign, readonly) IOSTouchKind TouchKind;
@property(nonatomic,assign, readwrite) CGPoint ControlPoint1;
@property(nonatomic,assign, readwrite) CGPoint ControlPoint2;
@property(nonatomic,assign, readwrite) bool Skip;
- (bool)SetNeedsToDraw:(bool)needsToDraw;

@end

@interface IOSTouch:NSObject
+ (NSString*)description:(UIStroke*)stroke;
+ (NSString*)descriptionWithPadding:(UIStroke*)stroke padding:(NSUInteger)padding;
@end

typedef void (^OnLogBlock)(NSString* log);
typedef void (^OnTouchesChanged)(UIStrokeManagerShared strokes);

@interface IOSTouchPencilManager:NSObject

@property(nonatomic, copy) OnLogBlock OnLog;
@property(nonatomic, copy) OnTouchesChanged OnTouchesChanged;

- (id)initWithView:(UIView*)view;

@end

#endif /* StrokeGestureRecognizer_h */
