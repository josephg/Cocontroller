//
//  GamepadWatcher.h
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import "StandardGamepad.h"
#import <Foundation/Foundation.h>

struct IOUSBInterfaceStruct300;
struct IOUSBDeviceStruct320;

// The LEDs are numbered top left, top right, bottom left, bottom right.
typedef enum {
  XBOX_LED_OFF = 0,
  
  // 2 quick flashes, then a series of slow flashes (about 1 per second).
  XBOX_LED_FLASH = 1,
  
  // Flash three times then hold the LED on. This is the standard way to tell the player
  // which player number they are.
  XBOX_LED_FLASH_1 = 2,
  XBOX_LED_FLASH_2 = 3,
  XBOX_LED_FLASH_3 = 4,
  XBOX_LED_FLASH_4 = 5,

  // Simply turn on the numbered LED and turn all other LEDs off.
  XBOX_LED_HOLD_1 = 6,
  XBOX_LED_HOLD_2 = 7,
  XBOX_LED_HOLD_3 = 8,
  XBOX_LED_HOLD_4 = 9,

  XBOX_LED_ROTATE = 10,
  
  XBOX_LED_FLASH_FAST = 11,
  XBOX_LED_FLASH_SLOW = 12, // Flash about once per 3 seconds
  
  // Flash alternating LEDs for a few seconds, then flash all LEDs about once per second
  XBOX_LED_ALTERNATE_PATTERN = 13,
  
  // 14 is just another boring flashing speed.
  
  // Flash all LEDs once then go black.
  XBOX_LED_FLASH_ONCE = 15,
} XBOXLedPattern;

@class Gamepad;
@protocol GamepadDelegate <NSObject>
@optional
- (void)gamepad:(Gamepad *)gamepad ledStatusKnown:(XBOXLedPattern)pattern;
- (void)gamepad:(Gamepad *)gamepad gotData:(StandardGamepadData)data;
@end

@interface Gamepad : NSObject {
  // The device itself. Available on MacOS 10.5.4 and up.
  struct IOUSBDeviceStruct320 **_dev;
  
  // InterfaceInterface300 is available from MacOS 10.5 up.
  // We only care about the interface which can receive commands. the other interfaces (for
  // chatpad and headset) are ignored for now.
  struct IOUSBInterfaceStruct300 **_interf;
  
  // This will be set to the max packet size reported by the interface, which is 32 bytes.
  // I would have expected USB to do message framing itself, but somehow we still sometimes
  // (rarely!) get packets off the interface which aren't correctly framed. The 360 controller
  // frames its packets with a 2 byte header (type, total length) so we can reframe the packet
  // data ourselves.
  UInt16 _read_buffer_size;
  UInt8 *_read_buffer;
  
  id<GamepadDelegate> delegate;
  
  XBOXLedPattern _ledPattern;
}

@property (assign) id delegate;

// The location ID is a 32 bit number which is unique among all USB devices in the
// system, and which will not change on a system reboot unless the topology of the
// bus itself changes.
//
// Returns UINT32_MAX on error.
- (UInt32)getLocationId;

// See the XBOXLedPattern enum for values above.
@property XBOXLedPattern ledPattern;

- (void)setLedPattern:(XBOXLedPattern)pattern;
// Set the values of the controller's rumble pack. These are bytes which range from
// 0 to 255 specifying the intensity of the vibration.
- (void)setRumbleLarge:(UInt8)large small:(UInt8)small;

@end

@protocol GamepadWatcherDelegate <NSObject>
@optional
- (void)gamepadDidConnect:(Gamepad *)g;
@end

@interface GamepadWatcher : NSObject {
  id delegate;
  NSMutableArray *gamepads;
}

@property (assign) id delegate;

- (void)listen;

@end
