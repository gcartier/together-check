/* gcc check.m -o check `pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0` -framework Cocoa
 */

#import <Cocoa/Cocoa.h>

#import <AVFoundation/AVFoundation.h>

#include <gst/gst.h>

#include <stdio.h>


NSWindow* window;
NSView* view;

NSString* feedbackMessage = @"Run test with Command-D";


@interface MyApplication : NSApplication
{
    bool shouldKeepRunning;
}

- (void)run;
- (void)terminate:(id)sender;
- (void)testDevices:(id)sender;
- (void)testMicrophone:(id)sender;
- (void)testCamera:(id)sender;

@end

@implementation MyApplication

- (void)run
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
 
    [self finishLaunching];

    shouldKeepRunning = YES;
    do
    {
        NSEvent* event =
            [self
                nextEventMatchingMask:NSEventMaskAny
                            untilDate:[NSDate distantFuture]
                            inMode:NSDefaultRunLoopMode
                            dequeue:YES];
 
        [self sendEvent:event];
        [self updateWindows];
        
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
    } while (shouldKeepRunning);
 
    [pool release];
}

bool processOne()
{
    NSEvent* event;
  
    event = [NSApp nextEventMatchingMask:NSEventMaskAny
                               untilDate:[NSDate distantPast]
                                  inMode:NSDefaultRunLoopMode
                                 dequeue:YES];

    if (event)
    {
        [NSApp sendEvent:event];
        
        return true;
    }
    else
    {
        return false;
    }
}

void processAll()
{
    while (processOne());
}

- (void)terminate:(id)sender
{
    shouldKeepRunning = NO;
}

bool GStreamerInited = false;

void initGStreamer()
{
    if (GStreamerInited)
        return;
    
    char contents[1024];
    char libraries[1024];
    char gstreamer[1024];
    char registry[1024];
    char syspath[1024];
    
    uint32_t maxLength = 1023;
    _NSGetExecutablePath(contents, &maxLength);
    unsigned long len = strlen(contents);
    contents[len - 11] = 0;
    
    strcpy(libraries, contents);
    strcat(libraries, "Libraries/");
    
    strcpy(gstreamer, libraries);
    strcat(gstreamer, "gstreamer/");
    
    strcpy(registry, gstreamer);
    strcat(registry, "registry.bin");
    
    strcpy(syspath, gstreamer);
    strcat(syspath, "lib/gstreamer-1.0");
    
    setenv("GST_REGISTRY", registry, 1);
    setenv("GST_PLUGIN_SYSTEM_PATH", syspath, 1);
    
    gst_registry_fork_set_enabled(0);
    gst_init(NULL, NULL);
    
    GStreamerInited = true;
}

void feedback(NSString* message)
{
    feedbackMessage = message;
    [feedbackMessage retain];
    
    if ([NSThread isMainThread]) {
        [view setNeedsDisplayInRect:[view frame]];
        [view displayIfNeeded];
        
        processAll();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [view setNeedsDisplayInRect:[view frame]];
            [view displayIfNeeded];
        
            processAll();
        });
    }
}

- (void)testDevices:(id)sender
{
    initGStreamer();
    
    feedback(@"Scanning Devices...");
    [NSThread sleepForTimeInterval:.5];
    
    GstDeviceMonitor *monitor;
    
    monitor = gst_device_monitor_new();
    gst_device_monitor_add_filter(monitor, NULL, NULL);
    GList *devices = gst_device_monitor_get_devices(monitor);
    int count = g_list_length(devices);
    
    feedback([NSString stringWithFormat: @"Found %d devices", count]);
}

- (void) testMicrophone:(id)sender
{
    initGStreamer();
    
    feedback(@"Requesting Microphone Authorization...");
    [NSThread sleepForTimeInterval:.5];
    
    GstElement* pipeline;
    pipeline = gst_parse_launch("osxaudiosrc ! fakesink", NULL);
    gst_element_set_state(pipeline, GST_STATE_PLAYING);
    // gst_element_set_state(pipeline, GST_STATE_NULL);
    // gst_object_unref(pipeline);
    
    feedback(@"Done");
}

- (void) testCamera:(id)sender
{
    initGStreamer();
    
    if (@available(macOS 10.14, *)) {
    feedback(@"Requesting Camera Authorization...");
    [NSThread sleepForTimeInterval:.5];
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
    {
        case AVAuthorizationStatusAuthorized:
        {
            feedback(@"Authorized");
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    feedback(@"Granted");
                }
                else {
                    feedback(@"Denied");
                }
            }];
            break;
        }
        case AVAuthorizationStatusDenied:
        {
            feedback(@"Denied");
            return;
        }
        case AVAuthorizationStatusRestricted:
        {
            feedback(@"Restricted");
            return;
        }
    }
    }
}
@end


@interface TestView: NSView
{
}
@end

@implementation TestView

- (void)drawRect:(NSRect)dirtyRect
{
    int width, height;

    width = [self bounds].size.width;
    height = [self bounds].size.height;
    
    [[NSColor blueColor] set];
    NSRectFill([self bounds]);

    NSMutableDictionary *drawStringAttributes = [[NSMutableDictionary alloc] init];
    [drawStringAttributes setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    [drawStringAttributes setValue:[NSFont fontWithName:@"American Typewriter" size:24] forKey:NSFontAttributeName];
    NSShadow *stringShadow = [[NSShadow alloc] init];
    [stringShadow setShadowColor:[NSColor blackColor]];
    NSSize shadowSize;
    shadowSize.width = 2;
    shadowSize.height = -2;
    [stringShadow setShadowOffset:shadowSize];
    [stringShadow setShadowBlurRadius:6];
    [drawStringAttributes setValue:stringShadow forKey:NSShadowAttributeName];    
    [stringShadow release];
    
    NSSize stringSize = [feedbackMessage sizeWithAttributes:drawStringAttributes];
    NSPoint centerPoint;
    centerPoint.x = (dirtyRect.size.width / 2) - (stringSize.width / 2);
    centerPoint.y = dirtyRect.size.height / 2 - (stringSize.height / 2);
    [feedbackMessage drawAtPoint:centerPoint withAttributes:drawStringAttributes];
    [drawStringAttributes release];
}

@end


void createMenuBar()
{
    NSMenu* bar = [[NSMenu alloc] init];
    [NSApp setMainMenu:bar];

    NSMenuItem* appMenuItem =
        [bar addItemWithTitle:@"" action:NULL keyEquivalent:@""];
    NSMenu* appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    [appMenu addItemWithTitle:@"Test Devices"
                       action:@selector(testDevices:)
                keyEquivalent:@"d"];
    [appMenu addItemWithTitle:@"Test Microphone"
                       action:@selector(testMicrophone:)
                keyEquivalent:@"m"];
    [appMenu addItemWithTitle:@"Test Camera"
                       action:@selector(testCamera:)
                keyEquivalent:@"c"];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
  
    NSMenuItem* windowMenuItem =
        [bar addItemWithTitle:@"" action:NULL keyEquivalent:@""];
    NSMenu* windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [NSApp setWindowsMenu:windowMenu];
    [windowMenuItem setSubmenu:windowMenu];

    [windowMenu addItemWithTitle:@"Miniaturize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
}


void createWindow()
{
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(150, 150, 600, 400)
                                         styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
  
    view = [[TestView alloc] init];
    
    [window setTitle:@"Check"];
    [window cascadeTopLeftFromPoint:NSMakePoint(20, 20)];
    [window setContentView: view];
    [window makeKeyAndOrderFront:window];
}


int main(int argc, char **argv)
{
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];

    [MyApplication sharedApplication];
    
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    createMenuBar();
  
    createWindow();

    [NSApp activateIgnoringOtherApps:YES];
    [NSApp run];

    [pool release];
  
    return 0;
}
