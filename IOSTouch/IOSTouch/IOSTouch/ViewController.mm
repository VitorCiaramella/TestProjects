//
//  ViewController.m
//  IOSTouch
//
//  Created by Vitor Ciaramella on 12/18/18.
//  Copyright © 2018 Vitor Ciaramella. All rights reserved.
//

#import "ViewController.h"
#import "IOSTouchPencilLib/Public/IOSTouchPencilManager.h"
#import "IOSTouchPencilLib/Public/IOSTouchDrawView.h"

#import "IOSTouchPencilLib/Public/UIStrokeLib.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIView *CanvasView;
@property (weak, nonatomic) IBOutlet UITextView *TextView;

@end

@implementation ViewController
{
    IOSTouchPencilManager* _TouchPencilManager;
    IOSTouchDrawView* _IOSTouchDrawView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _IOSTouchDrawView = [[IOSTouchDrawView alloc] initWithFrame:self.CanvasView.frame];
    _IOSTouchDrawView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.CanvasView addSubview:_IOSTouchDrawView];
    
    _TouchPencilManager = [[IOSTouchPencilManager alloc] initWithView:_IOSTouchDrawView];
    
    __weak auto weakSelf = self;
    _TouchPencilManager.OnLog = ^(NSString *log)
    {
        auto strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            //strongSelf.TextView.text = [log stringByAppendingString:strongSelf.TextView.text];
            
        }
    };
    _TouchPencilManager.OnTouchesChanged = ^(UIStrokeManagerShared strokes)
    {
        auto strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            auto text = [[NSMutableString alloc] initWithString:@""];
            auto strokesCount = strokes->ActiveStrokes.size();
            if (strokesCount > 0)
            {
                for (NSInteger i=strokesCount-1; i>=0; i--) {
                    auto stroke = &strokes->ActiveStrokes[i];
                    [text appendString:[IOSTouch description:stroke]];
                    [text appendString:@"\n"];
                }
            }
            strongSelf.TextView.text = text;
            
            [strongSelf->_IOSTouchDrawView DrawStrokes:strokes];
        }
    };
}


@end
