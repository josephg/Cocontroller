//
//  AppDelegate.h
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import <Cocoa/Cocoa.h>
#import "GamepadWatcher.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, GamepadWatcherDelegate> {
  GamepadWatcher *watcher;
}

@property (assign) IBOutlet NSWindow *window;

@end
