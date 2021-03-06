//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include "Starboard.h"
#include "Foundation/NSMutableDictionary.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSString.h"
#include <math.h>
#include "UIKit/UIGestureRecognizer.h"
#include "UIKit/UIRuntimeEventConnection.h"

#include "UIGestureRecognizerInternal.h"

extern NSMutableDictionary* curGesturesDict;

@implementation UIGestureRecognizer : NSObject
- (id)initWithCoder:(NSCoder*)coder {
    EbrDebugLog("UIGestureRecognizer: Should init with coder\n");
    return self;
}

- (void)addEventConnection:(UIRuntimeEventConnection*)connection {
    id dest = [connection obj];
    SEL destSel = (SEL)[connection sel];
    [self addTarget:dest action:destSel];
}

- (instancetype)initWithTarget:(id)target action:(SEL)selector {
    [self addTarget:target action:selector];
    return self;
}

- (void)setDelegate:(id<UIGestureRecognizerDelegate>)delegate {
    _delegate = delegate;
}

- (id<UIGestureRecognizerDelegate>)delegate {
    return _delegate;
}

- (void)_setView:(UIView*)view {
    _view = view;
}

- (UIView*)view {
    return _view;
}

- (void)setEnabled:(BOOL)enabled {
    _disabled = !enabled;
}

- (BOOL)isEnabled {
    return !_disabled;
}

- (void)setCancelsTouchesInView:(BOOL)cancels {
}

- (void)setDelaysTouchesBegan:(BOOL)delays {
}

- (void)setDelaysTouchesEnded:(BOOL)delays {
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
}

- (UIGestureRecognizerState)state {
    return _state;
}

- (void)setState:(UIGestureRecognizerState)state {
    _state = state;
}

- (void)_fire {
    for (int i = 0; i < _numTargets; i++) {
        id target = _targets[i]._target;
        SEL sel = _targets[i]._selector;

        {
            TimingFunction t("Gesture");
            // EbrDebugLog("Gesture %s detected - calling %s::%s\n", object_getClassName(self),
            // object_getClassName(target), sel);
            [target performSelector:sel withObject:self];
        }
    }
}

- (void)addTarget:(id)target action:(SEL)action {
    _targets[_numTargets]._target = target;
    _targets[_numTargets]._selector = action;
    _numTargets++;
}

- (void)reset {
    _state = UIGestureRecognizerStatePossible;
}

- (void)requireGestureRecognizerToFail:(UIGestureRecognizer*)gesture {
}

+ (BOOL)_fireGestures:(id)gestures {
    bool didRecognize = false;

    for (UIGestureRecognizer* curgesture in gestures) {
        UIGestureRecognizerState state = (UIGestureRecognizerState)[curgesture state];

        if (state == UIGestureRecognizerStateRecognized || state == UIGestureRecognizerStateBegan ||
            state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateEnded) {
            [curgesture _fire];
            didRecognize = true;
        }
    }

    return didRecognize;
}

- (void)cancel {
    if (_state == UIGestureRecognizerStateBegan || _state == UIGestureRecognizerStateChanged) {
        _state = UIGestureRecognizerStateCancelled;
        [self _fire];
    } else {
        _state = UIGestureRecognizerStateCancelled;
    }
}

- (void)cancelIfActive {
    id curList = [curGesturesDict objectForKey:[self class]];
    if ([curList containsObject:self]) {
        [self cancel];
    }
}

+ (void)cancelActiveExcept:(UIGestureRecognizer*)gesture {
    id curList = [curGesturesDict objectForKey:self];
    for (UIGestureRecognizer* curGesture in curList) {
        if (curGesture != gesture) {
            EbrDebugLog("Cancelling %s\n", object_getClassName(curGesture));
            [curGesture cancel];
        }
    }
}

+ (void)failActiveExcept:(UIGestureRecognizer*)gesture {
    NSArray* curList = [curGesturesDict objectForKey:self];
    for (UIGestureRecognizer* curGesture in curList) {
        if (curGesture != gesture) {
            UIGestureRecognizer* gesture = curGesture;

            if (gesture->_state != UIGestureRecognizerStatePossible) {
                gesture->_state = UIGestureRecognizerStateFailed;
            }
        }
    }
}

@end
