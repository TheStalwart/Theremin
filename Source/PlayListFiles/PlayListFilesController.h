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

#import <Cocoa/Cocoa.h>
#import "PWTableView.h"

@interface PlayListFilesController : NSObject {
	IBOutlet PWTableView *mPlayListFilesView;
	IBOutlet NSDrawer *mDrawer;
	IBOutlet NSButton *mRefresh;
	IBOutlet NSProgressIndicator *mProgress;
	IBOutlet NSButton *mDeleteButton;
	
	NSArray *mPlaylists;
    NSArray *sortedPlaylists;
	NSTimer *mStartProgressTimer;
	NSDate *mRefreshDate;
	
	IBOutlet NSPanel *mSavePlayListAsPanel;
	IBOutlet NSTextField *mSavePlayListName;
	
	IBOutlet NSPanel *mDeleteConfirmationPanel;
	IBOutlet NSButton *mDeleteConfirmationDoNotAskMeAgainCheckbox;
	IBOutlet NSTextField *mDeleteConfirmationLabel;
	
	BOOL mDraggingSupported;
	NSString *mPathOfNamedPlaylistBeingFetched;
	NSArray *mFetchedNamedPlaylist;
}
- (id) init;
- (void) dealloc;

- (void) toggleDrawer;
- (PWTableView *)playlistFilesView;

- (IBAction) refresh:(id)sender;
- (IBAction) loadSelectedPlaylist:(id)sender;
- (IBAction) deleteSelectedPlaylist:(id)sender;
- (void) deleteSelectedPlaylist;

- (void) saveCurrentPlaylist;
- (IBAction) savePlayListAction:(id)sender;

- (IBAction) deleteConfirmationButtonClicked:(id)sender;

@end
