/*
 * This file is part of ChatKit - http://www.chatkit.net
 * Copyright (c) Adam Iser, 2005.  All rights reserved.
 */

#import <Cocoa/Cocoa.h>


@interface GenericSegmentedCell : NSActionCell {
	NSMutableArray			*segments;
	
	NSView					*trackingView;
	NSSegmentSwitchTracking	trackingMode;

	NSRect		sizedForFrame;
	float		desiredWidth;
	
	int			hoveredSegment;
	int			pressedSegment;
	int			selectedSegment;
	int			trackingSegment;

	BOOL		showRollover;
	BOOL		isActive;
	
	BOOL		controlViewRespondsToUpdateCell;
}

- (void)removeCursorRects;

/* Cell Properties */
- (void)setSegmentCount:(int)count;
- (int)segmentCount;
- (void)setTrackingMode:(NSSegmentSwitchTracking)newTrackingMode;
- (NSSegmentSwitchTracking)trackingMode;
- (void)setShowRollover:(BOOL)flag;
- (BOOL)showRollover;
- (void)setSelectedSegment:(int)segment;
- (BOOL)selectSegmentWithTag:(int)tag;
- (int)selectedSegment;

/* Segment Properties */
- (void)setWidth:(float)width forSegment:(int)segment;
- (float)widthForSegment:(int)segment;
- (void)setImage:(NSImage *)image forSegment:(int)segment;
- (NSImage *)imageForSegment:(int)segment;
- (void)setLabel:(NSString *)label forSegment:(int)segment;
- (NSString *)labelForSegment:(int)segment;
- (void)setMenu:(NSMenu *)menu forSegment:(int)segment;
- (NSMenu *)menuForSegment:(int)segment;
- (void)setToolTip:(NSString *)toolTip forSegment:(int)segment;
- (NSString *)toolTipForSegment:(int)segment;
- (void)setTag:(int)tag forSegment:(int)segment;
- (int)tagForSegment:(int)segment;
- (void)setSelected:(BOOL)selected forSegment:(int)segment;
- (BOOL)isSelectedForSegment:(int)segment;
- (void)setEnabled:(BOOL)enabled forSegment:(int)segment;
- (BOOL)isEnabledForSegment:(int)segment;

/* Drawing state */
- (void)setActive:(BOOL)flag;
- (BOOL)isActive;
- (void)setHoveredSegment:(int)segment;
- (int)hoveredSegment;
- (void)setPressedSegment:(int)segment;
- (int)pressedSegment;
- (int)segmentAtPoint:(NSPoint)point;
- (void)invalidateDrawInfo;

/* Subclasses should implement custom segment drawing and sizing by overriding these methods */
- (void)drawBackgroundForSegment:(int)segment inFrame:(NSRect)frame withView:(NSView *)controlView;
- (void)drawSegment:(int)segment inFrame:(NSRect)frame withView:(NSView *)controlView;
- (float)autosizeWidthForSegment:(int)segment;
- (float)minimumWidthForSegment:(int)segment;

- (BOOL)_anySegmentShowsBadge;

@end
