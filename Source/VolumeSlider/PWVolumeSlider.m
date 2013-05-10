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

#import "PWVolumeSlider.h"
#import "MusicServerClient.h"
#import "WindowController.h"
#import "PWVolumeImage.h"
#import "PWSeekSlider.h"
#import "PWSeekSliderCell.h"

@implementation PWVolumeSlider
- (id) initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self != nil) {
		volumeImageZero = [[NSImage imageNamed:@"volumeZero"] retain];
		volumeImage33 = [[NSImage imageNamed:@"volume33"] retain];
		volumeImage66 = [[NSImage imageNamed:@"volume66"] retain];
		volumeImage100 = [[NSImage imageNamed:@"volume100"] retain];
		
		if (volumeImageZero == nil || volumeImage33 == nil || volumeImage66 == nil || volumeImage100 == nil) {
			NSLog(@"some images could not be loaded.");
		}
		
		mImageView = [[[PWVolumeImage alloc] initWithFrame:NSMakeRect(0, -1.5, [volumeImage100 size].width, [volumeImage100 size].height)] autorelease];
		[mImageView setImageFrameStyle:NSImageFrameNone];
		[mImageView setEditable:NO];
		[mImageView setImage:volumeImageZero];
		[mImageView setEnabled:NO];
		[mImageView setVolumeSlider:self];
		[self addSubview:mImageView];
		
		mSlider = [[[PWSeekSlider alloc] initWithFrame:NSMakeRect([volumeImage100 size].width + 2, -2.5, 100, [volumeImage100 size].height)] autorelease];
		[mSlider setMinValue:0];
		[mSlider setMaxValue:100];
		[mSlider setIntValue:0];
		[mSlider setEnabled:NO];
		[[mSlider cell] setControlSize:NSSmallControlSize];
		
		[[mSlider cell] setKnobImage:[NSImage imageNamed:@"volume_knob"]];
		
		[self addSubview:mSlider];
		
		mSize.height = 22;
		mSize.width = [volumeImage100 size].width + 2 + 100;
		
		mCachedNewVolume = -1;
	}
	return self;
}

- (void) dealloc {
	[mImageView release];
	[mSlider release];
	[super dealloc];
}

- (NSSize) size {
	return mSize;
}

- (void) setEnabled:(BOOL)enabled {
	[mImageView setEnabled:enabled];
	[mSlider setEnabled:enabled];
}

- (void) setFloatValue:(float)aValue {
	[mSlider setFloatValue:aValue];
	[self updateVolumeImage];
}

- (float) floatValue {
	return [mSlider floatValue];
}

- (int) intValue {
	return [mSlider intValue];
}

- (void) setTarget:(id)aTarget {
	[mSlider setTarget:aTarget];
}

- (void) setAction:(SEL)aAction {
	[mSlider setAction:aAction];
}

- (void) updateVolumeImage {
	int value = [mSlider intValue];
	if (value == 0) {
		[mImageView setImage:volumeImageZero];
	} else if (value >= 1 && value <= 33) {
		[mImageView setImage:volumeImage33];
	} else if (value > 33 && value <= 66) {
		[mImageView setImage:volumeImage66];
	} else if (value > 66) {
		[mImageView setImage:volumeImage100];
	}	
}

- (void) toggleMute {
	if ([self floatValue] > 0) {
		mValueBeforeMute = [self floatValue];
		[self setFloatValue:0];
	} else {
		[self setFloatValue:mValueBeforeMute];
	}
	[[mSlider target] performSelector:[mSlider action] withObject:mSlider];
}

- (void)scrollWheel:(NSEvent *)theEvent {
	float delta = [theEvent deltaY];
	[self setFloatValue:[self floatValue]+delta];
	[[mSlider target] performSelector:[mSlider action] withObject:mSlider];
}

@end
