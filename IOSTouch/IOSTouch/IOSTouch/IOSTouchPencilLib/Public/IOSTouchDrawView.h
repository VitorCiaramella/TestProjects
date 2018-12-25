//
//  IOSTouchDrawCanvas.h
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/19/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#ifndef IOSTouchDrawView_h
#define IOSTouchDrawView_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#import "IOSTouchPencilManager.h"
#import "UIStrokeLib.h"

@interface IOSTouchDrawView : UIView

- (void)DrawStrokes:(UIStrokeManagerShared)strokes;

@end

#endif /* IOSTouchDrawCanvas_h */
