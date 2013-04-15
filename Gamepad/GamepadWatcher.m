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
  IOUSBInterfaceInterface300 **interf;
  UInt32 maxPacketSize;
  int pipe;
  char bytes[];
} Transfer;

void gotData(void *refcon, IOReturn result, void *arg0) {
  UInt32 bytesRead = (UInt32)arg0;
  Transfer *xfer = (Transfer *)refcon;

//  UInt8 c, sc, p;
//  IOUSBInterfaceInterface300 **interf = xfer->interf;
//  (*interf)->GetInterfaceClass(interf, &c);
//  (*interf)->GetInterfaceSubClass(interf, &sc);
//  (*interf)->GetInterfaceProtocol(interf, &p);
//  
//  printf("data from pipe %d class %d subclass %d protocol %d", xfer->pipe, c, sc, p);
  

  
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
    
    // name is 'Controller'
//    io_name_t name;
//    kr = IORegistryEntryGetName(service, name);
//    if (kr != KERN_SUCCESS) name[0] = '\0';
//    
//    NSLog(@"name: %s", name);
    
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
    

    // If its useful, the deviceId can be used to track controllers through
    // reconnections.
//    UInt32 deviceId;
//    (*_dev)->GetLocationID(_dev, &deviceId);
//    NSLog(@"device location id %d", deviceId);
    
    // Open the device and configure it.
    kr = (*_dev)->USBDeviceOpen(_dev);
    assert(kr == KERN_SUCCESS);
    
    // Xbox controllers have one configuration option which has configuration value 1.
    // I could check that the device has the configuration value, but I may as well
    // just try and set it and fail out if it couldn't be configured.
//    UInt8 config, numConfig = 0;
//    kr = (*dev)->GetConfiguration(dev, &config);
//    assert(kr == KERN_SUCCESS);
//    NSLog(@"set to Configuration %d", config);
//    kr = (*dev)->GetNumberOfConfigurations(dev, &numConfig);
//    assert(numConfig >= 1);
//    assert(kr == KERN_SUCCESS);
    
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
      if (i == 1) {
        assert(direction == kUSBIn);
        
        Transfer *xfer = malloc(sizeof(Transfer) + maxPacketSize);
        xfer->owner = self;
        xfer->interf = _interf;
        xfer->pipe = i;
        xfer->maxPacketSize = maxPacketSize;
        (*_interf)->ReadPipeAsync(_interf, i, xfer->bytes, maxPacketSize, gotData, xfer);

      } else if (i == 2) {
        assert(direction == kUSBOut);
        NSLog(@"Writing control bytes");
        char buf2[]={0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}; // large, small
        (*_interf)->WritePipe(_interf, i, buf2, sizeof(buf2));
        
        char buf[]={0x01,0x03, 0x0a}; // 0xa = rotating
        (*_interf)->WritePipe(_interf, i, buf, sizeof(buf));
      }
    }
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
