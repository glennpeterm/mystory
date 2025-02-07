/*
     File: AVPlayerDemoPlaybackViewController.m
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


#import "AVPlayerDemoPlaybackViewController.h"
#import "AVPlayerDemoPlaybackView.h"

#import "WizardViewController.h"
#import "TrimVideoViewController.h"

//#import "AVPlayerDemoMetadataViewController.h"

@interface AVPlayerDemoPlaybackViewController ()
- (void)play:(id)sender;
- (void)pause:(id)sender;
//- (void)showMetadata:(id)sender;
- (void)initScrubberTimer;
- (void)showPlayButton;
- (void)showStopButton;
- (void)syncScrubber;
- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;
- (BOOL)isScrubbing;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
//- (id)init;
- (void)dealloc;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)viewDidLoad;
- (void)viewWillDisappear:(BOOL)animated;
- (void)handleSwipe:(UISwipeGestureRecognizer*)gestureRecognizer;
- (void)syncPlayPauseButtons;
- (void)setURL:(NSURL*)URL;
- (NSURL*)URL;
@end

@interface AVPlayerDemoPlaybackViewController (Player)
- (void)removePlayerTimeObserver;
- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;

#pragma mark -
@implementation AVPlayerDemoPlaybackViewController

@synthesize mPlayer, mPlayerItem, mPlaybackView, mToolbar, mPlayButton, mStopButton, mScrubber;
@synthesize isTrimView;

static AVPlayerDemoPlaybackViewController *sharedInstance = nil;

#pragma mark -
#pragma mark Singleton Methods
+ (AVPlayerDemoPlaybackViewController *)sharedInstance
{
    if (sharedInstance == nil)
    {
        //sharedInstance = [[WizardViewController alloc] init];
    }
    
    return sharedInstance;
}
+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

#pragma mark Asset URL

- (void)setURL:(NSURL*)URL
{
    [[ActivityLoadingViewController sharedInstance] ShowLoadingIndicatorViewWithText:ACTIVITY_LOADING_TEXT_LOADING showProgress:NO onController:[WizardViewController sharedInstance]];
    
    mURL = [URL copy];
    
    /*
     Create an asset for inspection of a resource referenced by a given URL.
     Load the values for the asset key "playable".
     */
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
    
    NSArray *requestedKeys = @[@"playable"];
    
    /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
     ^{
         dispatch_async( dispatch_get_main_queue(),
                        ^{
                            /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                            [self prepareToPlayAsset:asset withKeys:requestedKeys];
                        });
     }];
}

- (NSURL*)URL
{
	return mURL;
}

#pragma mark -
#pragma mark Movie controller methods

#pragma mark
#pragma mark Button Action Methods

- (IBAction)play:(id)sender
{
	/* If we are at the end of the movie, we must seek to the beginning first 
		before starting playback. */
	if (YES == seekToZeroBeforePlay) 
	{
		seekToZeroBeforePlay = NO;
        [self.mPlayer seekToTime:CMTimeMakeWithSeconds(self.startMarkerTime, NSEC_PER_SEC)];
	}
    
    if (CMTimeGetSeconds([self.mPlayer currentTime]) >= self.endMarkerTime)
    {
         [self.mPlayer seekToTime:CMTimeMakeWithSeconds(self.startMarkerTime, NSEC_PER_SEC)];
    }

	[self.mPlayer play];
	
    [self showStopButton];    
}

- (IBAction)pause:(id)sender
{
    
	[self.mPlayer pause];
    [self stopPlayBack];
    [self showPlayButton];
}

-(void)stopAndRemoveVideo
{
    [self pause:nil];
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.mPlayerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.mPlayerItem removeObserver:self forKeyPath:@"status"];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.mPlayerItem];
        self.mPlayerItem = nil;
    }
}

/* Display AVMetadataCommonKeyTitle and AVMetadataCommonKeyCopyrights metadata. */
/*- (IBAction)showMetadata:(id)sender
{
	AVPlayerDemoMetadataViewController* metadataViewController = [[AVPlayerDemoMetadataViewController alloc] init];

	[metadataViewController setMetadata:[[[self.mPlayer currentItem] asset] commonMetadata]];
	
	[self presentViewController:metadataViewController animated:YES completion:NULL];

}*/

#pragma mark -
#pragma mark Play, Stop buttons

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    /*NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mStopButton];
    self.mToolbar.items = toolbarItems;*/
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    /*NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mPlayButton];
    self.mToolbar.items = toolbarItems;*/
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        [self showStopButton];
	}
	else
	{
        [self showPlayButton];        
	}
}

-(void)enablePlayerButtons
{
    self.mPlayButton.enabled = YES;
    self.mStopButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.mPlayButton.enabled = NO;
    self.mStopButton.enabled = NO;
}

#pragma mark -
#pragma mark Movie scrubber control

/* ---------------------------------------------------------
**  Methods to handle manipulation of the movie scrubber control
** ------------------------------------------------------- */

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
	double interval = .1f;	
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		return;
	} 
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([self.mScrubber bounds]);
		//interval = 0.5f * duration / width;
        interval = 0.01f * duration / width;
	}

	/* Update the scrubber during normal playback. */
	__weak AVPlayerDemoPlaybackViewController *weakSelf = self;
	mTimeObserver = [self.mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) 
								queue:NULL /* If you pass NULL, the main queue is used. */
								usingBlock:^(CMTime time) 
                                            {
                                                [weakSelf syncScrubber];
                                            }];
}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		mScrubber.minimumValue = 0.0;
		return;
	} 

	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
        double time = CMTimeGetSeconds([self.mPlayer currentTime]);
        if (time >=0)
        {
            float minValue = self.progressTrack.frame.origin.x;
            float maxValue = self.progressTrack.frame.size.width;
            double progressValue = (maxValue  * (time / duration)) + minValue;
            [self updateProgressWithValue:progressValue];
            [self updateCurrentTimeWithValue:time];
        }
        
        
        if (isTrimView)
        {
            if (time >= self.endMarkerTime)
            {
                [self pause:nil];
                seekToZeroBeforePlay =YES;
            }
        }
	}
}

-(void)updateProgressWithValue:(double)value
{
    [self.progressThumbSlider setCenter:CGPointMake(value, self.progressThumbSlider.center.y)];
    CGRect progressViewFrame = self.progressBarView.frame;
    
    float minValue = self.progressTrack.frame.origin.x;
    
    [self.progressBarView setFrame:CGRectMake(progressViewFrame.origin.x, progressViewFrame.origin.y,value-minValue,progressViewFrame.size.height)];
}

-(void)updateCurrentTimeWithValue:(double)time
{
    int Min = (int)time / 60;
    int Sec = (int)time % 60;
    NSString *timeString = [NSString stringWithFormat:@"%.2d:%.2d",Min,Sec];
    
    [self.currentTimeLabel setText:timeString];
}

-(void)updateTotalTimeWithValue:(double)time
{
    int Min = (int)time / 60;
    int Sec = (int)time % 60;
    NSString *timeString = [NSString stringWithFormat:@"%.2d:%.2d",Min,Sec];
    
    [self.TotalTimeLabel setText:timeString];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    
    if (!isTrimView)
    {
        CGPoint touchLocation = [touch locationInView:self.progressView];
        CGRect touchRect = CGRectMake(touchLocation.x - 10, touchLocation.y - 10, 20, 20);
        if (CGRectIntersectsRect(self.progressThumbSlider.frame, touchRect) == YES)
        {
            self.draggingSlider = 1;
            [self beginScrubbing:nil];
        }
        if(touchLocation.y < 0)
        {
            CGPoint touchLocationInFullView = [touch locationInView:self.mPlaybackView];
            if(!(CGRectContainsPoint(self.gobackButton.frame, touchLocationInFullView) == YES))
            {
                [self playStopButtonPressed:nil];
            }
        }
    }
    
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *aTouch = [touches anyObject];
    
    if (!isTrimView)
    {
        CGPoint location = [aTouch locationInView:self.progressView];
        
        float sliderX = location.x;
        if (self.draggingSlider == 1)
        {
            float minValue = self.progressTrack.frame.origin.x;
            float maxValue = minValue + self.progressTrack.frame.size.width;
            if (sliderX <= minValue)
            {
                sliderX = minValue;
            }
            else if (sliderX >= maxValue)
            {
                sliderX = maxValue;
            }
            
            [self updateProgressWithValue:sliderX];
            [self scrub:nil];
        }

    }
    
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!isTrimView)
    {
        self.draggingSlider = 0;
        [self endScrubbing:nil];
    }
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
	mRestoreAfterScrubbingRate = [self.mPlayer rate];
	[self.mPlayer setRate:0.f];
	
	/* Remove previous timer. */
	[self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
    if (!isSeeking)
	{
		isSeeking = YES;
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
            seekToZeroBeforePlay = NO;
            
            float minValue = self.progressTrack.frame.origin.x;
            float maxValue = minValue + self.progressTrack.frame.size.width;
			float value = self.progressThumbSlider.center.x;
			double time = duration * (value - minValue) / (maxValue - minValue);
			
            [self updateCurrentTimeWithValue:time];
            
			[self.mPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
				dispatch_async(dispatch_get_main_queue(), ^{
					isSeeking = NO;
				});
			}];
		}
	}
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
	if (!mTimeObserver)
	{
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) 
		{
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
            CGFloat width = self.progressTrack.frame.size.width;
            double tolerance = 0.01f * duration / width;
			
			__weak AVPlayerDemoPlaybackViewController *weakSelf = self;
			mTimeObserver = [self.mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:NULL usingBlock:
			^(CMTime time)
			{
				[weakSelf syncScrubber];
			}];
		}
	}

	if (mRestoreAfterScrubbingRate)
	{
		[self.mPlayer setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
	}
}

- (BOOL)isScrubbing
{
	return mRestoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    self.mScrubber.enabled = YES;
    [self.progressView setAlpha:1.0f];
    [self.progressView setUserInteractionEnabled:YES];
}

-(void)disableScrubber
{
    self.mScrubber.enabled = NO;
    [self.progressView setAlpha:0.5f];
    [self.progressView setUserInteractionEnabled:NO];
}


#pragma mark
#pragma mark View Controller

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		[self setPlayer:nil];
		
		[self setEdgesForExtendedLayout:UIRectEdgeAll];
        
        sharedInstance = self;
	}
	
	return self;
}
/*
- (id)init
{
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        return [self initWithNibName:@"AVPlayerDemoPlaybackView-iPad" bundle:nil];
	} 
    else 
    {
        return [self initWithNibName:@"AVPlayerDemoPlaybackView" bundle:nil];
	}
    return [self initWithNibName:@"AVPlayerDemoPlaybackView" bundle:nil];
}*/

- (void)viewDidUnload
{
    self.mPlaybackView = nil;
	
    self.mToolbar = nil;
    self.mPlayButton = nil;
    self.mStopButton = nil;
    self.mScrubber = nil;
	
	[super viewDidUnload];
}

- (void)viewDidLoad
{
    
    sharedInstance = self;
    
	[self setPlayer:nil];

    [self.mScrubber setFrame:CGRectMake(0, 0, self.mToolbar.frame.size.width - 20, self.mScrubber.frame.size.height)];
    UIBarButtonItem *scrubberItem = [[UIBarButtonItem alloc] initWithCustomView:self.mScrubber];
    self.mToolbar.items = @[scrubberItem];
	isSeeking = NO;
	[self initScrubberTimer];
	
	[self syncPlayPauseButtons];
	[self syncScrubber];

    [super viewDidLoad];
}

- (void)viewWillDisappear:(BOOL)animated
{
    KMSDebugLog();
	[self.mPlayer pause];
	[super viewWillDisappear:animated];
}


-(void)InitialiseView
{
}
-(void)configureView
{
    
}
-(void)hideAndStopViewActions
{
    [self stopAndRemoveVideo];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

-(void)setViewDisplayName
{
    /* Set the view title to the last component of the asset URL. */
    self.title = [mURL lastPathComponent];
    
    /* Or if the item has a AVMetadataCommonKeyTitle metadata, use that instead. */
	for (AVMetadataItem* item in ([[[self.mPlayer currentItem] asset] commonMetadata]))
	{
		NSString* commonKey = [item commonKey];
		
		if ([commonKey isEqualToString:AVMetadataCommonKeyTitle])
		{
			self.title = [item stringValue];
		}
	}
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
{
	UIView* view = [self view];
	UISwipeGestureRecognizerDirection direction = [gestureRecognizer direction];
	CGPoint location = [gestureRecognizer locationInView:view];
	
	if (location.y < CGRectGetMidY([view bounds]))
	{
		if (direction == UISwipeGestureRecognizerDirectionUp)
		{
			[UIView animateWithDuration:0.2f animations:
			^{
				[[self navigationController] setNavigationBarHidden:YES animated:YES];
			} completion:
			^(BOOL finished)
			{
				[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
			}];
		}
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
			[UIView animateWithDuration:0.2f animations:
			^{
				[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
			} completion:
			^(BOOL finished)
			{
				[[self navigationController] setNavigationBarHidden:NO animated:YES];
			}];
		}
	}
	else
	{
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
            if (![self.mToolbar isHidden])
			{
				[UIView animateWithDuration:0.2f animations:
				^{
					[self.mToolbar setTransform:CGAffineTransformMakeTranslation(0.f, CGRectGetHeight([self.mToolbar bounds]))];
				} completion:
				^(BOOL finished)
				{
					[self.mToolbar setHidden:YES];
				}];
			}
		}
		else if (direction == UISwipeGestureRecognizerDirectionUp)
		{
            if ([self.mToolbar isHidden])
			{
				[self.mToolbar setHidden:NO];
				
				[UIView animateWithDuration:0.2f animations:
				^{
					[self.mToolbar setTransform:CGAffineTransformIdentity];
				} completion:^(BOOL finished){}];
			}
		}
	}
}

- (void)dealloc
{
	[self removePlayerTimeObserver];
	
	[self.mPlayer removeObserver:self forKeyPath:@"rate"];
	[mPlayer.currentItem removeObserver:self forKeyPath:@"status"];
	
	[self.mPlayer pause];
}

- (IBAction)goBackButtonPressed:(id)sender
{
    [self removePlayerTimeObserver];
    [self.mPlayer pause];
    [self.playButton setSelected:NO];
    [self.playButton setHidden:NO];
    [[[WizardViewController sharedInstance] previewPlayerContainerView] setHidden:YES];
}

- (IBAction)playStopButtonPressed:(UIButton *)sender
{
    [self.playButton setHidden:!self.playButton.isSelected];
    [self.playButton setSelected:!self.playButton.isSelected];
    
    if(!self.playButton.isSelected)
    {
        [self pause:nil];
    }
    else
    {
        [self play:nil];
    }
    
    
}
-(void)playAndSyncButtonPressed
{
    [self.playButton setHidden:YES];
    [self.playButton setSelected:YES];
    [self play:nil];
    
}

-(void)setCurrentSeekPosition:(double)seconds
{
    //[self.mPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC)];
    
    // Millisecond precision
    CMTime toleranceTime = CMTimeMake(1, 10);
    //[self.mPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self.mPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) toleranceBefore:toleranceTime toleranceAfter:toleranceTime];
}
-(void)prepareForTrimPreviewWithURL:(NSURL *)videoURL
{
    [self setURL:videoURL];
    [self.progressView setHidden:YES];
    [self.gobackButton setHidden:YES];
    isTrimView  = YES;
}
-(void)prepareForRecordPreviewWithURL:(NSURL *)videoURL
{
    [self setURL:videoURL];

    [self.progressView setHidden:NO];
    [self.gobackButton setHidden:NO];
    
    self.draggingSlider = 0;
    isTrimView  = NO;
}

-(void)stopPlayBack
{
    [self.playButton setSelected:NO];
    [self.playButton setHidden:NO];
    [[[TrimVideoViewController sharedInstance] previewButton] setSelected:NO];
}

@end

@implementation AVPlayerDemoPlaybackViewController (Player)

#pragma mark Player Item

- (BOOL)isPlaying
{
	return mRestoreAfterScrubbingRate != 0.f || [self.mPlayer rate] != 0.f;
}

/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification 
{
	/* After the movie has played to its end time, seek back to time zero 
		to play it again. */
	seekToZeroBeforePlay = YES;

    if (isTrimView)
    {
        [self stopPlayBack];
    }
    else
    {
        [self goBackButtonPressed:nil];
    }
    
}

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem. 
 ** ------------------------------------------------------- */

- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [self.mPlayer currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}


/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
	if (mTimeObserver)
	{
		[self.mPlayer removeTimeObserver:mTimeObserver];
		mTimeObserver = nil;
	}
}

#pragma mark -
#pragma mark Loading the Asset Keys Asynchronously

#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 ** 
 **  1) values of asset keys did not load successfully, 
 **  2) the asset keys did load successfully, but the asset is not 
 **     playable
 **  3) the item did not become ready to play. 
 ** ----------------------------------------------------------- */

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    [self disablePlayerButtons];
    
    /* Display the error. */
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}


#pragma mark Prepare to play asset, URL

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
		/* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
	}
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable) 
    {
        /* Generate an error describing the failure. */
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey, 
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey, 
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
	
	/* At this point we're ready to set up for playback of the asset. */
    	
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.mPlayerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.mPlayerItem removeObserver:self forKeyPath:@"status"];
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.mPlayerItem];
        self.mPlayerItem = nil;
    }
	
   
    
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.mPlayerItem addObserver:self 
                      forKeyPath:@"status"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
	
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.mPlayerItem];
	
    seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (!self.mPlayer)
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];	
		
        /* Observe the AVPlayer "currentItem" property to find out when any 
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did 
         occur.*/
        [self.player addObserver:self 
                      forKeyPath:@"currentItem"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self 
                      forKeyPath:@"rate"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.mPlayerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs 
         asynchronously; observe the currentItem property to find out when the 
         replacement will/did occur
		 
		 If needed, configure player item here (example: adding outputs, setting text style rules,
		 selecting media options) before associating it with a player
		 */
        [self.mPlayer replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        
        [self syncPlayPauseButtons];
    }
	
    [self.mScrubber setValue:0.0];
}

#pragma mark -
#pragma mark Asset Key Value Observing
#pragma mark

#pragma mark Key Value Observer for player rate, currentItem, player item status

/* ---------------------------------------------------------
**  Called when the value at the specified key path relative
**  to the given object has changed. 
**  Adjust the movie play and pause button controls when the 
**  player item "status" value changes. Update the movie 
**  scrubber control when the player item is ready to play.
**  Adjust the movie scrubber control when the player item 
**  "rate" value changes. For updates of the player
**  "currentItem" property, set the AVPlayer for which the 
**  player layer displays visual output.
**  NOTE: this method is invoked on the main queue.
** ------------------------------------------------------- */

- (void)observeValueForKeyPath:(NSString*) path 
			ofObject:(id)object 
			change:(NSDictionary*)change 
			context:(void*)context
{
	/* AVPlayerItem "status" property value observer. */
	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
	{
		[self syncPlayPauseButtons];

        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            /* Indicates that the status of the player is not yet known because 
             it has not tried to load new media resources for playback */
            case AVPlayerItemStatusUnknown:
            {
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                [self disablePlayerButtons];
            }
            break;
                
            case AVPlayerItemStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e. 
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                
                [self initScrubberTimer];
                
                [self enableScrubber];
                [self enablePlayerButtons];
                
                self.startMarkerTime = 0.0;
                double duration = CMTimeGetSeconds([self playerItemDuration]);
                [self updateTotalTimeWithValue:duration];
                self.endMarkerTime = duration;
                [[TrimVideoViewController sharedInstance] setFullClipDuration:duration];
                
                if (!isTrimView)
                {
                    if (![self isPlaying])
                    {
                        [self playAndSyncButtonPressed];
                    }
                    
                }
                [[ActivityLoadingViewController sharedInstance] HideLoadingIndicatorView];
                
                KMSDebugLog(@"prepareToPlayAsset - duration :%f",duration);
            }
            break;
                
            case AVPlayerItemStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
            }
            break;
        }
	}
	/* AVPlayer "rate" property value observer. */
	else if (context == AVPlayerDemoPlaybackViewControllerRateObservationContext)
	{
        [self syncPlayPauseButtons];
	}
	/* AVPlayer "currentItem" property observer. 
        Called when the AVPlayer replaceCurrentItemWithPlayerItem: 
        replacement will/did occur. */
	else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* Is the new player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disablePlayerButtons];
            [self disableScrubber];
        }
        else /* Replacement of player currentItem has occurred */
        {
            /* Set the AVPlayer for which the player layer displays visual output. */
            [self.mPlaybackView setPlayer:mPlayer];
            
            [self setViewDisplayName];
            
            /* Specifies that the player should preserve the video’s aspect ratio and 
             fit the video within the layer’s bounds. */
            [self.mPlaybackView setVideoFillMode:AVLayerVideoGravityResizeAspect];
            
            [self syncPlayPauseButtons];
        }
	}
	else
	{
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}


@end

