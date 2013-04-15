//
//  AppDelegate.h
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import <Cocoa/Cocoa.h>
#import "GamepadWatcher.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, GamepadWatcherDelegate, GamepadDelegate> {
  GamepadWatcher *watcher;
  
  IBOutlet NSButton* b0;
  IBOutlet NSButton* b1;
  IBOutlet NSButton* b2;
  IBOutlet NSButton* b3;
  IBOutlet NSButton* b4;
  IBOutlet NSButton* b5;
  IBOutlet NSProgressIndicator* b6;
  IBOutlet NSProgressIndicator* b7;
  IBOutlet NSButton* b8;
  IBOutlet NSButton* b9;
  IBOutlet NSButton* b10;
  IBOutlet NSButton* b11;
  IBOutlet NSButton* b12;
  IBOutlet NSButton* b13;
  IBOutlet NSButton* b14;
  IBOutlet NSButton* b15;
  IBOutlet NSButton* b16;
  
  NSPoint leftStick;
  NSPoint rightStick;
}

@property (assign) IBOutlet NSWindow *window;

@end
