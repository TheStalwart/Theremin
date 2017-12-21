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

#import "Directory.h"
#import "WindowController.h"

// FIXME: we need a way to free the cached stuff..

NSString *gDirectoryPropertyPath = @"gDirectoryPropertyPath"; 
NSString *gDirectoryPropertyDirectoryEntries = @"gDirectoryPropertyDirectoryEntries";
NSString *gDirectoryPropertyParent = @"gDirectoryPropertyParent";
NSString *gDirectoryPropertyDirectorySongEntries = @"gDirectoryPropertyDirectorySongEntries";

@implementation Directory
+ (id)directoryWithPath:(NSString *)aPath {
	return [[[Directory alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString *)aPath {
	self = [super init];
	if (self != nil) {
		mValues = [[NSMutableDictionary dictionary] retain];
		if (aPath != nil) {
			[mValues setObject:aPath forKey:gDirectoryPropertyPath];
			mValid = YES;
		} else {
			mValid = NO;
		}
	}
	return self;
}

+ (id)directoryWithDirectory:(Directory *)aDirectory {
	return [[[Directory alloc] initWithDirectory:aDirectory] autorelease];
}

- (id)initWithDirectory:(Directory *)aDirectory {
	self = [super init];
	if (self != nil) {
		mValues = [[NSMutableDictionary dictionaryWithDictionary:aDirectory->mValues] retain];
		mValid = aDirectory->mValid;
	}
	return self;
}

- (NSString *) description {
	return [NSString stringWithFormat:@"Directory <%p> Path: %@", self, [self path]];
}

- (void) dealloc {
	[mValues release];
	[super dealloc];
}

- (BOOL) valid {
	return mValid;
}

- (NSString *) path {
	if ([mValues objectForKey:gDirectoryPropertyPath] != nil)
		return [NSString stringWithString:[mValues objectForKey:gDirectoryPropertyPath]];
	return nil;
}

- (void) setPath:(NSString *)aPath {
	[mValues setObject:aPath forKey:gDirectoryPropertyPath];
}

- (NSString *) lastPathComponent {
	if ([mValues objectForKey:gDirectoryPropertyPath] != nil)
		return [[NSString stringWithString:[mValues objectForKey:gDirectoryPropertyPath]] lastPathComponent];
	return nil;
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:mValues];
	[encoder encodeBytes:&mValid length:sizeof(mValid)];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	mValues = [[decoder decodeObject] retain];
	
	NSUInteger length;
	memcpy(&mValid, [decoder decodeBytesWithReturnedLength:&length], sizeof(mValid));
	
	return self;
}

- (NSArray *) directoryEntries {
	if ([mValues objectForKey:gDirectoryPropertyDirectoryEntries])
		return [mValues objectForKey:gDirectoryPropertyDirectoryEntries];
	
	// FIXME: we just assume for now that there is only one client.. this might have to change sometime.
	if ([[[WindowController instance] musicClient] isConnected] == NO)
		return nil;
	
	NSArray *entries = [[[WindowController instance] musicClient] entriesInDirectory:self withTypes:eDirectoryType];
	[mValues setObject:entries forKey:gDirectoryPropertyDirectoryEntries];

	return entries;
}

- (NSArray *)songs {
	if ([mValues objectForKey:gDirectoryPropertyDirectorySongEntries])
		return [mValues objectForKey:gDirectoryPropertyDirectorySongEntries];
	
	// FIXME: we just assume for now that there is only one client.. this might have to change sometime.
	if ([[[WindowController instance] musicClient] isConnected] == NO)
		return nil;
	
	NSArray *songs = [[[WindowController instance] musicClient] entriesInDirectory:self withTypes:eSongType];
	[mValues setObject:songs forKey:gDirectoryPropertyDirectorySongEntries];
	
	return songs;
}

- (Directory *) parent {
	if ([mValues objectForKey:gDirectoryPropertyParent])
		return [Directory directoryWithDirectory:[mValues objectForKey:gDirectoryPropertyParent]];
	return nil;
}

@end
