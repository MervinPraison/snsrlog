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
//  RecordingViewController.h
//  snsrlog
//
//  Created by Benjamin Thiel on 24.05.11.
//

#import <UIKit/UIKit.h>
#import "BTFancyButton.h"
#import "Labels.h"
#import "LockScreenViewController.h"
#import "FileWriter.h"

@interface RecordingViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate, LockScreenDelegate>
{
    //weak reference
    Labels *labels;
    int lastLabel;
    
    FileWriter *fileWriter;
}

@property (nonatomic, retain) IBOutlet UITableView *myTableView;
@property (nonatomic, retain) IBOutlet BTFancyButton *recordingButton;
@property (nonatomic, retain) IBOutlet BTFancyButton *lockButton;

@property (nonatomic, retain) UIBarButtonItem *removeLabelButton;
@property (nonatomic, retain) UIBarButtonItem *addLabelButton;

-(IBAction)recordingPressed:(BTFancyButton *)sender;
-(IBAction)lockScreen:(UIButton *)sender;
-(void)removeLabels:(UIBarButtonItem *)sender;
-(void)addLabel:(UIBarButtonItem *)sender;

//used to listen for label changes
-(void)didReceiveChangeToLabel:(int)label timestamp:(NSTimeInterval)timestamp;

-(void)preferencesChanged:(NSNotification *)notification;

//AppDelegate would like to be able to stop recording when the app terminates
-(void)stopRecording;

@end
