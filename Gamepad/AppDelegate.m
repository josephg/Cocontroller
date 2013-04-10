//
//  AppDelegate.m
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import "AppDelegate.h"
#import "GamepadWatcher.h"

@implementation AppDelegate

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  watcher = [[GamepadWatcher alloc] init];
  watcher.delegate = self;
  [watcher listen];
}

@end
