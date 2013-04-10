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


@implementation Gamepad

- (void)processBytes:(char *)bytes ofLength:(UInt32)length {
  UInt8 type = bytes[0];
  UInt8 len = bytes[1];
  
  if (type != 0) {

    printf("weird packet: ");
    for (int i = 0; i < length; i++) {
      printf("%2x ", (unsigned char)bytes[i]);
    }
    printf("\n");

    // I don't understand what its talking about. Ignore the packet.
    return;
  }
  if (len != 20 || length != 20) {
    NSLog(@"Er, weird length. Ignoring.");
    return;
  }
  
  for (int i = 2; i < length; i++) {
    printf("%2x ", (unsigned char)bytes[i]);
  }
  printf("\n");
}

typedef struct {
  Gamepad *owner;
  IOUSBInterfaceInterface550 **interf;
  UInt32 maxPacketSize;
  int pipe;
  char bytes[];
} Transfer;

void gotData(void *refcon, IOReturn result, void *arg0) {
  UInt32 bytesRead = (UInt32)arg0;
  Transfer *xfer = (Transfer *)refcon;

  if (result != kIOReturnSuccess) return;
  [xfer->owner processBytes:xfer->bytes ofLength:bytesRead];
  
  // Queue up another read.
  (*xfer->interf)->ReadPipeAsync(xfer->interf, xfer->pipe, xfer->bytes, xfer->maxPacketSize, gotData, xfer);
}

- (id)initWithService:(io_service_t)service {
  self = [super init];
  if (self) {
    NSLog(@"init gamepad %d", service);
    
    kern_return_t kr;
    io_name_t name;
    kr = IORegistryEntryGetName(service, name);
    if (kr != KERN_SUCCESS) name[0] = '\0';
    
    NSLog(@"name: %s", name);
    
    IOCFPlugInInterface **plugin;
    SInt32 score;
    kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
    assert(kr == KERN_SUCCESS);
    
    IOObjectRelease(service);
    
    IOUSBDeviceInterface500 **dev;
    (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID500), (LPVOID *)&dev);
    
    (*plugin)->Release(plugin);
    
    UInt32 deviceId;
    (*dev)->GetLocationID(dev, &deviceId);
    NSLog(@"device location id %d", deviceId);
    
    kr = (*dev)->USBDeviceOpen(dev);
    assert(kr == KERN_SUCCESS);
    
    UInt8 config, numConfig = 0;
    (*dev)->GetConfiguration(dev, &config);
    NSLog(@"set to Configuration %d", config);
    kr = (*dev)->GetNumberOfConfigurations(dev, &numConfig);
    assert(numConfig >= 1);
    NSLog(@"out of %d", numConfig);
    
    IOUSBConfigurationDescriptorPtr configDesc;
    (*dev)->GetConfigurationDescriptorPtr(dev, 0, &configDesc);
    (*dev)->SetConfiguration(dev, configDesc->bConfigurationValue);
    
    
    IOUSBFindInterfaceRequest req;
    req.bInterfaceClass = req.bInterfaceSubClass = req.bInterfaceProtocol = req.bAlternateSetting = kIOUSBFindInterfaceDontCare;
    
    io_iterator_t iter;
    (*dev)->CreateInterfaceIterator(dev, &req, &iter);
    
    io_service_t usbInterface;
    while ((usbInterface = IOIteratorNext(iter))) {
      IOCFPlugInInterface **pluginInterface;
      kr = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score);
      assert(kr == KERN_SUCCESS);
      
      IOObjectRelease(usbInterface);
      
      IOUSBInterfaceInterface550 **interf;
      (*pluginInterface)->QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID550), (LPVOID *)&interf);
      
      (*pluginInterface)->Release(pluginInterface);
      
      // p = 1: buttons, LEDs and rumble pack.
      // p = 2: chatpad
      // p = 3: ????
      UInt8 c, sc, p;
      (*interf)->GetInterfaceClass(interf, &c);
      (*interf)->GetInterfaceSubClass(interf, &sc);
      (*interf)->GetInterfaceProtocol(interf, &p);
      NSLog(@"interf class:%d, subclass:%d, protocol:%d", c, sc, p);
      
//      if (p != 1) continue;
      // Actually open the interface.
      kr = (*interf)->USBInterfaceOpen(interf);
      assert(kr == KERN_SUCCESS);

      UInt8 numEndpoints;
      kr = (*interf)->GetNumEndpoints(interf, &numEndpoints);
      assert(kr == KERN_SUCCESS);
    
      NSLog(@"interface has %d endpoints", numEndpoints);
      
      CFRunLoopSourceRef source;
      kr = (*interf)->CreateInterfaceAsyncEventSource(interf, &source);
      assert(kr == KERN_SUCCESS);
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
      
      for (int i = 1; i <= numEndpoints; i++) {
        UInt8 direction;
        UInt8 number;
        UInt8 transferType;
        UInt16 maxPacketSize;
        UInt8 interval;
        
        kr = (*interf)->GetPipeProperties(interf,
                                          i, &direction,
                                          &number, &transferType,
                                          &maxPacketSize, &interval);
        NSLog(@"pipe %d direction %d type %d size %d", i, direction, transferType, maxPacketSize);
        
        if (direction == kUSBIn) {
//          IOReturn (*ReadPipeAsync)(void *self, UInt8 pipeRef, void *buf, UInt32 size, IOAsyncCallback1 callback, void *refcon);

          Transfer *xfer = malloc(sizeof(Transfer) + maxPacketSize);
          xfer->owner = self;
          xfer->interf = interf;
          xfer->pipe = i;
          xfer->maxPacketSize = maxPacketSize;
          (*interf)->ReadPipeAsync(interf, i, xfer->bytes, maxPacketSize, gotData, xfer);
        } else if (direction == kUSBOut) {
          
          if (p == 1 && i == 2) {
            NSLog(@"Writing control bytes");
            char buf2[]={0x00, 0x08, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00}; // large, small
            (*interf)->WritePipe(interf, i, buf2, sizeof(buf2));

            char buf[]={0x01,0x03, 0x0a}; // 0xa = rotating
            (*interf)->WritePipe(interf, i, buf, sizeof(buf));
            

          }
        }
//        kUSBOut
      }
    }
    
    
//    IOServiceAddInterestNotification
    
  }
  return self;
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
