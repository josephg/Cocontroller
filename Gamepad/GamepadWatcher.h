//
//  GamepadWatcher.h
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import <Foundation/Foundation.h>

@interface Gamepad : NSObject {
  
}

@end

@protocol GamepadWatcherDelegate <NSObject>
@optional
- (void)gamepadDidConnect:(Gamepad *)g;
@end

@interface GamepadWatcher : NSObject {
  id delegate;
  NSMutableArray *gamepads;
}

@property (nonatomic, retain) id delegate;

- (void)listen;

@end
