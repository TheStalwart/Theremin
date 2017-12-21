//
//  FileBrowserController.h
//  Theremin
//
//  Created by kampfgnu on 17/12/2017.
//

#import <Cocoa/Cocoa.h>

#import "PWTableView.h"

@class PWWindow;

@interface FileBrowserController : NSObject <NSTableViewDataSource, NSTableViewDelegate> {
	IBOutlet PWWindow *mWindow;
	IBOutlet NSBrowser *mBrowser;
	IBOutlet NSTreeController *mTreeController;
	NSMutableArray *mDirectories;
	IBOutlet PWTableView *mTableView;
	IBOutlet PWTableView *mSongView;
}

- (id) init;
- (void) dealloc;

- (void) show;

@end
