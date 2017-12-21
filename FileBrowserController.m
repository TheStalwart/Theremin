//
//  FileBrowserController.m
//  Theremin
//
//  Created by kampfgnu on 17/12/2017.
//

#import "FileBrowserController.h"
#import "MusicServerClient.h"
#import "Directory.h"
#import "Song.h"
#import "WindowController.h"
#import "PlayListController.h"
#import "PreferencesController.h"
#import "WindowController.h"

@interface FileBrowserController ()
@property (nonatomic, strong) Directory *currentDirectory;
@end


@implementation FileBrowserController

- (id) init {
	self = [super init];
	if (self != nil) {
		[NSBundle loadNibNamed:@"FileBrowser" owner:self];
		
		mDirectories = [[NSMutableArray array] retain];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(clientConnectionStatusChanged:)
													 name:nMusicServerClientConnected
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(clientConnectionStatusChanged:)
													 name:nMusicServerClientDisconnected
												   object:nil];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[mDirectories release];
	
	[super dealloc];
}

- (void)show {
	[mWindow makeKeyAndOrderFront:self];
}

- (void)clientConnectionStatusChanged:(NSNotification *)notification {
	if (!([[[WindowController instance] currentLibraryDataSource] supportsDataSourceCapabilities] & eLibraryDataSourceSupportsImportingSongs))
		return;
	
	BOOL enableControls = NO;
	
	self.currentDirectory = nil;
	
	if ([[notification name] isEqualTo:nMusicServerClientConnected]) {
		enableControls = YES;
		
		self.currentDirectory = [[[WindowController instance] musicClient] rootDirectory];
		[mTreeController setContent:self.currentDirectory];
		[mTreeController setSelectionIndexPath:[NSIndexPath indexPathWithIndex:0]];
		
		[mBrowser bind:@"content" toObject:mTreeController withKeyPath:@"arrangedObjects" options:nil];
		[mBrowser bind:@"contentValues" toObject:mTreeController withKeyPath:@"arrangedObjects.lastPathComponent" options:nil];
		[mBrowser bind:@"selectionIndexPaths" toObject:mTreeController withKeyPath:@"selectionIndexPaths" options:nil];
	} else if ([[notification name] isEqualTo:nMusicServerClientDisconnected]) {
		enableControls = NO;
		
		[mBrowser unbind:@"content"];
		[mBrowser unbind:@"contentValues"];
		[mBrowser unbind:@"selectionIndexPaths"];
		[mTreeController setContent:[[[Directory alloc] init] autorelease]];
	} else {
		return;
	}
	
	[mTableView reloadData];
	
	[mBrowser setEnabled:enableControls];
}

- (NSArray *)selectedSongsFromTableView {
	NSIndexSet *selection = [mTableView selectedRowIndexes];
	if (self.currentDirectory == nil) {
		return @[];
	}
	else {
		NSMutableArray *songs = [NSMutableArray arrayWithCapacity:selection.count];
		NSUInteger currentIndex = [selection firstIndex];
		while (currentIndex != NSNotFound) {
			[songs addObject:self.currentDirectory.songs[currentIndex]];
			currentIndex = [selection indexGreaterThanIndex:currentIndex];
		}
		
		return songs;
	}
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NSBrowser
////////////////////////////////////////////////////////////////////////

- (IBAction)browserCellSelected:(id)sender {
	NSArray *selectedObjects = [mTreeController selectedObjects];
	if ([selectedObjects count] != 1) {
		NSBeep();
		return;
	}
	
	self.currentDirectory = [selectedObjects firstObject];
	[mTableView reloadData];
}

- (NSArray *)selectedSongsUniqueIdentifiersInTable:(NSTableView *)tableView {
	NSArray *songs = [self selectedSongsFromTableView];
	
	NSMutableArray *uniqueIds = [NSMutableArray array];
	for (int i = 0; i < [songs count]; i++) {
		[uniqueIds addObject:[[songs objectAtIndex:i] uniqueIdentifier]];
	}
	
	return uniqueIds;
}

- (void)replacePlaylistWithSongIdentifiers:(NSArray *)uniqueIdentifiers {
	[[[WindowController instance] musicClient] clearPlaylist];
	[[[WindowController instance] musicClient] addSongsToPlaylistByUniqueIdentifier:uniqueIdentifiers];
	[[[WindowController instance] musicClient] startPlayback];
	
	[[[WindowController instance] playlistController] scheduleShowCurrentSongOnNextSongChange];
	[[[WindowController instance] playlistController] scheduleSelectCurrentSongOnNextSongChange];
}

- (void)appendPlaylistWithSongIdentifiers:(NSArray *)uniqueIdentifiers {
	[[[WindowController instance] musicClient] addSongsToPlaylistByUniqueIdentifier:uniqueIdentifiers];
}

- (NSArray *)uniqueSongIdentifiersOfCurrentBrowserSelection {
	NSArray *selectedObjects = [mTreeController selectedObjects];
	if ([selectedObjects count] != 1) {
		NSBeep();
		return @[];
	}
	
	Directory *firstDir = [selectedObjects firstObject];
	NSMutableArray *songIds = [NSMutableArray array];
	[self addSongIDsOfFolder:firstDir songList:&songIds];
	
	return songIds;
}

- (void)addSongIDsOfFolder:(Directory *)directory songList:(NSMutableArray **)songIDs {
	for (Song *song in directory.songs) {
		[*songIDs addObject:[song uniqueIdentifier]];
	}
	for (Directory *subDir in directory.directoryEntries) {
		[self addSongIDsOfFolder:subDir songList:songIDs];
	}
}

- (IBAction)replacePlaylistWithCurrentDirectory:(id)sender {
	[self replacePlaylistWithSongIdentifiers:[self uniqueSongIdentifiersOfCurrentBrowserSelection]];
}

- (IBAction)addPlaylistWithCurrentDirectory:(id)sender {
	[self appendPlaylistWithSongIdentifiers:[self uniqueSongIdentifiersOfCurrentBrowserSelection]];
}

#pragma mark -
#pragma mark Actions

- (IBAction)replaceFilesInPlaylist:(id)sender {
	if ([self executeActionForTableView:mTableView withSender:sender])
		[self replacePlaylistWithSongIdentifiers:[self selectedSongsUniqueIdentifiersInTable:mTableView]];
}

- (IBAction)appendSongsToPlaylist:(id)sender {
	if ([self executeActionForTableView:mTableView withSender:sender])
		[self appendPlaylistWithSongIdentifiers:[self selectedSongsUniqueIdentifiersInTable:mTableView]];
}

- (void)modifyPlaylistWithSongIDs:(NSArray *)songIDs {
	if (songIDs.count == 0) {
		return;
	}
	
	switch ([[PreferencesController sharedInstance] libraryDoubleClickAction]) {
		case eLibraryDoubleClickReplaces:
			[self replacePlaylistWithSongIdentifiers:songIDs];
			break;
		case eLibraryDoubleClickAppends:
			[self appendPlaylistWithSongIdentifiers:songIDs];
			break;
	}
}

- (IBAction)tableAction:(id)sender {
	NSArray *songIDs = [self selectedSongsUniqueIdentifiersInTable:mTableView];
	[self modifyPlaylistWithSongIDs:songIDs];
}

- (IBAction)doubleActionForBrowserDirectory:(id)sender {
	NSArray *songIDs = [self uniqueSongIdentifiersOfCurrentBrowserSelection];
	[self modifyPlaylistWithSongIDs:songIDs];
}

- (IBAction) getInfoOnSongs:(id)sender {
	[[WindowController instance] getInfoOnSongs:[self selectedSongsFromTableView]];
}

- (BOOL) executeActionForTableView:(PWTableView *)aTableView withSender:(id)sender {
	// if we were called using our PWTableView action character stuff, let it through
	if ([aTableView characterActionInProgress] == NO)
		// if clicked row is -1, the header could have been clicked - don't continue.
		if ([aTableView clickedRow] == -1)
			// if we are called from a context menu or toolbar item, also let it through
			if ([sender isKindOfClass:[NSMenuItem class]] == NO && [sender isKindOfClass:[NSToolbarItem class]] == NO)
				return NO;
	
	return YES;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - tableview stuff
////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.currentDirectory != nil ? self.currentDirectory.songs.count : 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if (self.currentDirectory == nil) {
		return @"nothing";
	}
	
	Song *song = self.currentDirectory.songs[row];
	
	if ([[tableColumn identifier] isEqualToString:@"length"]) {
		int time = [[song valueForKey:@"time"] intValue];
		return [NSString stringWithFormat:@"%d:%02d", time / 60, time % 60];
	} else if ([[tableColumn identifier] isEqualToString:@"artist.name"]) {
		return [song artist];
	} else if ([[tableColumn identifier] isEqualToString:@"composer.name"]) {
		return [song composer];
	} else if ([[tableColumn identifier] isEqualToString:@"album.name"]) {
		return [song album];
	} else if ([[tableColumn identifier] isEqualToString:@"song.date"]) {
		return [song date];
	} else if ([[tableColumn identifier] isEqualToString:@"title"]) {
		NSString *title = [song title];
		if (title == nil || [title length] == 0)
			return [[song file] lastPathComponent];
		else
			return title;
	}
	
	return [song valueForKeyPath:[tableColumn identifier]];
}

@end
