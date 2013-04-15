//
//  GamepadWatcher.m
//  Gamepad
//
//  Created by Joseph Gentle on 5/04/13.
//
//

#import "GamepadWatcher.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
//#include <IOKit/IOMessage.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/USB.h>

#define READ_ENDPOINT 1
#define CONTROL_ENDPOINT 2

typedef enum {
  CONTROL_MESSAGE_SET_RUMBLE = 0,
  CONTROL_MESSAGE_SET_LED = 1,
} XBOXControlMessageType;


typedef enum {
  STATUS_MESSAGE_BUTTONS = 0,
  STATUS_MESSAGE_LED = 1,
  STATUS_MESSAGE_UNKNOWN = 2,
  
  // Apparently this message tells you if the rumble pack is disabled in the controller. If
  // the rumble pack is disabled, vibration control messages have no effect.
  STATUS_MESSAGE_RUMBLE = 3,
} XBOXStatusMessageType;

@implementation Gamepad

@dynamic ledPattern;

- (void)readPacketOfLength:(UInt32)length {
  if (length < 2) return;
  
  XBOXStatusMessageType type = _read_buffer[0];
  if (_read_buffer[1] != length) {
    NSLog(@"Ignoring fragment");
    return;
  }
  
  switch (type) {
    case STATUS_MESSAGE_BUTTONS:
      for (int i = 2; i < length; i++) {
        printf("%2x ", (unsigned char)_read_buffer[i]);
      }
      printf("\n");
      break;
    case STATUS_MESSAGE_LED:
      _ledPattern = _read_buffer[2];
      if (delegate && [delegate respondsToSelector:@selector(gamepad:ledStatusKnown:)]) {
        [delegate gamepad:self ledStatusKnown:_ledPattern];
      }
      break;
      
    default:
      NSLog(@"ignoring packet of type %d", type);
      // Ignore!
      break;
  }
}

static void gotData(void *refcon, IOReturn result, void *arg0) {
  UInt32 bytesRead = (UInt32)arg0;
  Gamepad *g = (Gamepad *)refcon;

  // This will happen if the device was disconnected. The gamepad has probably been
  // destroyed. Ignore the bytes and don't requeue a read.
  if (result == kIOReturnAborted) return;
  else if (result != kIOReturnSuccess) {
    NSLog(@"Error reading gamepad data: %x", result);
    return;
  }
  
  [g readPacketOfLength:bytesRead];
  
  // Queue up another read.
  (*g->_interf)->ReadPipeAsync(g->_interf, READ_ENDPOINT, g->_read_buffer,
                                 g->_read_buffer_size, gotData, g);
}

- (id)initWithService:(io_service_t)service {
  self = [super init];
  if (self) {
    NSLog(@"init gamepad %d", service);
    
    kern_return_t kr;
    
    // First we need to make a PlugInInterface, which we can use in turn to get the DeviceInterface.
    IOCFPlugInInterface **plugin;
    SInt32 score; // Unused, but required for IOCreatePlugInInterfaceForService.
    kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
    assert(kr == KERN_SUCCESS);
    
    IOObjectRelease(service);
    service = 0;
    
    // use IOUSBDeviceStruct320 for support on MacOS 10.6.
    (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID320), (LPVOID *)&_dev);
    
    (*plugin)->Release(plugin);
    plugin = NULL;
    
    // Open the device and configure it.
    kr = (*_dev)->USBDeviceOpen(_dev);
    assert(kr == KERN_SUCCESS);
    
    // Xbox controllers have one configuration option which has configuration value 1.
    // I could check that the device has the configuration value, but I may as well
    // just try and set it and fail out if it couldn't be configured.
    IOUSBConfigurationDescriptorPtr configDesc;
    kr = (*_dev)->GetConfigurationDescriptorPtr(_dev, 0, &configDesc);
    assert(kr == KERN_SUCCESS);
    kr = (*_dev)->SetConfiguration(_dev, configDesc->bConfigurationValue);
    assert(kr == KERN_SUCCESS);
    
    // The device has 4 interfaces. They are used as follows:
    // Protocol 1:
    //  - Endpoint 1 (in) : Controller events, including button presses.
    //  - Endpoint 2 (out): Rumble pack and LED control
    // Protocol 2 has a single endpoint to read from a connected chatpad
    // Protocol 3 is used by a headset
    // The device also has an interface on subclass 253, protocol 10 with no endpoints.
    // It is unused.
    
    // For now, we just care about the two endpoints on protocol 1.
    // For more detail, see https://github.com/Grumbel/xboxdrv/blob/master/PROTOCOL
    IOUSBFindInterfaceRequest req;
    req.bInterfaceClass = 255;
    req.bInterfaceSubClass = 93;
    req.bInterfaceProtocol = 1;
    req.bAlternateSetting = kIOUSBFindInterfaceDontCare;
    
    io_iterator_t iter;
    kr = (*_dev)->CreateInterfaceIterator(_dev, &req, &iter);
    assert(kr == KERN_SUCCESS);
    
    // There should be exactly one usb interface which matches the requested settings.
    io_service_t usbInterface = IOIteratorNext(iter);
    assert(usbInterface);
    
    // We need to make an InterfaceInterface to communicate with the device endpoint.
    // This is the same process as earlier - first make a PluginInterface from the io_service
    // then make the InterfaceInterface from that.
    
    IOCFPlugInInterface **pluginInterface;
    kr = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score);
    assert(kr == KERN_SUCCESS);
    
    // Release the usb interface, and any subsequent interfaces returned by the iterator, if any.
    // (There shouldn't be any, but I don't want a future device to cause memory leaks.)
    do {
      IOObjectRelease(usbInterface);
    } while ((usbInterface = IOIteratorNext(iter)));
    
    // Actually create the interface.
    kr = (*pluginInterface)->QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID300), (LPVOID *)&_interf);
    
    (*pluginInterface)->Release(pluginInterface);
    
    // Actually open the interface.
    kr = (*_interf)->USBInterfaceOpen(_interf);
    assert(kr == KERN_SUCCESS);

    CFRunLoopSourceRef source;
    kr = (*_interf)->CreateInterfaceAsyncEventSource(_interf, &source);
    assert(kr == KERN_SUCCESS);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    
    // The interface should have two pipes. Pipe 1 with direction kUSBIn and pipe 2 with direction
    // kUSBOut. Both pipes should have type kUSBInterrupt.
    UInt8 numEndpoints;
    kr = (*_interf)->GetNumEndpoints(_interf, &numEndpoints);
    assert(kr == KERN_SUCCESS);
    assert(numEndpoints == 2);
    
    for (int i = 1; i <= numEndpoints; i++) {
      UInt8 direction;
      UInt8 number;
      UInt8 transferType;
      UInt16 maxPacketSize;
      UInt8 interval;
      
      kr = (*_interf)->GetPipeProperties(_interf,
                                        i, &direction,
                                        &number, &transferType,
                                        &maxPacketSize, &interval);
      
      assert(transferType == kUSBInterrupt);
      if (i == READ_ENDPOINT) {
        assert(direction == kUSBIn);
        
        
        _read_buffer = malloc(maxPacketSize);
        _read_buffer_size = maxPacketSize;
        
        (*_interf)->ReadPipeAsync(_interf, i, _read_buffer, _read_buffer_size, gotData, self);

      } else if (i == CONTROL_ENDPOINT) {
        assert(direction == kUSBOut);
        self.ledPattern = XBOX_LED_ALTERNATE_PATTERN;
      }
    }
  }
  return self;
}

- (void)dealloc {
  (*_interf)->Release(_interf);
  (*_dev)->Release(_dev);
  [super dealloc];
}

- (UInt32)getLocationId {
  // If its useful, the deviceId can be used to track controllers through
  // reconnections.
  UInt32 deviceId;
  IOReturn kr = (*_dev)->GetLocationID(_dev, &deviceId);
  if (kr != KERN_SUCCESS) return UINT32_MAX;
  
  return deviceId;
}

// The callback for writing data. Currently I don't really care about this, because
// its not like you care precicely when the controller started rumbling.
// arg0 contains the number of bytes written in this packet.
static void writeCallback(void *buffer, IOReturn result, void *arg0) {
  // Ignoring any errors sending data, because they will usually only occur when the
  // device is disconnected, in which case it really doesn't matter if the data got to the
  // controller or not.
  if (result != KERN_SUCCESS) {
//    NSLog(@"Error writing data");
  }
  
  free(buffer);
}

// Asynchronously write a message to the device's control interface.
- (void)sendControlMessage:(XBOXControlMessageType)message withBytes:(UInt8 *)bytes ofLength:(UInt32)payloadLength {
  // Its a bit wasteful allocating a buffer here. In theory, we could simply allocate a buffer in
  // the Gamepad class and reuse it with each writeBytes call. However, there are two problems with
  // that approach
  //  - Multiple calls to writeBytes would need to be queued, else a subsequent call would clobber
  //    the data sent in the first WritePipeAsync call
  //  - If a message is queued right before the gamepad object is deallocated, the buffer could not
  //    be deallocated.
  // Given there shouldn't be more than a few control packets per second, its simplest to just copy
  // the bytes here.
  UInt8 length = payloadLength + 2;
  UInt8 *buffer = malloc(length);
  buffer[0] = (UInt8)message;
  buffer[1] = length;
  memcpy(&buffer[2], bytes, payloadLength);
  (*_interf)->WritePipeAsync(_interf, CONTROL_ENDPOINT, buffer, (UInt32)length,
                             writeCallback, buffer);
}

- (XBOXLedPattern)ledPattern {
  return _ledPattern;
}

- (void)setLedPattern:(XBOXLedPattern)pattern {
  UInt8 buf[]={(UInt8)pattern};
  [self sendControlMessage:CONTROL_MESSAGE_SET_LED withBytes:buf ofLength:sizeof(buf)];
  _ledPattern = pattern;
}

- (void)setRumbleLarge:(UInt8)large small:(UInt8)small {
  UInt8 buf[]={0x00, large, small, 0x00, 0x00, 0x00};
  [self sendControlMessage:CONTROL_MESSAGE_SET_RUMBLE withBytes:buf ofLength:sizeof(buf)];
}

@end

@implementation GamepadWatcher
@synthesize delegate = delegate;

- (id)init {
  self = [super init];
  if (self) {
    gamepads = [[NSMutableArray alloc] initWithCapacity:4];
  }
  return self;
}

static const int32_t VENDOR_MICROSOFT = 0x045e;
static const int32_t PRODUCT_360_CONTROLLER = 0x028e;

- (void)pump:(io_iterator_t)iter {
  io_service_t ref;
  while ((ref = IOIteratorNext(iter))) {
    Gamepad *gamepad = [[Gamepad alloc] initWithService:ref];
    [gamepads addObject:gamepad];
    if ([delegate respondsToSelector:@selector(gamepadDidConnect:)]) {
      [delegate gamepadDidConnect:gamepad];
    }
    [gamepad release];
  }
}

static void _pump(void *_watcher, io_iterator_t iter) {
  [(GamepadWatcher *)_watcher pump:iter];
}

- (void)listen {
  
  CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
  CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorName),
                       CFNumberCreate(kCFAllocatorDefault,
                                      kCFNumberSInt32Type, &VENDOR_MICROSOFT));
  CFDictionarySetValue(matchingDict, CFSTR(kUSBProductName),
                       CFNumberCreate(kCFAllocatorDefault,
                                      kCFNumberSInt32Type, &PRODUCT_360_CONTROLLER));
  
  IONotificationPortRef port = IONotificationPortCreate(kIOMasterPortDefault);
  
  CFRunLoopSourceRef source = IONotificationPortGetRunLoopSource(port);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);

  io_iterator_t iter;
  
  IOReturn ret = IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, matchingDict,
                                                  _pump, self, &iter);
  if (ret != kIOReturnSuccess) {
    NSLog(@"error: %d", ret);
  }
  
  // Get all the initially connected gamepads
  [self pump:iter];
}

@end
