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

@class PWSeekSlider, PWVolumeImage;

@interface PWVolumeSlider : NSView {
	PWVolumeImage *mImageView;
	PWSeekSlider *mSlider;
	
	NSImage *volumeImageZero;
	NSImage *volumeImage33;
	NSImage *volumeImage66;
	NSImage *volumeImage100;
	
	NSSize mSize;
	
	float mCachedNewVolume;
	float mValueBeforeMute;
}
- (id) initWithFrame:(NSRect)frame;

- (NSSize) size;

- (void) setEnabled:(BOOL)enabled;

- (void) setFloatValue:(float)aValue;
- (float) floatValue;

- (int) intValue;

- (void) setTarget:(id)aTarget;
- (void) setAction:(SEL)aAction;

- (void) updateVolumeImage;

- (void) toggleMute;

@end
