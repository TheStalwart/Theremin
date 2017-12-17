/*
 Copyright (C) 2006-2008  Patrik Weiskircher
 
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

#import "LibrarySubControllerBase.h"
#import "LibraryController.h"
#import "Song.h"
#import "SQLController.h"
#import "PlayListController.h"
#import "LibrarySearchController.h"
#import "WindowController.h"

@interface LibrarySubControllerBase (PrivateMethods)
- (int) convertToDisplayIndex:(int)i;
- (int) convertToListIndex:(int)i;
- (void) setIgnoreSelectionChanged:(BOOL)value;

- (NSString *)liveSearchColumn;
- (void) customTableViewSetup;

- (void) updateLibraryDataSource;
@end

@implementation LibrarySubControllerBase
- (id) initWithTableView:(PWTableView *)aTableView andLibraryController:(LibraryController *)aLibraryController andHasAllEntry:(BOOL)allEntry {
	self = [super init];
	if (self != nil) {
		mTableView = aTableView;
		mLibraryController = aLibraryController;
		
		[mTableView setDataSource:self];
		[mTableView setDelegate:self];
		
		[mTableView setDoubleAction:@selector(tableAction:)];
		[mTableView setTarget:mLibraryController];
		
		[[NSNotificationCenter defaultCenter] addObserver:mLibraryController selector:@selector(tableViewBecameFirstResponder:) 
													 name:nBecameFirstResponder
												   object:mTableView];
		
		if (allEntry)
			[mTableView selectAllSelectsRow:0];
		
		mHasAllEntry = allEntry;
		
		[mTableView setColumnIdentifierToSearch:[self liveSearchColumn]];
		[mTableView setLiveSearchEnabled:YES];
		
		unichar returnActionKeys[] = { NSCarriageReturnCharacter };
		NSCharacterSet *returnCharacterSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:returnActionKeys length:1]];
		
		[mTableView setActionForCharacters:returnCharacterSet withModifiers:NSAlternateKeyMask onTarget:aLibraryController usingSelector:@selector(appendSongsToPlaylist:)];
		[mTableView setActionForCharacters:returnCharacterSet onTarget:aLibraryController usingSelector:@selector(replaceFilesInPlaylist:)];
		
		unichar escapeActionKeys[] = { 0x1b };
		NSCharacterSet *escapeCharacterSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:escapeActionKeys length:1]];
		[mTableView setActionForCharacters:escapeCharacterSet onTarget:aLibraryController usingSelector:@selector(stopSearch:)];
		
		if ([self respondsToSelector:@selector(customTableViewSetup)])
			[self customTableViewSetup];
	}
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[mItems release];
	[super dealloc];
}


#pragma mark -
#pragma mark Conversion

- (int) convertToDisplayIndex:(int)i {
	return mHasAllEntry ? i + 1 : i;
}

- (int) convertToListIndex:(int)i {
	return mHasAllEntry ? i - 1 : i;
}

#pragma mark -
#pragma mark Disable/Enable

- (void) clearAndDisable {
	[mItems release], mItems = nil;
	[mTableView reloadData];
	[mTableView setEnabled:NO];
}

- (void) enable {
	[mTableView setEnabled:YES];
}

#pragma mark -
#pragma mark Selection Stuff

- (NSArray *) getSelected:(BOOL*)allSelected {
	NSIndexSet *selection = [mTableView selectedRowIndexes];
	if (([selection containsIndex:0] || [selection count] == 0) && mHasAllEntry) {
		if (allSelected != NULL) {
			*allSelected = YES;
		}
		return [NSArray arrayWithArray:mItems];
	} else {
		NSUInteger indexes[20];
		NSRange range = NSMakeRange([self convertToDisplayIndex:0], [self convertToDisplayIndex:[mItems count]]);
		
		NSUInteger returnValue;
		NSMutableArray *selectedItems = [NSMutableArray array];
		
		while ( (returnValue = [selection getIndexes:indexes maxCount:20 inIndexRange:&range])) {
			for (int i = 0; i < returnValue; i++) {
				NSObject *item = [mItems objectAtIndex:[self convertToListIndex:indexes[i]]];
				if (item != nil)
					[selectedItems addObject:item];
			}
			if (returnValue < 20)
				break;
		}
		
		if (allSelected != NULL) {
			*allSelected = NO;
		}
		return selectedItems;
	}
}

- (id) saveSelectionInformationWithSelectedSongs:(NSArray *)selectedEntries {
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	BOOL selectCompilation = NO;
	
	for (int i = 0; i < [selectedEntries count]; i++) {
		int sqlIdentifier = [(id<ThereminEntity>)[selectedEntries objectAtIndex:i] identifier];
		
		if (sqlIdentifier == CompilationSQLIdentifier)
			selectCompilation = YES;
		
		if (sqlIdentifier < 0)
			continue;
		
		[indexSet addIndex:sqlIdentifier];
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:indexSet, @"indexes", [NSNumber numberWithBool:selectCompilation], @"compilation", nil];
}

- (void) loadSelectionInformation:(id)data withEntries:(NSArray *)theEntries{
	NSIndexSet *indexes = [data objectForKey:@"indexes"];
	BOOL selectCompilation = [[data objectForKey:@"compilation"] boolValue];
	
	BOOL first = YES;
	for (int i = 0; i < [theEntries count]; i++) {
		int sqlIdentifier = [(id<ThereminEntity>)[theEntries objectAtIndex:i] identifier];
		if ([indexes containsIndex:sqlIdentifier] || (selectCompilation == YES && sqlIdentifier == CompilationSQLIdentifier)) {
			[mTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[self convertToDisplayIndex:i]] byExtendingSelection:!first];
			
			if (first == YES) {
				[mTableView scrollRowToVisible:[self convertToDisplayIndex:i]];
				first = NO;
			}
		}
	}
	
	if ([indexes count] <= 0 || first == YES) {
		[mTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[mTableView scrollRowToVisible:0];
	}
}

- (void) saveSelection {
	[mSelectionData release], mSelectionData = nil;
	
	BOOL allSelected;
	NSArray *selectedItems = [self getSelected:&allSelected];
	
	if (!allSelected)
		mSelectionData = [[self saveSelectionInformationWithSelectedSongs:selectedItems] retain];	
}

#pragma mark -
#pragma mark Data gathering

- (void) reloadData {
	[self updateLibraryDataSource];
	
#ifdef SQL_DEBUG
	NSLog(@"%@: reloadData", [self class]);
#endif
	
	[mItems release], mItems = nil;
	
	NSMutableArray *filters = [[mLibraryController searchController] musicSearchFilters];
	if (!filters)
		filters = [NSMutableArray array];

	NSArray *controllers = [mLibraryController getOrderedListOfSubControllers];
	
	BOOL addFilters = YES;
	for (int i = 0; i < [controllers count]; i++) {
		LibrarySubControllerBase *controller = [controllers objectAtIndex:i];
		if (controller == self)
			addFilters = NO;
		
		if (addFilters)
			[controller addRequiredFilters:filters];
	}
	
#ifdef SQL_DEBUG
	NSLog(@"before");
#endif
	
	[self requestFilteredItems:filters];
}

- (void) receivedResults:(NSArray *)items {
	mItems = [[self sortedArray:items] retain];
	
#ifdef SQL_DEBUG
	NSLog(@"after");
#endif
	
	mIgnoreSelectionChanged = YES;
	[mTableView reloadData];
	
	if (!mSelectionData) {
		[mTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[mTableView scrollRowToVisible:0];
	} else
		[self loadSelectionInformation:mSelectionData withEntries:mItems];
	[mSelectionData release], mSelectionData = nil;
	mIgnoreSelectionChanged = NO;
}

#pragma mark -
#pragma mark Table View Stuff

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return mHasAllEntry ? [mItems count] + 1 : [mItems count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if (row == 0 && mHasAllEntry)
		return [self getDisplayTitleOfAllItem];
	
	return [[mItems objectAtIndex:[self convertToListIndex:row]] name];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if (mIgnoreSelectionChanged)
		return;
	
	NSArray *controllers = [mLibraryController getOrderedListOfSubControllers];
	BOOL reloadData = NO;
	for (int i = 0; i < [controllers count]; i++) {
		LibrarySubControllerBase *controller = [controllers objectAtIndex:i];
		if (reloadData) {
			[controller saveSelection];
			[controller reloadData];
		}
		if (controller == self)
			reloadData = YES;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard {
	if ([rowIndexes count] == 1)
		[aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[rowIndexes firstIndex]] byExtendingSelection:NO];

	NSArray *uniqueIdentifiers = [mLibraryController selectedSongsUniqueIdentifiersInTable:aTableView];
	
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:uniqueIdentifiers];
	[pboard declareTypes:[NSArray arrayWithObject:gMpdUniqueIdentifierType] owner:self];
	[pboard setData:data forType:gMpdUniqueIdentifierType];
	
	return YES;
}

- (id<LibraryDataSourceProtocol>) libraryDataSource {
	return [[_libraryDataSource retain] autorelease];
}

- (void) updateLibraryDataSource {
	[_libraryDataSource release];
	_libraryDataSource = [[[WindowController instance] currentLibraryDataSource] retain];
	
	[mItems release], mItems = nil;
	[mTableView reloadData];
	
	[mTableView setAllowsMultipleSelection:[_libraryDataSource supportsDataSourceCapabilities] & eLibraryDataSourceSupportsMultipleSelection];
}

#pragma mark -
#pragma mark Overrideable

- (void) addRequiredFilters:(NSMutableArray *)filters {
	
}

- (void) requestFilteredItems:(NSArray *)filters {
}

- (NSString *) getDisplayTitleOfAllItem {
	return @"";
}

- (NSArray *) sortedArray:(NSArray *)items {
	return [items sortedArrayUsingSelector:@selector(compareTo:)];
}

@end
