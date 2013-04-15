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

- (void)gamepad:(Gamepad *)gamepad gotData:(StandardGamepadData)data {
  b0.state = data.button[0];
  b1.state = data.button[1];
  b2.state = data.button[2];
  b3.state = data.button[3];
  b4.state = data.button[4];
  b5.state = data.button[5];
  
  b6.doubleValue = data.button[6];
  b7.doubleValue = data.button[7];
  
  b8.state = data.button[8];
  b9.state = data.button[9];
  b10.state = data.button[10];
  b11.state = data.button[11];
  b12.state = data.button[12];
  b13.state = data.button[13];
  b14.state = data.button[14];
  b15.state = data.button[15];
  b16.state = data.button[16];
  
  float amt = 50;
  [b10 setFrameOrigin:NSMakePoint(leftStick.x + data.axis[AXIS_LEFT_X] * amt,
                                  leftStick.y - data.axis[AXIS_LEFT_Y] * amt)];
  
  [b11 setFrameOrigin:NSMakePoint(rightStick.x + data.axis[AXIS_RIGHT_X] * amt,
                                  rightStick.y - data.axis[AXIS_RIGHT_Y] * amt)];
}

- (void)gamepadDidConnect:(Gamepad *)g {
  g.delegate = self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  watcher = [[GamepadWatcher alloc] init];
  watcher.delegate = self;
  [watcher listen];
  
  leftStick = NSPointFromCGPoint([b10 frame].origin);
  rightStick = NSPointFromCGPoint([b11 frame].origin);

}

@end
