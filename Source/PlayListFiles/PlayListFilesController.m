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

#import "PlayListFilesController.h"
#import "WindowController.h"
#import "PlayListFile.h"
#import "PreferencesController.h"
#import "PlayListController.h"
#import "Song.h"

@implementation PlayListFilesController
- (id) init {
	self = [super init];
	if (self != nil) {
		[NSBundle loadNibNamed:@"PlayListFiles" owner:self];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(foundPlaylists:)
													 name:nMusicServerClientFoundPlaylists
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(disconnected:)
													 name:nMusicServerClientDisconnected
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(connected:)
													 name:nMusicServerClientConnected
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(refresh:)
													 name:nMusicServerClientNumberOfPlaylistsChanged
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(fetchedNamedPlaylist:)
													 name:nMusicServerClientFetchedNamedPlaylist
												   object:nil];
		
		mDraggingSupported = NO;
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[mPlaylists release], mPlaylists = nil;
	[mStartProgressTimer release], mStartProgressTimer = nil;
	[mRefreshDate release], mRefreshDate = nil;
	[super dealloc];
}

- (void) awakeFromNib {
	[mDrawer setParentWindow:[[WindowController instance] window]];
	
	[mPlayListFilesView setTarget:self];
	[mPlayListFilesView setDoubleAction:@selector(loadSelectedPlaylist:)];

	unichar returnActionKeys[] = { NSCarriageReturnCharacter };
	NSCharacterSet *returnCharacterSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:returnActionKeys length:1]];
	[mPlayListFilesView setActionForCharacters:returnCharacterSet onTarget:self usingSelector:@selector(loadSelectedPlaylist:)];
	
	if ([[PreferencesController sharedInstance] playlistDrawerOpen])
		[self toggleDrawer];
	
	[[mDrawer contentView] setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(drawerFrameChanged:)
												 name:NSViewFrameDidChangeNotification
											   object:[mDrawer contentView]];
}

- (void) drawerFrameChanged:(NSNotification *)aNotification {
	[[PreferencesController sharedInstance] setPlaylistDrawerWidth:[mDrawer contentSize].width];
}

- (void) toggleDrawer {
	if ([mDrawer state] == NSDrawerOpenState) {
		[mDrawer close];
		[[PreferencesController sharedInstance] setPlaylistDrawerOpen:NO];
	} else if ([mDrawer state] == NSDrawerClosedState) {
		[mDrawer open];
		
		NSSize current = [mDrawer contentSize];
		current.width = [[PreferencesController sharedInstance] playlistDrawerWidth];
		[mDrawer setContentSize:current];
		
		if (mRefreshDate == nil || [[NSDate date] timeIntervalSinceDate:mRefreshDate] > 5*60)
			[self refresh:nil];
		
		[[[WindowController instance] window] makeFirstResponder:mPlayListFilesView];
		[[PreferencesController sharedInstance] setPlaylistDrawerOpen:YES];
	}
}

- (PWTableView *)playlistFilesView
{
	return mPlayListFilesView;
}

- (IBAction) refresh:(id)sender {
	[mPlayListFilesView setEnabled:NO];

	// currently, playlists are only supported in the top level directory..
	id directory = [[[WindowController instance] musicClient] rootDirectory];
	[[[WindowController instance] musicClient] asynchronousEntriesInDirectory:directory withTypes:ePlayListFileType];
	
	mStartProgressTimer = [[NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(startProgressTimer:) userInfo:nil repeats:NO] retain];
}


- (void) foundPlaylists:(NSNotification *)aNotification {
	[mPlaylists release];
	mPlaylists = [[[aNotification userInfo] objectForKey:@"Entries"] retain];
	
	[mPlayListFilesView setEnabled:YES];
	[mPlayListFilesView reloadData];
	
	[mProgress stopAnimation:self];
	[mStartProgressTimer invalidate];
	[mStartProgressTimer release], mStartProgressTimer = nil;
	
	[mRefreshDate release];
	mRefreshDate = [[NSDate date] retain];
}

- (IBAction) loadSelectedPlaylist:(id)sender {
	// if we were called using our PWTableView action character stuff, let it through
	if ([mPlayListFilesView characterActionInProgress] == NO)
		// if clicked row is -1, the header could have been clicked - don't continue.
		if ([mPlayListFilesView clickedRow] == -1)
			// if we are called from a context menu, also let it through
			if ([sender isKindOfClass:[NSMenuItem class]] == NO) {
				NSBeep();
				return;
			}
	
	PlayListFile *file = [mPlaylists objectAtIndex:[mPlayListFilesView selectedRow]];
	currentPlaylist = [file filePath];
	[[[WindowController instance] musicClient] loadPlaylist:file];
	[[[WindowController instance] musicClient] startPlayback];
}

- (void) saveCurrentPlaylist {
	if(currentPlaylist == nil){
		currentPlaylist = @"";
	}
	[mSavePlayListName setStringValue: currentPlaylist];
	NSWindow *mainWindow = [[WindowController instance] window];
	[NSApp beginSheet:mSavePlayListAsPanel modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) savePlayListAction:(id)sender {
	[mSavePlayListAsPanel orderOut:nil];
	[NSApp endSheet:mSavePlayListAsPanel];
	
	if ([sender tag] == 1) {
		NSString *name = [mSavePlayListName stringValue];
		if ([name length] == 0) {
			NSBeep();
			return;
		}
		
		[[[WindowController instance] musicClient] saveCurrentPlaylistAs:name];
	}
}

- (IBAction) deleteSelectedPlaylist:(id)sender {
	if ([mPlayListFilesView selectedRow] == -1) {
		NSBeep();
		return;
	}

	if ([[PreferencesController sharedInstance] noConfirmationNeededForDeletionOfPlaylist])
		[self deleteSelectedPlaylist];
	else {
		PlayListFile *file = [mPlaylists objectAtIndex:[mPlayListFilesView selectedRow]];
		[mDeleteConfirmationLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the playlist \"%@\"?", @"Question if the user wants to delete the playlist"),
			[[file filePath] lastPathComponent]]];
		
		[NSApp beginSheet:mDeleteConfirmationPanel
		   modalForWindow:[[WindowController instance] window]
			modalDelegate:nil
		   didEndSelector:nil
			  contextInfo:nil];
	}
}

- (IBAction) deleteConfirmationButtonClicked:(id)sender {
	[mDeleteConfirmationPanel orderOut:nil];
	[NSApp endSheet:mDeleteConfirmationPanel];
	
	if ([sender tag] == 1) {
		BOOL doNotAskMeAgain = [mDeleteConfirmationDoNotAskMeAgainCheckbox state] == NSOnState ? YES : NO;
		
		if (doNotAskMeAgain) {
			[[PreferencesController sharedInstance] setNoConfirmationNeededForDeletionOfPlaylist:YES];
		}
		
		[self deleteSelectedPlaylist];
	}
}

- (void) deleteSelectedPlaylist {
	PlayListFile *file = [mPlaylists objectAtIndex:[mPlayListFilesView selectedRow]];
	[[[WindowController instance] musicClient] deletePlaylist:file];
}

- (void) disconnected:(NSNotification *)aNotification {
	[mRefreshDate release], mRefreshDate = nil;
	[mPlaylists release], mPlaylists = nil;
	[mPlayListFilesView reloadData];
	
	[mRefresh setEnabled:NO];
	[mDeleteButton setEnabled:NO];
}

- (void) connected:(NSNotification *)aNotification {
	[mRefresh setEnabled:YES];
	
	if ([[[WindowController instance] musicClient] canGetPlaylistInfo])
		mDraggingSupported = YES;
	else
		mDraggingSupported = NO;
	
	if ([mDrawer state] == NSDrawerOpenState) {
		[self refresh:nil];
	}
}

- (void) startProgressTimer:(NSTimer *)aTimer {
	[mStartProgressTimer release], mStartProgressTimer = nil;
	[mProgress startAnimation:self];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [mPlaylists count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if ([[aTableColumn identifier] isEqualToString:@"Playlist Icon"]) {
		return [NSImage imageNamed:@"PlayListIcon"];
	} else if ([[aTableColumn identifier] isEqualToString:@"Playlist Name"]) {
		return [[[mPlaylists objectAtIndex:rowIndex] filePath] lastPathComponent];
	}
	
	return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
	if ([rowIndexes count] > 1)
		return NO;
	
	int index = [rowIndexes firstIndex];
	
	[pboard declareTypes:[NSArray arrayWithObject:gMpdUniqueIdentifierType] owner:self];
	[pboard setString:[[mPlaylists objectAtIndex:index] filePath] forType:@"PLAYLISTPATH"];
	return YES;
}

- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type {
	NSString *path = [sender stringForType:@"PLAYLISTPATH"];
	if (path == nil)
		return;
	
	PlayListFile *file = [PlayListFile listWithFilePath:path];
	
	[mPathOfNamedPlaylistBeingFetched release], mPathOfNamedPlaylistBeingFetched = [path retain];
	[mFetchedNamedPlaylist release], mFetchedNamedPlaylist = nil;
	
	[[[WindowController instance] musicClient] fetchNamedPlaylist:file];
	
	NSDate *now = [[NSDate date] retain];
	while (mFetchedNamedPlaylist == nil) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
		
		// if we can't get the playlist in < 3 second, we give up.
		if ([now timeIntervalSinceNow] < -3.0) {
			break;
		}
	}

	[now release];
	[mPathOfNamedPlaylistBeingFetched release], mPathOfNamedPlaylistBeingFetched = nil;
	
	if (mFetchedNamedPlaylist) {
		NSMutableArray *uniqueIdentifiers = [NSMutableArray array];
		for (int i = 0; i < [mFetchedNamedPlaylist count]; i++) {
			[uniqueIdentifiers addObject:[[mFetchedNamedPlaylist objectAtIndex:i] uniqueIdentifier]];
		}
		
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:uniqueIdentifiers];
		[sender setData:data forType:gMpdUniqueIdentifierType];

		[mFetchedNamedPlaylist release], mFetchedNamedPlaylist = nil;
	}
}

- (void)fetchedNamedPlaylist:(NSNotification *)aNotification {
	NSDictionary *dict = [aNotification userInfo];
	if ([[[dict objectForKey:@"PlayListFile"] filePath] isEqualToString:mPathOfNamedPlaylistBeingFetched]) {
		mFetchedNamedPlaylist = [[dict objectForKey:dSongs] retain];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if ([mPlayListFilesView selectedRow] == -1)
		[mDeleteButton setEnabled:NO];
	else
		[mDeleteButton setEnabled:YES];
}

@end
