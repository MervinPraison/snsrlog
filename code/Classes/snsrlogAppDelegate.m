// The BSD 2-Clause License (aka "FreeBSD License")
// 
// Copyright (c) 2012, Benjamin Thiel
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met: 
// 
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer. 
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//
//  snsrlogAppDelegate.m
//  snsrlog
//
//  Created by Benjamin Thiel on 06.03.11.
//

#import "snsrlogAppDelegate.h"
#import "AudioInput.h"
#import "Accelerometer.h"
#import "Gyroscope.h"
#import "CompassAndGPS.h"
#import "Preferences.h"
#import "ConsoleLogger.h"
#import "DCIntrospect.h"

@implementation snsrlogAppDelegate

@synthesize window;

//indicates whether preferencesChanged had already been called by the notification
static BOOL preferencesChangedAlreadyCalled = NO;

//is called before any other method (even init) of this class
+(void)initialize {
    
    //before performing further setup, we need to make sure that the preferences are
    //initialized with default values. The defaults specified in the Settings.bundle
    //are only registered if the settings app has been opened prior to application launch.
    //We need to assume that this has not happened, so we do it manually.
    [Preferences registerDefaults];
}

- (id)init {
    
    self = [super init];
    
    if (self != nil) {
        
        myTabBarController = nil;
        liveViewController = nil;
        
        preventAutoLockCounter = 0;
        proximitySensingCounter = 0;
        
        //determine proximity sensor availability by turning it on and off again
        [UIDevice currentDevice].proximityMonitoringEnabled = YES;
        isProximitySensingAvailable = [[UIDevice currentDevice] isProximityMonitoringEnabled];
        [UIDevice currentDevice].proximityMonitoringEnabled = NO;
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [liveViewController release];
    [recordingViewController release];
    [archiveViewController release];
    [streamingViewController release];
    
    [proximityHUD release];
    [lockView release];
    
    [myTabBarController release];
    [window release];
    [super dealloc];
}

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    myTabBarController = [[UITabBarController alloc] init];
    
    //create the view controllers
    liveViewController = [[LiveViewController alloc] initWithNibName:nil
                                                              bundle:nil];
    
    //recording
    RecordingViewController *actualRecordingViewController = [[RecordingViewController alloc] init];
    actualRecordingViewController.title = @"Recording";
    recordingViewController = [[UINavigationController alloc] initWithRootViewController:[actualRecordingViewController autorelease]];
    
    //archive
    archiveViewController = [[ArchiveViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    //streaming
    StreamingMainViewController *actualStreamingVC = [[StreamingMainViewController alloc] init];
    actualStreamingVC.title = @"Streaming";
    streamingViewController = [[UINavigationController alloc] initWithRootViewController:[actualStreamingVC autorelease]];

    //make navigation bars opaque on iOS>=7
    NSArray *navBars = @[recordingViewController.navigationBar,
                         streamingViewController.navigationBar];
    for (UINavigationBar *navBar in navBars) {
        
        if ([navBar respondsToSelector:@selector(setTranslucent:)]) {
            
            navBar.translucent = NO;
        }
    }
    
    
    //listen for changes in preferences. This might also yield to a call of preferencesChanged, hence the view controllers have to be initialized
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferencesChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioInputAvailabilityChanged:)
                                                 name:AudioInputAvailabilityChangedNotification
                                               object:nil];
    
    //create the icons for the tab bar
    UITabBarItem *liveControllerIcon = [[UITabBarItem alloc] initWithTitle:@"Live"
                                                                     image:[UIImage imageNamed:@"liveViewIcon.png"]
                                                                       tag:0];
    UITabBarItem *recordingControllerIcon = [[UITabBarItem alloc] initWithTitle:@"Recording"
                                                                     image:[UIImage imageNamed:@"recordingIcon.png"]
                                                                       tag:1];
    UITabBarItem *archiveControllerIcon = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemHistory
                                                                                       tag:2];
    UITabBarItem *streamingControllerIcon = [[UITabBarItem alloc] initWithTitle:@"Streaming"
                                                                          image:[UIImage imageNamed:@"streamingIcon.png"]
                                                                            tag:3];
    
    liveViewController.tabBarItem = [liveControllerIcon autorelease];
    recordingViewController.tabBarItem = [recordingControllerIcon autorelease];
    archiveViewController.tabBarItem = [archiveControllerIcon autorelease];
    streamingViewController.tabBarItem = [streamingControllerIcon autorelease];
    
    //create a navigation controller, so that a navigation bar appears in archiveViewController
    UINavigationController *archiveNavigationViewController = [[[UINavigationController alloc] initWithRootViewController:archiveViewController] autorelease];
    
    //collect the tabs to be shown in the tab bar
    NSArray *tabs = [NSArray arrayWithObjects:
                     liveViewController,
                     recordingViewController,
                     archiveNavigationViewController,
                     streamingViewController,
                     nil];
    myTabBarController.viewControllers = tabs;
    //set the tab to be shown first
    myTabBarController.selectedViewController = liveViewController;
    
    //prevent views from protruding underneath the tab bar (default on iOS7 and newer)
    UITabBar *tabBar = myTabBarController.tabBar;
    if ([tabBar respondsToSelector:@selector(setTranslucent:)]) {
        
        tabBar.translucent = NO;
    }
    
    //everything is set up, let's show it!
    [self.window setRootViewController:myTabBarController];
    [self.window makeKeyAndVisible];
    
    //create the HUD
    proximityHUD = [[MBProgressHUD alloc] initWithWindow:self.window];
    lockView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LockOpen.png"]];
    proximityHUD.customView = lockView;
    proximityHUD.mode = MBProgressHUDModeCustomView;
    proximityHUD.animationType = MBProgressHUDAnimationZoom;
    
    //we don't interact with the HUD and want underlying views to be able to react to events
    proximityHUD.userInteractionEnabled = NO;
    
    [self.window addSubview:proximityHUD];

    //avoid duplicate calls of preferencesChanged
    if (!preferencesChangedAlreadyCalled) {
        
        //start/stop the sensor and show/hide the live views
        [self preferencesChanged:nil];
    }
    
    // always call after makeKeyAndDisplay.
#if TARGET_IPHONE_SIMULATOR
    [[DCIntrospect sharedIntrospector] start];
#endif
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
    
    NSLog(@"applicationWillTerminate:");
    //close the files correctly, as cached data may be lost otherwise
    [(RecordingViewController *)recordingViewController.visibleViewController stopRecording];
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

//MARK: - own methods

//start and stop sensor and live view according to preferences
- (void)preferencesChanged:(NSNotification *)notification {
    
    if (preferencesChangedAlreadyCalled) NSLog(@"preferences changed");
    preferencesChangedAlreadyCalled = YES;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    //sensors to be switched on
    BOOL accelerometerON = [userDefaults boolForKey:kAccelerometerOn];
    BOOL gyroscopeON = [userDefaults boolForKey:kGyroscopeOn];
    BOOL microphoneON = [userDefaults boolForKey:kMicrophoneOn];
    BOOL gpsON = [userDefaults boolForKey:kGpsOn];
    BOOL compassON = [userDefaults boolForKey:kCompassOn];
    
    //show/hide the live views
    liveViewController.showAccelerometer = accelerometerON && [[Accelerometer sharedInstance] isAvailable] && [userDefaults boolForKey:kShowAccelerometer];
    liveViewController.showAudio = microphoneON && [[AudioInput sharedInstance] isAvailable] && [userDefaults boolForKey:kShowMicrophone];
    liveViewController.showCompass = compassON && [[CompassAndGPS sharedInstance] isAvailable] && [userDefaults boolForKey:kShowCompass];
    liveViewController.showGPS = gpsON && [[CompassAndGPS sharedInstance] isAvailable] && [userDefaults boolForKey:kShowGps];
    liveViewController.showGyroscope = gyroscopeON && [[Gyroscope sharedInstance] isAvailable] && [userDefaults boolForKey:kShowGyroscope];
    
#if TARGET_IPHONE_SIMULATOR
    //show all views
    liveViewController.showAccelerometer = YES;
    liveViewController.showAudio = YES;
    liveViewController.showCompass = YES;
    liveViewController.showGPS = YES;
    liveViewController.showGyroscope = YES;
#endif
    
    //set new frequency (implicitly also sets the Gyroscope frequency)
    [Accelerometer sharedInstance].frequency = [[NSUserDefaults standardUserDefaults] integerForKey:kAccelerometerFrequency];
    
    //turn sensors on/off    
    if (accelerometerON) {
        [[Accelerometer sharedInstance] start];
    } else  {
        [[Accelerometer sharedInstance] stop];
    }

    if (gyroscopeON) {
        [[Gyroscope sharedInstance] start];
    } else  {
        [[Gyroscope sharedInstance] stop];
    }
    
    if (microphoneON) {
        [[AudioInput sharedInstance] start];
    } else  {
        [[AudioInput sharedInstance] stop];
    }
    
    if (gpsON) {
        [[CompassAndGPS sharedInstance] startGPS];
    } else  {
        [[CompassAndGPS sharedInstance] stopGPS];
    }
    
    if (compassON) {
        [[CompassAndGPS sharedInstance] startCompass];
    } else  {
        [[CompassAndGPS sharedInstance] stopCompass];
    }
}

-(void)audioInputAvailabilityChanged:(NSNotification *)notification {
    
    if ([[AudioInput sharedInstance] isAvailable]) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        BOOL microphoneON = [userDefaults boolForKey:kMicrophoneOn];
        
        //turn on/off the microphone
        if (microphoneON) {
            [[AudioInput sharedInstance] start];
        } else  {
            [[AudioInput sharedInstance] stop];
        }
        
        //show or hide the audio view
        liveViewController.showAudio = microphoneON && [userDefaults boolForKey:kShowMicrophone];
        
    } else {
        
        [[AudioInput sharedInstance] stop];
        liveViewController.showAudio = NO;
    }
}

-(void)enableProximitySensing:(BOOL)enable {
    
    if (isProximitySensingAvailable) {
        
        if (enable) {
            
            proximitySensingCounter++;
            
        } else {
            
            proximitySensingCounter--;
        }
        
        BOOL shouldEnable = (proximitySensingCounter > 0) ? YES : NO;
        
        if (shouldEnable != [UIDevice currentDevice].isProximityMonitoringEnabled) {
            
            [UIDevice currentDevice].proximityMonitoringEnabled = shouldEnable;
            
            //show the HUD
            proximityHUD.labelText = [NSString stringWithFormat:@"Auto-Locking: %@", (shouldEnable ? @"ON" : @"OFF")];
            proximityHUD.detailsLabelText = (shouldEnable ? @"You may put the device in your pocket." : @"");
            lockView.image = (shouldEnable ? [UIImage imageNamed:@"LockClosed.png"] : [UIImage imageNamed:@"LockOpen.png"]);
            
            [proximityHUD show:YES];
            [proximityHUD hide:NO
                    afterDelay:(shouldEnable ? 2.5 : 1)];
        }
    }
}

-(void)preventAutoLock:(BOOL)enable {
    
    if (enable) {
        
        preventAutoLockCounter++;
        
    } else {
        
        preventAutoLockCounter--;
    }
    
    [UIApplication sharedApplication].idleTimerDisabled = (preventAutoLockCounter > 0) ? YES : NO;
}


@end
