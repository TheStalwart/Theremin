/*
 * This file is part of ChatKit - http://www.chatkit.net
 * Copyright (c) Adam Iser, 2005.  All rights reserved.
 */

#import "GenericSegmentedCell.h"
#import "GenericSegment.h"

@interface NSObject (GenericSegmentedCellAdditions)
- (void)updateCell:(NSCell *)aCell;
@end

@interface GenericSegmentedCell (PRIVATE)
- (void)_init;
@end

/*!
 * @class GenericSegmentedCell
 * @abstract A recreation of NSSegmentedCell with greater capability for customization.
 *
 * This control/cell combination assists with the creation of NSSegmentedControls with a customized appearance.
 *
 * Note: This default cell class performs NO drawing or autosizing.  You will need to create a custom subclass and 
 *       provide your custom drawing and sizing code.
 *
 * Possible improvements:
 *  - Don't install tracking rects if rollover effect is disabled
 */
@implementation GenericSegmentedCell

/*!
 * @abstract Init
 */
- (id)init
{
	if ((self = [super init])) {
		[self _init];
	}
	
	return self;
}

/*!
 * @abstract Init text cell
 */
- (id)initTextCell:(NSString *)aString;
{
	if ((self = [super initTextCell:aString])) {
		[self _init];
	}
	
	return self;
}

/*!
 * @abstract Init image cell
 */
- (id)initImageCell:(NSImage *)image;
{
	if ((self = [super initImageCell:image])) {
		[self _init];
	}
	
	return self;
}

/*!
 * @abstract Common init
 */
- (void)_init
{
	hoveredSegment = -1;
	pressedSegment = -1;
	selectedSegment = -1;
	trackingSegment = -1;
	
	showRollover = NO;
	isActive = YES;
	
	//Stop NSCell from sending actions.  We will send actions manually for finer control
	[self sendActionOn:0];
}

/*!
 * @abstract Dealloc
 */
- (void)dealloc
{
	[segments release]; segments = nil;
	
	[super dealloc];
}

/*!
 * @abstract Set control view
 */
- (void)setControlView:(NSView*)view
{
	[super setControlView:view];

	//Check implementation now so we only have to check once
	controlViewRespondsToUpdateCell = [[self controlView] respondsToSelector:@selector(updateCell:)];
}


//Global Properties ----------------------------------------------------------------------------------------------------
#pragma mark Forwarded to cell
/*!
 * @abstract Enabled/Disable showing of roll over effect
 */
- (void)setShowRollover:(BOOL)flag {
	showRollover = flag;
}
- (BOOL)showRollover {
	return showRollover;
}

/*!
 * @abstract Set/Get segment count
 *
 * All segment properties are reset when the segment count is changed.
 */
- (void)setSegmentCount:(int)count
{
	if ([segments count] != count) {
		[segments release];
		segments = [[NSMutableArray alloc] initWithCapacity:count];
		
		//Create the segment data containers
		int i;
		for (i = 0; i < count; i ++) {
			[segments addObject:[[[GenericSegment alloc] init] autorelease]];
		}
	}
}
- (int)segmentCount {
	return [segments count];
}

/*!
 * @abstract Set/Get tracking mode
 */
- (void)setTrackingMode:(NSSegmentSwitchTracking)newTrackingMode {
	trackingMode = newTrackingMode;
}
- (NSSegmentSwitchTracking)trackingMode {
	return trackingMode;
}

/*!
 * @abstract Set/Get selected segment
 */
- (void)setSelectedSegment:(int)segment {
	selectedSegment = segment;
}
- (int)selectedSegment {
	return selectedSegment;
}

/*!
 * @abstract Select a segment by tag
 */
- (BOOL)selectSegmentWithTag:(int)tag
{
	NSEnumerator	*enumerator = [segments objectEnumerator];
	GenericSegment	*segment;
	int 			segmentIndex = 0;
	
	while ((segment = [enumerator nextObject])) {
		if ([segment tag] == tag) {
			[self setSelectedSegment:segmentIndex];
			return YES;
		}
		segmentIndex++;
	}
	
	return NO;
}

/*!
 * @abstract Set/Get hovered segment
 */
- (void)setHoveredSegment:(int)segment
{
	if (hoveredSegment != segment) {
		hoveredSegment = segment;
		if (controlViewRespondsToUpdateCell) [[self controlView] updateCell:self];
	}
}
- (int)hoveredSegment {
	return hoveredSegment;
}

/*!
 * @abstract Set/Get pressed segment
 */
- (void)setPressedSegment:(int)segment
{
	if (pressedSegment != segment) {
		pressedSegment = segment;
		if (controlViewRespondsToUpdateCell) [[self controlView] updateCell:self];
	}
}
- (int)pressedSegment {
	return pressedSegment;
}

/*!
 * @abstract Set/Get active state of this cell
 */
- (void)setActive:(BOOL)flag
{
	if (isActive != flag) {
		isActive = flag;
		if (controlViewRespondsToUpdateCell) [[self controlView] updateCell:self];
	}
}
- (BOOL)isActive {
	return isActive;
}

- (void)makeNextSegmentKey
{
	/* Select the next segment. Since we don't support anything but momentary presses, this is currently a no-op. */
}

- (void)makePreviousSegmentKey
{
	/* Select the previous segment. Since we don't support anything but momentary presses, this is currently a no-op. */	
}

//Segment properties ---------------------------------------------------------------------------------------------------
#pragma mark Segment properties
/*!
 * @abstract Set/Get segment width
 */
- (void)setWidth:(float)width forSegment:(int)segment {
	[((GenericSegment *)[segments objectAtIndex:segment]) setWidth:width];
	[self invalidateDrawInfo]; //must re-calc sizing
}
- (float)widthForSegment:(int)segment {
	return [((GenericSegment *)[segments objectAtIndex:segment]) width];
}

/*!
 * @abstract Set/Get segment image
 */
- (void)setImage:(NSImage *)image forSegment:(int)segment {
	[[segments objectAtIndex:segment] setImage:image];
	[self invalidateDrawInfo]; //must re-calc sizing
}
- (NSImage *)imageForSegment:(int)segment {
	return [[segments objectAtIndex:segment] image];
}

/*!
 * @abstract Set/Get segment label
 */
- (void)setLabel:(NSString *)label forSegment:(int)segment {
	[[segments objectAtIndex:segment] setLabel:label];
	[self invalidateDrawInfo]; //must re-calc sizing
}
- (NSString *)labelForSegment:(int)segment{
	return [[segments objectAtIndex:segment] label];
}

/*!
 * @abstract Set/Get segment menu
 */
- (void)setMenu:(NSMenu *)menu forSegment:(int)segment {
	[[segments objectAtIndex:segment] setMenu:menu];
	[self invalidateDrawInfo]; //must re-calc sizing
}
- (NSMenu *)menuForSegment:(int)segment {
	return [[segments objectAtIndex:segment] menu];
}

/*!
 * @abstract Set/Get segment tooltip
 */
- (void)setToolTip:(NSString *)toolTip forSegment:(int)segment {
	[[segments objectAtIndex:segment] setToolTip:toolTip];
}
- (NSString *)toolTipForSegment:(int)segment {
	return [[segments objectAtIndex:segment] toolTip];
}
- (BOOL)_hasItemTooltips
{
	return YES;
}
- (void)_setNeedsToolTipRecalc:(id)sender
{
	/* Called by NSSegmentedControl when we need to relaclulate tooltips... */
}

/*!
 * @abstract Set/Get segment tag
 */
- (void)setTag:(int)tag forSegment:(int)segment {
	[((GenericSegment *)[segments objectAtIndex:segment]) setTag:tag];
}
- (int)tagForSegment:(int)segment {
	return [((GenericSegment *)[segments objectAtIndex:segment]) tag];
}

/*!
 * @abstract Set/Get segment selected
 */
- (void)setSelected:(BOOL)selected forSegment:(int)segment {
	[[segments objectAtIndex:segment] setSelected:selected];
}
- (BOOL)isSelectedForSegment:(int)segment {
	return [[segments objectAtIndex:segment] isSelected];
}

/*!
 * @abstract Set/Get segment enabled
 */
- (void)setEnabled:(BOOL)enabled forSegment:(int)segment {
	[[segments objectAtIndex:segment] setEnabled:enabled];
}
- (BOOL)isEnabledForSegment:(int)segment {
	return [[segments objectAtIndex:segment] isEnabled];
}


//Cursor Tracking ------------------------------------------------------------------------------------------------------
#pragma mark Cursor Tracking
/*!
 * @abstract Reset cursor tracking
 */
- (void)resetCursorRect:(NSRect)cellFrame inView:(NSView *)controlView
{
	[self calcDrawInfo:cellFrame];	
	[self removeCursorRects];

	//Install cursor tracking and tooltip rects
	NSEnumerator	*enumerator = [segments objectEnumerator];
	GenericSegment	*segment;
	int 			segmentIndex = 0;
	
	while ((segment = [enumerator nextObject])) {
		[segment setTrackingTag:[controlView addTrackingRect:[segment frame]
													   owner:self
													userData:[NSNumber numberWithInt:segmentIndex]
												assumeInside:NO]];
		[controlView addToolTipRect:[segment frame]
							  owner:[segment toolTip]
						   userData:nil];
		
		segmentIndex++;
	}
		
	trackingView = controlView;
}

/*!
 * @abstract Remove cursor tracking
 */
- (void)removeCursorRects
{
	NSEnumerator	*enumerator = [segments objectEnumerator];
	GenericSegment	*segment;
	
	while ((segment = [enumerator nextObject])) {
		[trackingView removeTrackingRect:[segment trackingTag]];
		[segment setTrackingTag:0];
	}
	
	//Remove tooltips
	[trackingView removeAllToolTips];
	
	//Unset any hovered segments when the tracking rects are removed
	[self setHoveredSegment:-1];
}

/*!
 * @abstract Mouse entered, highlight the rolled over segment
 */
- (void)mouseEntered:(NSEvent *)theEvent
{
	int	segment = [(NSNumber *)[theEvent userData] intValue];
	
	if ([self showRollover] && [self isEnabledForSegment:segment]) {
		[self setHoveredSegment:segment];
	}
}

/*!
 * @abstract Mouse exited, remove segment highlight
 */
- (void)mouseExited:(NSEvent *)theEvent
{
	if ([self hoveredSegment] == [(NSNumber *)[theEvent userData] intValue]) {
		[self setHoveredSegment:-1];
	}
}

- (void)displayMenuForSegment:(int)segment inView:(NSView *)controlView
{	
	NSRect segmentFrame = [[segments objectAtIndex:segment] frame];
	NSPoint point = [controlView convertPoint:segmentFrame.origin toView:nil];
	point.y -= NSHeight(segmentFrame) + 2;
	point.x -= 1;
	
	NSEvent *currentEvent = [NSApp currentEvent];
	NSEvent *event = [NSEvent mouseEventWithType:[currentEvent type]
										location:point
								   modifierFlags:[currentEvent modifierFlags]
									   timestamp:[currentEvent timestamp]
									windowNumber:[[currentEvent window] windowNumber]
										 context:[currentEvent context]
									 eventNumber:[currentEvent eventNumber]
									  clickCount:[currentEvent clickCount]
										pressure:[currentEvent pressure]];
	[NSMenu popUpContextMenu:[self menuForSegment:segment]
				   withEvent:event
					 forView:controlView];
	[self setPressedSegment:-1];
}

/*!
 * @abstract Begin mouse-down tracking
 */
- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
	trackingSegment = [self segmentAtPoint:startPoint];

	if (trackingSegment != -1 && [self isEnabledForSegment:trackingSegment]) {
		[self setPressedSegment:trackingSegment];

		if ([self menuForSegment:trackingSegment]) {
			[self displayMenuForSegment:trackingSegment inView:controlView];
		}

		return YES;
	} else {
		return NO;
	}
}

/*!
 * @abstract Update pressed state during tracking
 */
- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
	if ([self segmentAtPoint:currentPoint] == trackingSegment) {
		[self setPressedSegment:trackingSegment];
	}else{
		[self setPressedSegment:-1];
	}
	
	return YES;
}

/*!
 * @abstract Finish mouse-down tracking
 */
- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
	[self setPressedSegment:-1];

	if ([self segmentAtPoint:stopPoint] == trackingSegment) {
		[self setSelectedSegment:trackingSegment];
		
		if (![self menuForSegment:trackingSegment]) {
			//Don't send the action if we displayed a menu
			[(NSControl *)[self controlView] sendAction:[self action] to:[self target]];
		}
	}
}

//Drawing & Sizing -----------------------------------------------------------------------------------------------------
#pragma mark Drawing & Sizing
/*!
 * @abstract Draw
 */
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[self calcDrawInfo:cellFrame];

	//Draw the background of each segment
	NSEnumerator	*enumerator = [segments objectEnumerator];
	GenericSegment	*segment;
	int				segmentIndex = 0;

	while ((segment = [enumerator nextObject])) {
		[self drawBackgroundForSegment:segmentIndex inFrame:[segment frame] withView:controlView];
		segmentIndex++;
	}
	
	//Draw cell interior
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

/*!
 * @abstract Draw cell interior
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSEnumerator	*enumerator = [segments objectEnumerator];
	GenericSegment	*segment;
	int				segmentIndex = 0;
	
	while ((segment = [enumerator nextObject])) {
		[self drawSegment:segmentIndex inFrame:[segment frame] withView:controlView];
		segmentIndex++;
	}
}

/*!
 * @abstract Calculate and return the desired cell size
 */
- (NSSize)cellSizeForBounds:(NSRect)aRect
{
	[self calcDrawInfo:aRect];

	return NSMakeSize(desiredWidth, aRect.size.height);
}

/*!
 * @abstract Calculate drawing related frame info.
 *
 * Frames will only be recalculated if cellFrame differs from the last time calcDrawInfo was called.  To force
 * recalculation, invoke invalidateDrawInfo.
 */
- (void)calcDrawInfo:(NSRect)cellFrame
{
	if (!NSEqualRects(cellFrame,sizedForFrame)) {
		NSEnumerator	*enumerator;
		GenericSegment	*segment;
		int				segmentIndex;
		float 			totalWidth = 0, flexibleWidth = 0;
		
		sizedForFrame = cellFrame;
		
		//Calculate desired width, flexible width
		enumerator = [segments objectEnumerator];
		segmentIndex = 0;

		while ((segment = [enumerator nextObject])) {
			float segmentWidth = [segment width];
			
			if (segmentWidth == 0) {
				segmentWidth = [self autosizeWidthForSegment:segmentIndex];
				flexibleWidth += segmentWidth;
			}
			
			totalWidth += segmentWidth;
			segmentIndex++;
		}
		
		desiredWidth = totalWidth;
		
		//If cellFrame isn't wide enough, generate a scale for our flexible cells
		float flexRatio = 1.0;
		
		if (totalWidth > cellFrame.size.width && flexibleWidth != 0) {
			flexRatio = (cellFrame.size.width - (totalWidth - flexibleWidth)) / flexibleWidth;
		}
		
		//Generate segment rects based on the scale
		enumerator = [segments objectEnumerator];
		segmentIndex = 0;

		while ((segment = [enumerator nextObject])) {
			float segmentWidth = [segment width];
			float minimumWidth = [self minimumWidthForSegment:segmentIndex];
			
			//Automatically size segments with width 0 (factoring in scale)
			if (segmentWidth == 0) {
				segmentWidth = [self autosizeWidthForSegment:segmentIndex] * flexRatio;
			}

			//Keep segments above their minimum width
			if (segmentWidth < minimumWidth) {
				segmentWidth = minimumWidth;
			}
			
			cellFrame.size.width = segmentWidth;
			[segment setFrame:NSMakeRect((int)cellFrame.origin.x,
										 (int)cellFrame.origin.y,
										 (int)cellFrame.size.width,
										 (int)cellFrame.size.height)];
			
			cellFrame.origin.x += segmentWidth;
			segmentIndex++;
		}
	}
}

/*!
 * @abstract Invalidate drawing information calculated by calcDrawInfo
 *
 * Invoke after changing segment properties in such a way that would require resizing or re-layout.
 */
- (void)invalidateDrawInfo
{
	sizedForFrame = NSZeroRect;
}

/*!
 * @abstract Find the segment at a specific point
 *
 * @return Index of segment at point, -1 if no segments exist at point.
 */
- (int)segmentAtPoint:(NSPoint)point
{
	NSEnumerator	*enumerator = [segments objectEnumerator];
	GenericSegment	*segment;
	int				segmentIndex = 0;
	
	while ((segment = [enumerator nextObject])) {
		if (NSPointInRect(point, [segment frame])) return segmentIndex;
		segmentIndex++;
	}
	
	return -1;
}

/*!
 * @abstract Draw background of a segment
 *
 * Subcasses should override this method to provide custom segment drawing
 * @param segment Index of segment to draw
 * @param frame	Frame of segment within cell
 * @param controlView Containing control view in which drawing will occur
 */
- (void)drawBackgroundForSegment:(int)segment inFrame:(NSRect)frame withView:(NSView *)controlView
{
	//For subclasses
}

/*!
 * @abstract Draw content of a segment
 *
 * Subcasses should override this method to provide custom segment drawing
 * @param segment Index of segment to draw
 * @param frame	Frame of segment within cell
 * @param controlView Containing control view in which drawing will occur
 */
- (void)drawSegment:(int)segment inFrame:(NSRect)frame withView:(NSView *)controlView
{
	//For subclasses
}

/*!
 * @abstract Calculate and return the desired width of a segment
 *
 * Subcasses should override this method to provide custom segment sizing
 * @param segment Index of segment to draw
 * @return Width that segment desires for drawing
 */
- (float)autosizeWidthForSegment:(int)segment
{
	return 0; //For subclasses
}

/*!
 * @abstract Calculate and return the mininum allowed width of a segment
 *
 * Subcasses should override this method to provide custom segment sizing
 * @param segment Index of segment to draw
 * @return Width that segment requires for drawing
 */
- (float)minimumWidthForSegment:(int)segment
{
	return 0; //For subclasses
}

- (BOOL)_anySegmentShowsBadge {
	return NO;
}

@end
