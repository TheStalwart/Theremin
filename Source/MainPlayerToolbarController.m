/*
 Copyright (C) 2009  Patrik Weiskircher
 
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

#import "MainPlayerToolbarController.h"
#import "UnifiedToolbar.h"
#import "UnifiedToolbarItem.h"
#import "PWVolumeSlider.h"
#import "PWMusicSearchField.h"
#import "MusicServerClient.h"
#import "WindowController.h"

NSString *tPlayControlItemIdentifier = @"tPlayControlItemIdentifier";
NSString *tStopItemIdentifier = @"tStopItemIdentifier";
NSString *tShuffleItemIdentifier = @"tShuffleItemIdentifier";
NSString *tVolumeSlider = @"tVolumeSlider";
NSString *tSearchField = @"tSearchField";

#define TR_S_TOOLBAR_LABEL_PREV		NSLocalizedString(@"Previous", @"Main Window toolbar items label")
#define TR_S_TOOLBAR_LABEL_PLAY		NSLocalizedString(@"Play", @"Main Window toolbar items label")
#define TR_S_TOOLBAR_LABEL_NEXT		NSLocalizedString(@"Next", @"Main Window toolbar items label")
#define TR_S_TOOLBAR_LABEL_PAUSE	NSLocalizedString(@"Pause", @"Main Window toolbar items label")
#define TR_S_TOOLBAR_LABEL_STOP		NSLocalizedString(@"Stop", @"Main Window toolbar items label")
#define TR_S_TOOLBAR_LABEL_SHUFFLE	NSLocalizedString(@"Shuffle", @"Main Window toolbar items label")

@interface MainPlayerToolbarController (PrivateMethods)
- (void) setupToolbar;
- (void) enableToolbarItems:(BOOL)enable;
@end

@implementation MainPlayerToolbarController

- (id) init {
	self = [super init];
	if (self != nil) {
		[self setupToolbar];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(connected:)
													 name:nMusicServerClientConnected
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(disconnected:)
													 name:nMusicServerClientDisconnected
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(stateChanged:) 
													 name:nMusicServerClientStateChanged 
												   object:nil];	
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(volumeChanged:)
													 name:nMusicServerClientVolumeChanged
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(shuffleOptionChanged:)
													 name:nMusicServerClientShuffleOptionChanged
												   object:nil];
	}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_toolbarItems release];
	[_toolbar release];
	[_volumeSlider release];
	[_playerItem release];
	[_stopItem release];
    [_shuffleItem release];
	[_musicSearch release];
	[super dealloc];
}

- (void) setupToolbar {
	_toolbarItems = [[NSMutableDictionary alloc] init];
	_toolbar = [[UnifiedToolbar alloc] initWithIdentifier:@"mpdToolbar"];
	[_toolbar setDelegate:self];
	[_toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];	
	[_toolbar setAllowsUserCustomization:YES];
	[_toolbar setAutosavesConfiguration:YES];
}

- (void) connected:(NSNotification *)notification {
	[self enableToolbarItems:YES];
}

- (void) disconnected:(NSNotification *)notification {
	[self enableToolbarItems:NO];
}

- (void) enableToolbarItems:(BOOL)enable {
	[_playerItem setEnabled:enable forSegment:0];
	[_playerItem setEnabled:enable forSegment:1];
	[_playerItem setEnabled:enable forSegment:2];
	
	[_stopItem setEnabled:enable];
	[_shuffleItem setEnabled:enable forSegment:0];
	[_volumeSlider setEnabled:enable];
	[[self musicSearchField] setEnabled:enable];	
}

- (void) stateChanged:(NSNotification *)notification {
	int state = [[[notification userInfo] objectForKey:dState] intValue];
	
	[_playerItem setEnabled:YES forSegment:0];
	[_playerItem setEnabled:YES forSegment:1];
	[_playerItem setEnabled:YES forSegment:2];
	
	switch (state) {
		case eStatePaused:
			[_playerItem setImage:[NSImage imageNamed:@"playSong"] forSegment:1];
			[_playerItem setLabel:TR_S_TOOLBAR_LABEL_PLAY forSegment:1];
			[_stopItem setEnabled:YES];
			break;
			
		case eStatePlaying:
			[_playerItem setImage:[NSImage imageNamed:@"pauseSong"] forSegment:1];
			[_playerItem setLabel:TR_S_TOOLBAR_LABEL_PAUSE forSegment:1];
			[_stopItem setEnabled:YES];
			break;
			
		case eStateStopped:
			[_playerItem setImage:[NSImage imageNamed:@"playSong"] forSegment:1];
			[_playerItem setLabel:TR_S_TOOLBAR_LABEL_PLAY forSegment:1];
			[_stopItem setEnabled:NO];
			break;
	}
}

- (void) volumeChanged:(NSNotification *)notification {
	int volume = [[[notification userInfo] objectForKey:dVolume] intValue];
	
	if ([[[NSRunLoop currentRunLoop] currentMode] isEqualTo:NSEventTrackingRunLoopMode] == YES) {
		return;
	}
	
	[_volumeSlider setFloatValue:volume];
}

- (void) shuffleOptionChanged:(NSNotification *)notification {
	bool shuffleState = [[[notification userInfo] objectForKey:@"shuffleState"] boolValue];
	
	if (shuffleState)
		[_shuffleItem setImage:[NSImage imageNamed:@"shuffleOff"]];
	else
		[_shuffleItem setImage:[NSImage imageNamed:@"shuffleOn"]];
}

- (void) volumeShouldChange:(id)sender {
	[[[WindowController instance] musicClient] setPlaybackVolume:[_volumeSlider floatValue]];
	[_volumeSlider updateVolumeImage];
}


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
	if ([_toolbarItems objectForKey:itemIdentifier] != nil)
		return [_toolbarItems objectForKey:itemIdentifier];
	
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
	if ([itemIdentifier isEqualToString:tPlayControlItemIdentifier]) {
		UnifiedToolbarItem *uitem = [[[UnifiedToolbarItem alloc] initWithItemIdentifier:itemIdentifier segmentCount:3] autorelease];
		
		[uitem setImage:[NSImage imageNamed:@"prevSong"] forSegment:0];
		[uitem setImage:[NSImage imageNamed:@"playSong"] forSegment:1];
		[uitem setImage:[NSImage imageNamed:@"nextSong"] forSegment:2];
		
		[uitem setLabel:TR_S_TOOLBAR_LABEL_PREV forSegment:0];
		[uitem setLabel:TR_S_TOOLBAR_LABEL_PLAY forSegment:1];
		[uitem setLabel:TR_S_TOOLBAR_LABEL_NEXT forSegment:2];
		
		[uitem setTarget:[WindowController instance] forSegment:0];
		[uitem setAction:@selector(previousSong:) forSegment:0];
		
		[uitem setTarget:[WindowController instance] forSegment:1];
		[uitem setAction:@selector(togglePlayPause:) forSegment:1];
		
		[uitem setTarget:[WindowController instance] forSegment:2];
		[uitem setAction:@selector(nextSong:) forSegment:2];
		
		[_toolbarItems setObject:uitem forKey:itemIdentifier];
		item = uitem;
		_playerItem = [uitem retain];
	} else if ([itemIdentifier isEqualToString:tStopItemIdentifier]) {
		UnifiedToolbarItem *uitem = [[[UnifiedToolbarItem alloc] initWithItemIdentifier:itemIdentifier segmentCount:1] autorelease];
		
		[uitem setImage:[NSImage imageNamed:@"stopSong"]];
		[uitem setTarget:[WindowController instance]];
		[uitem setAction:@selector(stop:)];
		[uitem setLabel:TR_S_TOOLBAR_LABEL_STOP];
		
		[_toolbarItems setObject:uitem forKey:itemIdentifier];
		item = uitem;
		_stopItem = [uitem retain];
	} else if ([itemIdentifier isEqualToString:tShuffleItemIdentifier]) {
        UnifiedToolbarItem *uitem = [[[UnifiedToolbarItem alloc] initWithItemIdentifier:itemIdentifier segmentCount:1] autorelease];
        
		[uitem setImage:[NSImage imageNamed:@"shuffleOff"]];
        [uitem setLabel:TR_S_TOOLBAR_LABEL_SHUFFLE];
		[uitem setTarget:[WindowController instance]];
		[uitem setAction:@selector(shuffle:)];
        
        [_toolbarItems setObject:uitem forKey:itemIdentifier];
        item = uitem;
        _shuffleItem = [uitem retain];
    } else if ([itemIdentifier isEqualToString:tVolumeSlider]) {
		_volumeSlider = [[PWVolumeSlider alloc] initWithFrame:NSMakeRect(0,0,0,0)];
		[_volumeSlider setFrame:NSMakeRect(0, 0, [_volumeSlider size].width, [_volumeSlider size].height)];
		
		[item setView:_volumeSlider];
		[item setMinSize:NSMakeSize(NSWidth([_volumeSlider frame]), NSHeight([_volumeSlider frame]))];
		[item setMaxSize:NSMakeSize(NSWidth([_volumeSlider frame]), NSHeight([_volumeSlider frame]))];
		
		[_volumeSlider setTarget:self];
		[_volumeSlider setAction:@selector(volumeShouldChange:)];
		
		[_toolbarItems setObject:item forKey:itemIdentifier];
	} else if ([itemIdentifier isEqualToString:tSearchField]) {
		[item setView:[self musicSearchField]];
		[item setMinSize:NSMakeSize(NSWidth([[self musicSearchField] frame]), NSHeight([[self musicSearchField] frame]))];
		[item setMaxSize:NSMakeSize(NSWidth([[self musicSearchField] frame]), NSHeight([[self musicSearchField] frame]))];
		
		[_toolbarItems setObject:item forKey:itemIdentifier];
	}
	
	return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:tPlayControlItemIdentifier, tStopItemIdentifier, tShuffleItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, tVolumeSlider, tSearchField, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:tPlayControlItemIdentifier, tStopItemIdentifier, tShuffleItemIdentifier, tVolumeSlider, NSToolbarFlexibleSpaceItemIdentifier, tSearchField, nil];
}

- (PWMusicSearchField *)musicSearchField {
	if (!_musicSearch) {
		NSRect frame = NSMakeRect(0,0,150,30);
		_musicSearch = [[PWMusicSearchField alloc] initWithFrame:frame];
	}
	return [[_musicSearch retain] autorelease];
}

- (NSToolbar *)toolbar {
	return [[_toolbar retain] autorelease];
}

- (PWVolumeSlider *)volumeSlider {
	return [[_volumeSlider retain] autorelease];
}

@end
