/*
 Copyright (C) 2006-2007  Patrik Weiskircher
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
 MA 02110-1301, USA.
 */

#import "WindowController.h"
#import "InfoAreaController.h"

#import "PreferencesController.h"
#import "PlayListController.h"
#import "PWWindow.h"
#import "LicenseController.h"
#import "LibraryController.h"
#import "MainPlayerToolbarController.h"
#import "FileBrowserController.h"

#import "PlayListFilesController.h"
#import "UpdateDatabaseController.h"
#import "AppGlobalHotkey.h"
#import "AppGlobalHotkeyController.h"

#import "SongInfoController.h"
#import "CompilationDetector.h"

#import "ProfileMenuItem.h"
#import "ProfileRepository.h"
#import "OutputDeviceHandler.h"
#import "AppleRemoteController.h"

#import "SPMediaKeyTap.h"

WindowController *globalWindowController = nil;

const NSString *nProfileSwitched = @"nProfileSwitched";
const NSString *dProfile = @"dProfile";

@interface WindowController (PrivateMethods)
- (void) setupNotificationObservers;
- (void) setupProfilesMenu;

// callback when profiles in settings changed.
- (void) profilesChanged:(NSNotification *)aNotification;

// callback when we switched profile
- (void) switchedProfile;

- (NSMenuItem *) profilesMenuItem;
- (NSMenu *) newProfilesMenu;
@end

@implementation WindowController

@synthesize licenseController = _licenseController;

#pragma mark Initializations 

+ (void) initialize {
	NSString *userDefaultsPath = [[NSBundle mainBundle] pathForResource:@"at.justp.theremin.userDefaults" ofType:@"plist"];
	if ([userDefaultsPath length] > 0) {
		NSMutableDictionary *userDefaults = [NSMutableDictionary dictionaryWithContentsOfFile:userDefaultsPath];
		if (!userDefaults) {
			userDefaults = [[[NSMutableDictionary alloc] init] autorelease];
		}
		
		// SPMediaKeyTap
		// Register defaults for the whitelist of apps that want to use media keys
		[userDefaults setObject:[SPMediaKeyTap defaultMediaKeyUserBundleIdentifiers]
						 forKey:kMediaKeyUsingBundleIdentifiersDefaultsKey];
		
		[[NSUserDefaults standardUserDefaults] registerDefaults:userDefaults];
	}
}

+ (id) instance {
	return globalWindowController;
}

- (id<LibraryDataSourceProtocol>) currentLibraryDataSource {
	return [LibraryDataSource libraryDataSourceForProfile:[[PreferencesController sharedInstance] currentProfile]];
}

- (void) setupConnectionWithMusicClient {
	NSPort *port1, *port2;
	
	port1 = [NSPort port];
	port2 = [NSPort port];
	
	[(MusicServerClient*)mClient stop];
	[mClient release];
	mClient = nil;
	
	[mConnectionToMpdClient release];
	
	mConnectionToMpdClient = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[mConnectionToMpdClient setRootObject:self];

	
	NSString *musicClientClass = NSStringFromClass([MusicServerClient musicServerClientClassForProfile:[[PreferencesController sharedInstance] currentProfile]]);

	NSDictionary *infos = [NSDictionary dictionaryWithObjectsAndKeys:port2, nMusicServerClientPort0,
																	port1, nMusicServerClientPort1,
																	musicClientClass, nMusicServerClientClass,
						   nil];
	[NSThread detachNewThreadSelector:@selector(connectWithPorts:)
							 toTarget:[MusicServerClient class]
						   withObject:infos];
	
	[self switchedProfile];
}

- (void) setupNotificationObservers {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientDisconnected:) name:nMusicServerClientDisconnected object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientRequiredAuthentication:) name:nMusicServerClientRequiresAuthentication object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientStateChanged:) name:nMusicServerClientStateChanged object:nil];	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientShuffleChanged:) name:nMusicServerClientShuffleOptionChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientRepeatChanged:) name:nMusicServerClientRepeatOptionChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientCrossfadeChanged:) name:nMusicServerClientCrossfadeSecondsChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(elapsedTimeChanged:) name:nMusicServerClientElapsedTimeChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(totalTimeChanged:) name:nMusicServerClientTotalTimeChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(profilesChanged:) name:(NSString *)nProfileControllerUpdatedProfiles object:nil];
}


- (void) setKeyEquivalentForMenuItemWithSelector:(SEL)selector toKey:(int)key {
	NSMenu *controlMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTag:1] submenu];
	int index;
	NSMenuItem *item;
	unichar ch = key;
	
	index = [controlMenu indexOfItemWithTarget:self andAction:selector];
	if (index != -1) {
		item = [controlMenu itemAtIndex:index];
		[item setKeyEquivalent:[NSString stringWithCharacters:&ch length:1]];
	}
}

- (void) setupMenuShortcuts {
	[self setKeyEquivalentForMenuItemWithSelector:@selector(nextSong:) toKey:NSRightArrowFunctionKey];
	[self setKeyEquivalentForMenuItemWithSelector:@selector(previousSong:) toKey:NSLeftArrowFunctionKey];
	[self setKeyEquivalentForMenuItemWithSelector:@selector(prevAlbum:) toKey:NSLeftArrowFunctionKey];
	[self setKeyEquivalentForMenuItemWithSelector:@selector(nextAlbum:) toKey:NSRightArrowFunctionKey];
	[self setKeyEquivalentForMenuItemWithSelector:@selector(increaseVolume:) toKey:NSUpArrowFunctionKey];
	[self setKeyEquivalentForMenuItemWithSelector:@selector(decreaseVolume:) toKey:NSDownArrowFunctionKey];
	
	NSArray *commonTypesToIgnore = [NSArray arrayWithObjects:[NSButton class], [NSTextView class], [NSSlider class], nil];
	
	AppGlobalHotkey *hk = [[[AppGlobalHotkey alloc] initWithTarget:self andAction:@selector(togglePlayPause:)
												 withKeyEquivalent:@" "] autorelease];
	[hk excludeFirstResponderClasses:commonTypesToIgnore];
	[[AppGlobalHotkeyController instance] addHotkey:hk];
	
	NSArray *allowedTypes = [NSArray arrayWithObjects:[NSNumber numberWithUnsignedInt:NSKeyUp], 
							 [NSNumber numberWithUnsignedInt:NSKeyDown],
							 nil];
	
	hk = [[[AppGlobalHotkey alloc] initWithTarget:self andAction:@selector(previousSong:)
								withKey:NSLeftArrowFunctionKey] autorelease];
	[hk excludeFirstResponderClasses:commonTypesToIgnore];
	[hk setAllowedTypes:allowedTypes];
	[hk setIgnoreTypes:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:NSKeyDown]]];
	[hk excludeModifierKeys:NSCommandKeyMask|NSAlternateKeyMask];
	[[AppGlobalHotkeyController instance] addHotkey:hk];

	hk = [[[AppGlobalHotkey alloc] initWithTarget:self andAction:@selector(nextSong:)
								withKey:NSRightArrowFunctionKey] autorelease];
	[hk excludeFirstResponderClasses:commonTypesToIgnore];
	[hk setAllowedTypes:allowedTypes];
	[hk setIgnoreTypes:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInt:NSKeyDown]]];
	[hk excludeModifierKeys:NSCommandKeyMask|NSAlternateKeyMask];
	[[AppGlobalHotkeyController instance] addHotkey:hk];
	
	[mWindow setUseGlobalHotkeys:YES];
}

- (id) init {	
	self = [super init];
	if (self != nil) {
		globalWindowController = self;
		
		[NSApp setDelegate:self];
	
		[self setupNotificationObservers];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(appActiveChanged:)
													 name:NSApplicationDidResignActiveNotification
												   object:NSApp];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(appActiveChanged:)
													 name:NSApplicationDidBecomeActiveNotification
												   object:NSApp];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(systemWillSleep:)
													 name:NSWorkspaceWillSleepNotification
												   object:[NSWorkspace sharedWorkspace]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(systemDidWake:)
													 name:NSWorkspaceDidWakeNotification
												   object:[NSWorkspace sharedWorkspace]];
		mDisableAutoreconnectOnce = NO;
		mPausedOnSleep = NO;
	}
	
	return self;
}

- (void) awakeFromNib {
	[[PreferencesController sharedInstance] importOldSettings];
	preferencesWindowController = [[PreferencesWindowController alloc] initWithPreferencesController:[PreferencesController sharedInstance]];
	[self profilesChanged:nil];
	
	_mainPlayerToolbarController = [[MainPlayerToolbarController alloc] init];
	[mWindow setToolbar:[_mainPlayerToolbarController toolbar]];
	
	[mPlaylistController setupSearchField:[_mainPlayerToolbarController musicSearchField]];
	
	[self setupMenuShortcuts];
	
	mPlayListFilesController = [[PlayListFilesController alloc] init];
	mLibraryController = [[LibraryController alloc] init];
	mUpdateDatabaseController = [[UpdateDatabaseController alloc] init];
	mFileBrowserController = [[FileBrowserController alloc] init];
	
	[self setupConnectionWithMusicClient];
	
	_outputDeviceHandler = [[OutputDeviceHandler alloc] initWithMenu:[_controlsMenuItem submenu]];
	_appleRemoteController = [[AppleRemoteController alloc] init];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
	[_mainPlayerToolbarController release];
	
	[mClient release];
	[mConnectionToMpdClient release];
	[mLibraryController release];
	[mUpdateDatabaseController release];
	[mPlayListFilesController release], mPlayListFilesController = nil;
	[mFileBrowserController release];
	
	[_outputDeviceHandler release];
	[_appleRemoteController release];
	[_mediaKeyTap release];
	
	[_licenseController release];

	
	[super dealloc];
}

#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	_mediaKeyTap = [[SPMediaKeyTap alloc] initWithDelegate:self];
	
	if ([SPMediaKeyTap usesGlobalMediaKeyTap]) {
		[_mediaKeyTap startWatchingMediaKeys];
	} else {
		NSLog(@"Media key monitoring not supported");
	}
}

#pragma mark - SPMediaKeyTapDelegate

-(void)mediaKeyTap:(SPMediaKeyTap*)keyTap receivedMediaKeyEvent:(NSEvent*)event; {
	NSAssert([event type] == NSSystemDefined && [event subtype] == SPSystemDefinedEventMediaKeys, @"Unexpected NSEvent in mediaKeyTap:receivedMediaKeyEvent:");
	// here be dragons...
	int keyCode = (([event data1] & 0xFFFF0000) >> 16);
	int keyFlags = ([event data1] & 0x0000FFFF);
	BOOL keyIsPressed = (((keyFlags & 0xFF00) >> 8)) == 0xA;
	int keyRepeat = (keyFlags & 0x1);
	
	if (keyIsPressed) {
		NSString *debugString = [NSString stringWithFormat:@"%@", keyRepeat?@", repeated.":@"."];
		switch (keyCode) {
			case NX_KEYTYPE_PLAY:
				debugString = [@"Play/pause pressed" stringByAppendingString:debugString];
				[self togglePlayPause:keyTap];
				break;
				
			case NX_KEYTYPE_FAST:
				debugString = [@"Ffwd pressed" stringByAppendingString:debugString];
				[self nextSong:keyTap];
				break;
				
			case NX_KEYTYPE_REWIND:
				debugString = [@"Rewind pressed" stringByAppendingString:debugString];
				[self previousSong:keyTap];
				break;
			default:
				debugString = [NSString stringWithFormat:@"Key %d pressed%@", keyCode, debugString];
				break;
				// More cases defined in hidsystem/ev_keymap.h
		}
		NSLog(@"%@", debugString);
	}
}

#pragma mark -
#pragma mark Profiles

- (void) setupProfilesMenu {
	NSMenuItem *profilesMenu = [self profilesMenuItem];

	[_profileChooser setMenu:[self newProfilesMenu]];
	[profilesMenu setSubmenu:[self newProfilesMenu]];
}

- (NSMenu *) newProfilesMenu {
	NSMenu *subMenu = [[[NSMenu alloc] initWithTitle:@"Profiles"] autorelease];
	
	NSArray *profiles = [ProfileRepository profiles];
	for (int i = 0; i < [profiles count]; i++) {
		Profile *profile = [profiles objectAtIndex:i];
		ProfileMenuItem *item = [[[ProfileMenuItem alloc] initWithTitle:[profile description]
																 action:@selector(selectProfile:)
														  keyEquivalent:@""] autorelease];
		[item setProfile:profile];
		[subMenu addItem:item];
	}

	return subMenu;
}

- (NSMenuItem *) profilesMenuItem {
	return [_fileMenu itemWithTag:9999];
}

- (void) profilesChanged:(NSNotification *)aNotification {
	int profilesCount = [[ProfileRepository profiles] count];
	[_profileChooser setHidden:profilesCount == 1];
	[self setupProfilesMenu];
	[self switchedProfile];
}

- (IBAction) selectProfile:(id)sender {
	[[PreferencesController sharedInstance] setCurrentProfile:[(ProfileMenuItem *)sender profile]];
	[self setupConnectionWithMusicClient];
}

- (void) switchedProfile {
	NSMenu *profilesMenu = [[self profilesMenuItem] submenu];
	Profile *currentProfile = [[PreferencesController sharedInstance] currentProfile];

	for (int i = 0; i < [[profilesMenu itemArray] count]; i++) {
		ProfileMenuItem *item = (ProfileMenuItem *)[profilesMenu itemAtIndex:i];
		if ([[item profile] isEqualToProfile:currentProfile])
			[item setState:NSOnState];
		else
			[item setState:NSOffState];
	}
	
	for (int i = 0; i < [[[_profileChooser menu] itemArray] count]; i++) {
		ProfileMenuItem *item = (ProfileMenuItem *)[[_profileChooser menu] itemAtIndex:i];
		if ([[item profile] isEqualToProfile:currentProfile]) {
			[_profileChooser selectItem:item];
			break;
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)nProfileSwitched 
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:currentProfile forKey:dProfile]];
}

#pragma mark -

- (void)setMusicClient:(id)inClient {
	[inClient setProtocolForProxy:@protocol(MusicServerClientInterface)];
	mClient = [inClient retain];

	[mInfoAreaController scheduleUpdate];
	[mClient initialize];
	
	[mClient connectToServerWithProfile:[[PreferencesController sharedInstance] currentProfile]];
}

- (id)musicClient {
	return mClient;
}

- (int) currentPlayerState {
	return mCurrentState;
}

- (PlayListController *) playlistController {
	return mPlaylistController;
}

- (NSWindow *)window {
	return mWindow;
}

- (void) appActiveChanged:(NSNotification *)aNotification {
	if ([[aNotification name] isEqualTo:NSApplicationDidResignActiveNotification]) {
		[mClient playerWindowUnfocused];
	} else if ([[aNotification name] isEqualTo:NSApplicationDidBecomeActiveNotification]) {
		[mClient playerWindowFocused];
	}
}

- (void) systemWillSleep:(NSNotification *) notification {
	if ([[PreferencesController sharedInstance] pauseOnSleep] && [self currentPlayerState] == eStatePlaying) {
		[mClient pausePlayback];
		mPausedOnSleep = YES;
	}
}

- (void) systemDidWake:(NSNotification *) notification {
	if ([[PreferencesController sharedInstance] pauseOnSleep] && mPausedOnSleep)
		[mClient play];
	mPausedOnSleep = NO;
}

- (NSString *)applicationSupportFolder {	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"Theremin"];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	[mWindow makeKeyAndOrderFront:self];
	
	return NO;
}

#pragma mark Configuration Stuff

- (void) autoreconnectTimerTriggered:(NSTimer *)timer {
	mAutoreconnectTimer = nil;
	[mClient connectToServerWithProfile:[[PreferencesController sharedInstance] currentProfile]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	BOOL connected = [[self musicClient] isConnected];
	
	if ([item action] == @selector(connect:)) return !connected;
	else if ([item action] == @selector(disconnect:) ||
		     [item action] == @selector(saveCurrentPlaylist:) ||
			 [item action] == @selector(scrollToCurrentSong:) ||
			 [item action] == @selector(togglePlayPause:) ||
			 [item action] == @selector(stop:) ||
			 [item action] == @selector(nextSong:) ||
			 [item action] == @selector(previousSong:) ||
			 [item action] == @selector(nextAlbum:) ||
			 [item action] == @selector(prevAlbum:) ||
			 [item action] == @selector(toggleShuffle:) ||
			 [item action] == @selector(toggleRepeat:) ||
			 [item action] == @selector(toggleCrossfade:) ||
			 [item action] == @selector(increaseVolume:) ||
			 [item action] == @selector(decreaseVolume:) ||
			 [item action] == @selector(find:))
		return connected;

	if ([item action] == @selector(deleteSelectedItems:)) {
		return (connected && (
							  ([NSApp keyWindow] == mWindow && [mWindow firstResponder] == mPlaylist)
							  || ([NSApp keyWindow] == mWindow && [mWindow firstResponder] == mPlayListFilesController.playlistFilesView)
							)
		);
	}
	
	if ([item action] == @selector(getInfoOnKeyWindow:)) {
		if ([NSApp keyWindow] == mWindow && [mWindow firstResponder] == mPlaylist)
			return connected;
		else if ([NSApp keyWindow] == [mLibraryController window] && [mLibraryController isGetInfoAllowed])
			return connected;
		return NO;
	}
	
	if ([item action] == @selector(updateCompleteDatabase:) ||
		[item action] == @selector(showUpdateDatabase:))
		return connected && [[self currentLibraryDataSource] supportsDataSourceCapabilities] & eLibraryDataSourceSupportsImportingSongs;
	else if ([item action] == @selector(detectCompilations:))
		return connected && [[self currentLibraryDataSource] supportsDataSourceCapabilities] & eLibraryDataSourceSupportsCustomCompilations;
	else if ([item action] == @selector(randomizePlaylist:))
		return connected && [[MusicServerClient musicServerClientClassForProfile:[[PreferencesController sharedInstance] currentProfile]] capabilities] & eMusicClientCapabilitiesRandomizePlaylist;
	
	return [item isEnabled];
}

#pragma mark MusicClient notification handlers

- (void) clientDisconnected:(NSNotification *)notification {
	if ([[[PreferencesController sharedInstance] currentProfile] autoreconnect] == YES) {
		if (mDisableAutoreconnectOnce == YES) {
			mDisableAutoreconnectOnce = NO;
		} else {
			[mAutoreconnectTimer invalidate];
		
			mAutoreconnectTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(autoreconnectTimerTriggered:) userInfo:nil repeats:NO];
		}
	}
}

- (void) clientRequiredAuthentication:(NSNotification *)notification {
	NSString *server = [[notification userInfo] objectForKey:@"server"];
	int port = [[[notification userInfo] objectForKey:@"port"] intValue];
	[mAuthenticationDescription setStringValue:[NSString stringWithFormat:@"%@:%d", server, port]];
	[mAuthenticationSavePassword setState:NSOffState];
	[NSApp runModalForWindow:mAuthenticationPanel];

}

- (void) clientStateChanged:(NSNotification *)notification {
	mCurrentState = [[[notification userInfo] objectForKey:dState] intValue];

	[mInfoAreaController scheduleUpdate];
	[mPlaylistController updateCurrentSongMarker];
}

- (void) elapsedTimeChanged:(NSNotification *)aNotification {
	if ([[[NSRunLoop currentRunLoop] currentMode] isEqualTo:NSEventTrackingRunLoopMode] == YES) {
		return;
	}

	int elapsed = [[[aNotification userInfo] objectForKey:dElapsedTime] intValue];
	[mInfoAreaController updateSeekBarWithElapsedTime:elapsed];
}

- (void) totalTimeChanged:(NSNotification *)aNotification {
	int total = [[[aNotification userInfo] objectForKey:dTotalTime] intValue];
	[mInfoAreaController updateSeekBarWithTotalTime:total];
}

- (void) clientShuffleChanged:(NSNotification *)notification {
	BOOL shuffleEnabled = [[[notification userInfo] objectForKey:@"shuffleState"] boolValue];
	if (shuffleEnabled) {
		[mShuffleItem setState:NSOnState];
	} else {
		[mShuffleItem setState:NSOffState];
	}
}

- (void) clientRepeatChanged:(NSNotification *)notification {
	BOOL repeatEnabled = [[[notification userInfo] objectForKey:@"repeatState"] boolValue];
	if (repeatEnabled) {
		[mRepeatItem setState:NSOnState];
	} else {
		[mRepeatItem setState:NSOffState];
	}
}

- (void) clientCrossfadeChanged:(NSNotification *)notification {
	NSInteger crossfadeSeconds = [[[notification userInfo] objectForKey:@"crossfadeSeconds"] integerValue];
	
	if (crossfadeSeconds) {
		[mCrossfadeItem setState:NSOnState];
	} else {
		[mCrossfadeItem setState:NSOffState];
	}
}

#pragma mark Actions.

- (IBAction) preferencesClicked:(id)sender {
	[preferencesWindowController showPreferences];
}

- (void) getInfoOnSongs:(NSArray *)theSongs {
	SongInfoController *songInfoController = [[SongInfoController alloc] init];
	[songInfoController showSongs:theSongs];
}

#pragma mark Authentication stuff
- (IBAction) authenticationButtonPressed:(id)sender {
	switch ([sender tag]) {
		case 0: // cancel
			[mClient setAuthenticationInformation:[NSDictionary dictionary]];
			break;
			
		case 1: // authenticate
			if ([mAuthenticationSavePassword state] == NSOnState) {
				[[[PreferencesController sharedInstance] currentProfile] setPassword:[mAuthenticationPassword stringValue]];
				[[[PreferencesController sharedInstance] currentProfile] savePassword];
			}
			[mClient setAuthenticationInformation:[NSDictionary dictionaryWithObject:[mAuthenticationPassword stringValue] forKey:@"password"]];
			break;
	}
	
	[mAuthenticationPassword setStringValue:@""];
	[mAuthenticationPanel orderOut:self];
	[NSApp stopModal];
}

#pragma mark toolbar actions

- (IBAction) togglePlayPause:(id)sender {
	switch ([self currentPlayerState]) {
		case eStatePaused:
		case eStateStopped:
			[mClient startPlayback];
			break;
		case eStatePlaying:
			[mClient pausePlayback];
			break;
	}
}

- (IBAction) nextSong:(id)sender {
	[mClient next];
	[mPlaylistController scheduleShowCurrentSongOnNextSongChange];
}

- (IBAction) previousSong:(id)sender {
	[mClient previous];
	[mPlaylistController scheduleShowCurrentSongOnNextSongChange];
}

- (IBAction) nextAlbum:(id)sender {
	Song *song = [mPlaylistController songOfNextAlbum];
	if (song != nil) {
		[mClient skipToSong:song];
		[mPlaylistController scheduleShowCurrentSongOnNextSongChange];
		[mPlaylistController scheduleSelectCurrentSongOnNextSongChange];
	}
}

- (IBAction) prevAlbum:(id)sender {
	Song *song = [mPlaylistController songOfPreviousAlbum];
	if (song != nil) {
		[mClient skipToSong:song];
		[mPlaylistController scheduleShowCurrentSongOnNextSongChange];
		[mPlaylistController scheduleSelectCurrentSongOnNextSongChange];
	}
}

- (IBAction) stop:(id)sender {
	[mClient stopPlayback];
}

- (IBAction) shuffle:(id)sender {
	[mClient toggleShuffle];
}

- (IBAction) showPlayerWindow:(id)sender {
	if ([[NSApp keyWindow] isEqualTo:mWindow])
		[mClient playerWindowFocused];
	
	[mWindow makeKeyAndOrderFront:self];
}

- (IBAction) showLicense:(id)sender {
	if ( ! self.licenseController) {
		self.licenseController = [[[LicenseController alloc] init] autorelease];
	}
	
	[self.licenseController show];
}

- (IBAction) showLibrary:(id)sender {
	[mLibraryController show];
}

- (IBAction)showFileBrowser:(id)sender {
	[mFileBrowserController show];
}

- (IBAction) showUpdateDatabase:(id)sender {
	[mUpdateDatabaseController show];
}

- (IBAction) updateCompleteDatabase:(id)sender {
	[mUpdateDatabaseController updateCompleteDatabase];
}

- (IBAction) deleteSelectedItems:(id)sender {
	if ([NSApp keyWindow] == mWindow && [mWindow firstResponder] == mPlaylist) {
		[mPlaylistController deleteSelectedSongs:sender];
	} else if ([NSApp keyWindow] == mWindow && [mWindow firstResponder] == mPlayListFilesController.playlistFilesView) {
		[mPlayListFilesController deleteSelectedPlaylist:sender];
	}
}

- (IBAction) seekSliderChanged:(id)sender {
	[mInfoAreaController updateSeekBarWithTotalTime:[sender maxValue]];
	[mInfoAreaController updateSeekBarWithElapsedTime:[sender intValue]];

	[mClient scheduleSeek:[sender intValue] withDelay:0.1];
}

- (IBAction) connect:(id)sender {
	[mAutoreconnectTimer invalidate], mAutoreconnectTimer = nil;
	[mClient connectToServerWithProfile:[[PreferencesController sharedInstance] currentProfile]];
}

- (IBAction) disconnect:(id)sender {
	mDisableAutoreconnectOnce = YES;
	[mClient disconnectWithReason:@""];
}

- (IBAction) toggleShuffle:(id)sender {
	[mClient toggleShuffle];
}

- (IBAction) toggleRepeat:(id)sender {
	[mClient toggleRepeat];
}

- (void)toggleCrossfade:(id)sender
{
	[mClient toggleCrossfade];
}

- (IBAction) find:(id)sender {
	NSWindow *window = [NSApp keyWindow];
	if (window == nil) {
		return;
	}
	
	id search = [_mainPlayerToolbarController musicSearchField];
	if (search != nil && [search acceptsFirstResponder])
		[window makeFirstResponder:search];
}

- (IBAction) scrollToCurrentSong:(id)sender {
	[mPlaylistController showCurrentSong];
}

- (IBAction) toggleDrawer:(id)sender {
	[mPlayListFilesController toggleDrawer];
}

- (IBAction) saveCurrentPlaylist:(id)sender {
	[mPlayListFilesController saveCurrentPlaylist];
}

- (IBAction) randomizePlaylist:(id)sender {
	[mPlaylistController randomizePlaylist:self];
}

- (IBAction) increaseVolume:(id)sender {
	[mClient setPlaybackVolume:MIN(([[_mainPlayerToolbarController volumeSlider] intValue]+5), 100)];
}

- (IBAction) decreaseVolume:(id)sender {
	[mClient setPlaybackVolume:MAX(0, ([[_mainPlayerToolbarController volumeSlider] intValue]-5))];
}

- (IBAction) getInfo:(id)sender {
	NSArray *array = [[self playlistController] getSelectedSongs];
	if ([array count] == 0) {
		NSBeep();
		return;
	}
	[self getInfoOnSongs:array];
}

- (IBAction) getInfoOnKeyWindow:(id)sender {
	if ([NSApp keyWindow] == mWindow)
		return [self getInfo:sender];
	else if ([NSApp keyWindow] == [mLibraryController window])
		return [mLibraryController getInfoOnSongs:self];
}

- (IBAction) detectCompilations:(id)sender {
	CompilationDetector *detector = [[CompilationDetector alloc] initWithDataSource:[self currentLibraryDataSource] andDelegate:self];
	[detector start];
}

- (void) compilationDetectorFinished:(id)sender {
	[sender release];
	[mLibraryController reloadAll];
}


@end
