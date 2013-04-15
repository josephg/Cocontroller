//
//  GamepadWatcher.h
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import <Foundation/Foundation.h>

struct IOUSBInterfaceStruct300;
struct IOUSBDeviceStruct320;

@interface Gamepad : NSObject {
  // The device itself. Available on MacOS 10.5.4 and up.
  struct IOUSBDeviceStruct320 **_dev;
  
  // InterfaceInterface300 is available from MacOS 10.5 up.
  // We only care about the interface which can receive commands. the other interfaces (for
  // chatpad and headset) are ignored for now.
  struct IOUSBInterfaceStruct300 **_interf;
  
  size_t _buffer_size;
  UInt8 *_buffer;
}

// The location ID is a 32 bit number which is unique among all USB devices in the
// system, and which will not change on a system reboot unless the topology of the
// bus itself changes.
- (UInt32)getLocationId;
- (void)writeBytes:(UInt8 *)bytes ofLength:(size_t)length;

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
