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

typedef enum {
	eDirectory	= 0x00000001,
	eEntries	= 0x00000002,
	eParent		= 0x00000004
} DirectoryFlags;

@interface Directory : NSObject {
	NSMutableDictionary *mValues;
	BOOL mValid;
}
+ (id)directoryWithPath:(NSString *)aPath;
- (id)initWithPath:(NSString *)aPath;

+ (id)directoryWithDirectory:(Directory *)aDirectory;
- (id)initWithDirectory:(Directory *)aDirectory;

- (NSString *) description;

- (void) dealloc;

- (BOOL) valid;

- (NSString *) path;
- (void) setPath:(NSString *)aPath;

- (NSArray *) directoryEntries;
- (Directory *) parent;
- (NSArray *)songs;

@end
