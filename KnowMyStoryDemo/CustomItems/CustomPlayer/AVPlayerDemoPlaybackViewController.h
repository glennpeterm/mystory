/*
     File: AVPlayerDemoPlaybackViewController.h
 Abstract: UIViewController managing a playback view, thumbnail view, and associated playback UI.
  Version: 1.3
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */


#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class AVPlayer;
@class AVPlayerDemoPlaybackView;

@interface AVPlayerDemoPlaybackViewController : UIViewController
{
@private
	IBOutlet AVPlayerDemoPlaybackView* mPlaybackView;
	
	IBOutlet UISlider* mScrubber;
    IBOutlet UIToolbar *mToolbar;
    IBOutlet UIBarButtonItem *mPlayButton;
    IBOutlet UIBarButtonItem *mStopButton;

	float mRestoreAfterScrubbingRate;
	BOOL seekToZeroBeforePlay;
	id mTimeObserver;
	BOOL isSeeking;
    
    BOOL isTrimView;

	NSURL* mURL;
    
	AVPlayer* mPlayer;
    AVPlayerItem * mPlayerItem;
    
    
}

#pragma mark Singleton Methods
+ (AVPlayerDemoPlaybackViewController *)sharedInstance;

@property (nonatomic, copy) NSURL* URL;
@property (readwrite, strong, setter=setPlayer:, getter=player) AVPlayer* mPlayer;
@property (strong) AVPlayerItem* mPlayerItem;
@property int draggingSlider;
@property BOOL isTrimView;

@property (nonatomic, strong) IBOutlet AVPlayerDemoPlaybackView *mPlaybackView;
@property (nonatomic, strong) IBOutlet UIToolbar *mToolbar;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *mPlayButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *mStopButton;
@property (nonatomic, strong) IBOutlet UISlider* mScrubber;
@property (weak, nonatomic) IBOutlet UIButton *gobackButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

@property (weak, nonatomic) IBOutlet UIView *progressView;
@property (weak, nonatomic) IBOutlet UIImageView *progressThumbSlider;
@property (weak, nonatomic) IBOutlet UIView *progressTrack;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *TotalTimeLabel;
@property (weak, nonatomic) IBOutlet UIView *progressBarView;

//Abdu Jan 27
@property double startMarkerTime;
@property double endMarkerTime;

- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;
//- (IBAction)showMetadata:(id)sender;
- (IBAction)goBackButtonPressed:(id)sender;
- (IBAction)playStopButtonPressed:(UIButton *)sender;

-(void)setCurrentSeekPosition:(double)seconds;
-(void)prepareForTrimPreviewWithURL:(NSURL *)videoURL;
-(void)prepareForRecordPreviewWithURL:(NSURL *)videoURL;

-(void)stopPlayBack;

-(void)configureView;
-(void)hideAndStopViewActions;

@end
