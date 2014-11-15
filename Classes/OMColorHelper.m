//
//  OMColorHelper.m
//  OMColorHelper
//
//  Created by Ole Zorn on 09/07/12.
//
//

#import "OMColorHelper.h"
#import "OMPlainColorWell.h"
#import "OMColorFrameView.h"
#import <objc/runtime.h>

#define kOMColorHelperHighlightingDisabled	@"OMColorHelperHighlightingDisabled"
#define kOMColorHelperInsertionMode			@"OMColorHelperInsertionMode"

@interface OMColorHelper ()

@property (nonatomic) NSDictionary *colorsDictionary;

@end

@implementation OMColorHelper {
//    NSColorWell *colorWell;
//    NSWindow *inputWindow;
//    NSTextField *textField;
//    NSButton *
}

@synthesize colorWell=_colorWell, colorFrameView=_colorFrameView, textView=_textView, selectedColorRange=_selectedColorRange, selectedColorType=_selectedColorType;

#pragma mark - Plugin Initialization

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id sharedPlugin = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
	});
}

- (instancetype)init {
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
		_selectedColorRange = NSMakeRange(NSNotFound, 0);
		_constantColorsByName = [[NSDictionary alloc] initWithObjectsAndKeys:
								 [[NSColor blackColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]], @"black",
								 [NSColor darkGrayColor], @"darkGray",
								 [NSColor lightGrayColor], @"lightGray",
								 [[NSColor whiteColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]], @"white",
								 [NSColor grayColor], @"gray",
								 [NSColor redColor], @"red",
								 [NSColor greenColor], @"green",
								 [NSColor blueColor], @"blue",
								 [NSColor cyanColor], @"cyan",
								 [NSColor yellowColor], @"yellow",
								 [NSColor magentaColor], @"magenta",
								 [NSColor orangeColor], @"orange",
								 [NSColor purpleColor], @"purple",
								 [NSColor brownColor], @"brown",
								 [[NSColor clearColor] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]], @"clear", nil];
		
        NSString *objcRGBAUIColorPattern = @"(\\[\\s*UIColor\\s+colorWith|\\[\\s*\\[\\s*UIColor\\s+alloc\\]\\s*initWith)Red:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+green:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+blue:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]";
        NSString *swiftRGBAUIColorPattern = @"UIColor\\s*\\(\\s*red\\s*:\\s*([0-9]+\\.?[0-9]*f?)(\\/[0-9]*\\.?[0-9]+f?)?\\s*,\\s*green\\s*:\\s*([0-9]+\\.?[0-9]*f?)(\\/[0-9]*\\.?[0-9]+f?)?\\s*,\\s*blue\\s*:\\s*([0-9]+\\.?[0-9]*f?)(\\/[0-9]*\\.?[0-9]+f?)?\\s*,\\s*alpha\\s*:\\s*([0-9]+\\.?[0-9]*f?)(\\/[0-9]*\\.?[0-9]+f?)?\\s*\\)";
		_rgbaUIColorRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@|%@", objcRGBAUIColorPattern, swiftRGBAUIColorPattern] options:0 error:NULL];
        
        
		_whiteUIColorRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\[\\s*UIColor\\s+colorWith|\\[\\s*\\[\\s*UIColor\\s+alloc\\]\\s*initWith)White:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
		_rgbaNSColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*NSColor\\s+colorWith(Calibrated|Device)Red:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+green:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+blue:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
		_whiteNSColorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[\\s*NSColor\\s+colorWith(Calibrated|Device)White:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s+alpha:\\s*([0-9]*\\.?[0-9]*f?)\\s*(\\/\\s*[0-9]*\\.?[0-9]*f?)?\\s*\\]" options:0 error:NULL];
        
        NSString *colorNames = [[_constantColorsByName allKeys] componentsJoinedByString:@"|"];
		_constantColorRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"\\[?(UI|NS)Color[\\s\\.]+(%@)Color[\\]\\(]\\)?", colorNames] options:0 error:NULL];
	}
	return self;
}

- (void)addColors {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setTitle:@"Select Color map JSON"];
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (NSFileHandlingPanelOKButton == result) {
            NSData *data = [NSData dataWithContentsOfURL:panel.URL];
            NSError *error;
            NSDictionary *colorMap = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

            [colorMap enumerateKeysAndObjectsUsingBlock:^(NSString *colorName, NSDictionary *rgbaInfo, BOOL *stop) {
                [self addColorNamed:colorName
                                red:[rgbaInfo[@"red"] floatValue]
                              green:[rgbaInfo[@"green"] floatValue]
                               blue:[rgbaInfo[@"blue"] floatValue]
                              alpha:[rgbaInfo[@"alpha"] floatValue]];
                
            }];
        }
    }];
}

- (void)addColor {
    NSView *inputView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 62)];
    
    NSColorWell *colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(15, 15, 60, 32)];
    [inputView addSubview:colorWell];
    
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(90, 15, 95, 26)];
    [inputView addSubview:textField];

    NSAlert *alert = [NSAlert alertWithMessageText:@"Add color" defaultButton:@"Add" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"more info..."];
    alert.accessoryView = inputView;
    
    [alert runModal];
}

- (void)addColorNamed:(NSString *)name red:(float)red green:(float)green blue:(float)blue alpha:(float)alpha {
    if (!_customColorsByName) {
        _customColorsByName = [NSMutableDictionary dictionary];
    }
    _customColorsByName[name] = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:alpha];
    
    if (!_customColorRegex) {
        NSString *regexPattern = [NSString stringWithFormat:@"\\[\\s*(UI|NS)Color\\s+(%@)\\s*\\]", [[_customColorsByName allKeys] componentsJoinedByString:@"|"]];
        _customColorRegex = [NSRegularExpression regularExpressionWithPattern:regexPattern options:0 error:NULL];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
	if (editMenuItem) {
		[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem *toggleColorHighlightingMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Colors Under Caret" action:@selector(toggleColorHighlightingEnabled:) keyEquivalent:@""];
		[toggleColorHighlightingMenuItem setTarget:self];
		[[editMenuItem submenu] addItem:toggleColorHighlightingMenuItem];
		
		NSMenuItem *colorInsertionModeItem = [[NSMenuItem alloc] initWithTitle:@"Color Insertion Mode" action:nil keyEquivalent:@""];
		NSMenuItem *colorInsertionModeNSItem = [[NSMenuItem alloc] initWithTitle:@"NSColor" action:@selector(selectNSColorInsertionMode:) keyEquivalent:@""];
		[colorInsertionModeNSItem setTarget:self];
		NSMenuItem *colorInsertionModeUIItem = [[NSMenuItem alloc] initWithTitle:@"UIColor" action:@selector(selectUIColorInsertionMode:) keyEquivalent:@""];
		[colorInsertionModeUIItem setTarget:self];
		
		NSMenu *colorInsertionModeMenu = [[NSMenu alloc] initWithTitle:@"Color Insertion Mode"];
		[colorInsertionModeItem setSubmenu:colorInsertionModeMenu];
		[[colorInsertionModeItem submenu] addItem:colorInsertionModeUIItem];
		[[colorInsertionModeItem submenu] addItem:colorInsertionModeNSItem];
		[[editMenuItem submenu] addItem:colorInsertionModeItem];
		
		NSMenuItem *insertColorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Insert Color..." action:@selector(insertColor:) keyEquivalent:@""];
		[insertColorMenuItem setTarget:self];
		[[editMenuItem submenu] addItem:insertColorMenuItem];
        
        NSMenuItem *addColorNewMenuItem = [[NSMenuItem alloc] initWithTitle:@"Add Color" action:@selector(addColor) keyEquivalent:@""];
        [addColorNewMenuItem setTarget:self];
        [[editMenuItem submenu] addItem:addColorNewMenuItem];
        
        NSMenuItem *addColorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Add Colors" action:@selector(addColors) keyEquivalent:@""];
        [addColorMenuItem setTarget:self];
        [[editMenuItem submenu] addItem:addColorMenuItem];
	}
	
	BOOL highlightingEnabled = ![[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
	if (highlightingEnabled) {
		[self activateColorHighlighting];
	}
}

#pragma mark - Preferences

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(insertColor:)) {
		NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
		return ([firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [firstResponder isKindOfClass:[NSTextView class]]);
	} else if ([menuItem action] == @selector(toggleColorHighlightingEnabled:)) {
		BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
		[menuItem setState:enabled ? NSOffState : NSOnState];
		return YES;
	} else if ([menuItem action] == @selector(selectNSColorInsertionMode:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] integerForKey:kOMColorHelperInsertionMode] == 1 ? NSOnState : NSOffState];
	} else if ([menuItem action] == @selector(selectUIColorInsertionMode:)) {
		[menuItem setState:[[NSUserDefaults standardUserDefaults] integerForKey:kOMColorHelperInsertionMode] == 0 ? NSOnState : NSOffState];
	}
	return YES;
}

- (void)selectNSColorInsertionMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:1 forKey:kOMColorHelperInsertionMode];
}

- (void)selectUIColorInsertionMode:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kOMColorHelperInsertionMode];
}

- (void)toggleColorHighlightingEnabled:(id)sender
{
	BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
	[[NSUserDefaults standardUserDefaults] setBool:!enabled forKey:kOMColorHelperHighlightingDisabled];
	if (enabled) {
		[self activateColorHighlighting];
	} else {
		[self deactivateColorHighlighting];
	}
}

- (void)activateColorHighlighting
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(selectionDidChange:) name:NSTextViewDidChangeSelectionNotification object:nil];
	if (!self.textView) {
		NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
		if ([firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [firstResponder isKindOfClass:[NSTextView class]]) {
			self.textView = (NSTextView *)firstResponder;
		}
	}
	if (self.textView) {
		NSNotification *notification = [NSNotification notificationWithName:NSTextViewDidChangeSelectionNotification object:self.textView];
		[self selectionDidChange:notification];
		
	}
}

- (void)deactivateColorHighlighting
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextViewDidChangeSelectionNotification object:nil];
	[self dismissColorWell];
	//self.textView = nil;
}

#pragma mark - Color Insertion

- (void)insertColor:(id)sender
{
	if (!self.textView) {
		NSResponder *firstResponder = [[NSApp keyWindow] firstResponder];
		if ([firstResponder isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [firstResponder isKindOfClass:[NSTextView class]]) {
			self.textView = (NSTextView *)firstResponder;
		} else {
			NSBeep();
			return;
		}
	}
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled]) {
		//Inserting a color implicitly activates color highlighting:
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kOMColorHelperHighlightingDisabled];
		[self activateColorHighlighting];
	}
	[self.textView.undoManager beginUndoGrouping];
	NSInteger insertionMode = [[NSUserDefaults standardUserDefaults] integerForKey:kOMColorHelperInsertionMode];
	if (insertionMode == 0) {
		[self.textView insertText:@"[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:1.0]" replacementRange:self.textView.selectedRange];
	} else {
		[self.textView insertText:@"[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0]" replacementRange:self.textView.selectedRange];
	}
	[self.textView.undoManager endUndoGrouping];
	[self performSelector:@selector(activateColorWell) withObject:nil afterDelay:0.0];
}

- (void)activateColorWell
{
	[self.colorWell activate:YES];
}

#pragma mark - Text Selection Handling

- (void)selectionDidChange:(NSNotification *)notification
{
	if ([[notification object] isKindOfClass:NSClassFromString(@"DVTSourceTextView")] && [[notification object] isKindOfClass:[NSTextView class]]) {
		self.textView = (NSTextView *)[notification object];
		
		BOOL disabled = [[NSUserDefaults standardUserDefaults] boolForKey:kOMColorHelperHighlightingDisabled];
		if (disabled) return;
		
		NSArray *selectedRanges = [self.textView selectedRanges];
		if (selectedRanges.count >= 1) {
			NSRange selectedRange = [selectedRanges[0] rangeValue];
			NSString *text = self.textView.textStorage.string;
			NSRange lineRange = [text lineRangeForRange:selectedRange];
			NSRange selectedRangeInLine = NSMakeRange(selectedRange.location - lineRange.location, selectedRange.length);
			NSString *line = [text substringWithRange:lineRange];
			
			NSRange colorRange = NSMakeRange(NSNotFound, 0);
			OMColorType colorType = OMColorTypeNone;
			NSColor *matchedColor = [self colorInText:line selectedRange:selectedRangeInLine type:&colorType matchedRange:&colorRange];
			
			if (matchedColor) {
				NSColor *backgroundColor = [self.textView.backgroundColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
				CGFloat r = 1.0; CGFloat g = 1.0; CGFloat b = 1.0;
				[backgroundColor getRed:&r green:&g blue:&b alpha:NULL];
				CGFloat backgroundLuminance = (r + g + b) / 3.0;
								
				NSColor *strokeColor = (backgroundLuminance > 0.5) ? [NSColor colorWithCalibratedWhite:0.2 alpha:1.0] : [NSColor whiteColor];
				
				self.selectedColorType = colorType;
				self.colorWell.color = matchedColor;
				self.colorWell.strokeColor = strokeColor;
				
				self.selectedColorRange = NSMakeRange(colorRange.location + lineRange.location, colorRange.length);
				NSRect selectionRectOnScreen = [self.textView firstRectForCharacterRange:self.selectedColorRange];
				NSRect selectionRectInWindow = [self.textView.window convertRectFromScreen:selectionRectOnScreen];
				NSRect selectionRectInView = [self.textView convertRect:selectionRectInWindow fromView:nil];
				NSRect colorWellRect = NSMakeRect(NSMaxX(selectionRectInView) - 49, NSMinY(selectionRectInView) - selectionRectInView.size.height - 2, 50, selectionRectInView.size.height + 2);
				self.colorWell.frame = NSIntegralRect(colorWellRect);
				[self.textView addSubview:self.colorWell];
				self.colorFrameView.frame = NSInsetRect(NSIntegralRect(selectionRectInView), -1, -1);
				
				self.colorFrameView.color = strokeColor;
				
				[self.textView addSubview:self.colorFrameView];
			} else {
				[self dismissColorWell];
			}
		} else {
			[self dismissColorWell];
		}
	}
}

- (void)dismissColorWell
{
	if (self.colorWell.isActive) {
		[self.colorWell deactivate];
		[[NSColorPanel sharedColorPanel] orderOut:nil];
	}
	[self.colorWell removeFromSuperview];
	[self.colorFrameView removeFromSuperview];
	self.selectedColorRange = NSMakeRange(NSNotFound, 0);
	self.selectedColorType = OMColorTypeNone;
}

- (void)colorDidChange:(id)sender
{
	if (self.selectedColorRange.location == NSNotFound) {
		return;
	}
	NSString *colorString = [self colorStringForColor:self.colorWell.color withType:self.selectedColorType];
	if (colorString) {
		[self.textView.undoManager beginUndoGrouping];
		[self.textView insertText:colorString replacementRange:self.selectedColorRange];
		[self.textView.undoManager endUndoGrouping];
	}
}

#pragma mark - View Initialization

- (OMPlainColorWell *)colorWell
{
	if (!_colorWell) {
		_colorWell = [[OMPlainColorWell alloc] initWithFrame:NSMakeRect(0, 0, 50, 30)];
		[_colorWell setTarget:self];
		[_colorWell setAction:@selector(colorDidChange:)];
	}
	return _colorWell;
}

- (OMColorFrameView *)colorFrameView
{
	if (!_colorFrameView) {
		_colorFrameView = [[OMColorFrameView alloc] initWithFrame:NSZeroRect];
	}
	return _colorFrameView;
}

#pragma mark - Color String Parsing

- (float)valueFromString:(NSString *)string matchingRegex:(NSRegularExpression *)regex {
    NSRange rangeOfValueString = [[regex matchesInString:string options:NSMatchingReportCompletion range:NSMakeRange(0, string.length)].firstObject range];
    NSString *valueString = [string substringWithRange:rangeOfValueString];
    valueString = [valueString substringFromIndex:[valueString rangeOfString:@":"].location + 1];
    valueString = [valueString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    valueString = [valueString stringByReplacingOccurrencesOfString:@"f" withString:@""];
    
    if ([valueString rangeOfString:@"/"].location != NSNotFound) {
        NSString *numerator = [valueString substringToIndex:[valueString rangeOfString:@"/"].location];
        NSString *denominator = [valueString substringFromIndex:[valueString rangeOfString:@"/"].location + 1];
        return numerator.floatValue/denominator.floatValue;
    } else {
        return valueString.floatValue;
    }
}

- (NSColor *)colorInText:(NSString *)text selectedRange:(NSRange)selectedRange type:(OMColorType *)type matchedRange:(NSRangePointer)matchedRange
{
	__block NSColor *foundColor = nil;
	__block NSRange foundColorRange = NSMakeRange(NSNotFound, 0);
	__block OMColorType foundColorType = OMColorTypeNone;
	
	[_rgbaUIColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
		NSRange colorRange = [result range];
		if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
        
            if ([text rangeOfString:@"["].location == NSNotFound) {
                foundColorType = OMColorTypeSwiftUIRGBAInit;
                //  UIColor(red:0.600, green:0.460, blue:0.656, alpha:0.540)
                NSString *numberPattern = @"\\s*:\\s*([0-9]+\\.?[0-9]*f?)(\\/[0-9]*\\.?[0-9]+f?)?";
                NSRegularExpression *redRegex = [NSRegularExpression regularExpressionWithPattern:[@"red" stringByAppendingString:numberPattern] options:0 error:nil];
                float red = [self valueFromString:text matchingRegex:redRegex];
                
                NSRegularExpression *greenRegex = [NSRegularExpression regularExpressionWithPattern:[@"green" stringByAppendingString:numberPattern] options:0 error:nil];
                float green = [self valueFromString:text matchingRegex:greenRegex];
                
                NSRegularExpression *blueRegex = [NSRegularExpression regularExpressionWithPattern:[@"blue" stringByAppendingString:numberPattern] options:0 error:nil];
                float blue = [self valueFromString:text matchingRegex:blueRegex];
                
                NSRegularExpression *alphaRegex = [NSRegularExpression regularExpressionWithPattern:[@"alpha" stringByAppendingString:numberPattern] options:0 error:nil];
                float alpha = [self valueFromString:text matchingRegex:alphaRegex];
                
                foundColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
                foundColorRange = colorRange;
                *stop = YES;
                return;
            } else if ([text rangeOfString:@"initWithRed"].location != NSNotFound) {
				foundColorType = OMColorTypeUIRGBAInit;
			} else {
				foundColorType = OMColorTypeUIRGBA;
			}
			
			// [UIColor colorWithRed:0.211 green:0.039 blue:0.482 alpha:0.500]
			double red = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
			red = [self dividedValue:red withDivisorRange:[result rangeAtIndex:3] inString:text];
			
			double green = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
			green = [self dividedValue:green withDivisorRange:[result rangeAtIndex:5] inString:text];
			
			double blue = [[text substringWithRange:[result rangeAtIndex:6]] doubleValue];
			blue = [self dividedValue:blue withDivisorRange:[result rangeAtIndex:7] inString:text];
			
			double alpha = [[text substringWithRange:[result rangeAtIndex:8]] doubleValue];
			alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:9] inString:text];
			
			foundColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
			foundColorRange = colorRange;
			*stop = YES;
		}
	}];
	
	if (!foundColor) {
		[_whiteUIColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *typeIndicator = [text substringWithRange:[result rangeAtIndex:1]];
				if ([typeIndicator rangeOfString:@"init"].location != NSNotFound) {
					foundColorType = OMColorTypeUIWhiteInit;
				} else {
					foundColorType = OMColorTypeUIWhite;
				}
				double white = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
				white = [self dividedValue:white withDivisorRange:[result rangeAtIndex:3] inString:text];
				
				double alpha = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
				alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:5] inString:text];
				
				foundColor = [NSColor colorWithCalibratedWhite:white alpha:alpha];
				foundColorRange = colorRange;
				*stop = YES;
			}
		}];
	}
	
	if (!foundColor) {
		[_constantColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *NS_UI = [text substringWithRange:[result rangeAtIndex:1]];
				NSString *colorName = [text substringWithRange:[result rangeAtIndex:2]];
				foundColor = _constantColorsByName[colorName];
				foundColorRange = colorRange;
				if ([NS_UI isEqualToString:@"UI"]) {
					foundColorType = OMColorTypeUIConstant;
				} else {
					foundColorType = OMColorTypeNSConstant;
				}
				*stop = YES;
			}
		}];
	}
    
//    TODO fix
    if (!foundColor) {
        [_customColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange colorRange = [result range];
            if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
                NSString *NS_UI = [text substringWithRange:[result rangeAtIndex:1]];
                NSString *colorName = [text substringWithRange:[result rangeAtIndex:2]];
                foundColor = _customColorsByName[colorName];
                foundColorRange = colorRange;
                if ([NS_UI isEqualToString:@"UI"]) {
                    foundColorType = OMColorTypeUICustom;
                } else {
                    foundColorType = OMColorTypeUICustom;
                }
                *stop = YES;
            }
        }];
    }
	
	if (!foundColor) {
		[_rgbaNSColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *deviceOrCalibrated = [text substringWithRange:[result rangeAtIndex:1]];
				if ([deviceOrCalibrated isEqualToString:@"Device"]) {
					foundColorType = OMColorTypeNSRGBADevice;
				} else {
					foundColorType = OMColorTypeNSRGBACalibrated;
				}
				double red = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
				red = [self dividedValue:red withDivisorRange:[result rangeAtIndex:3] inString:text];
				
				double green = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
				green = [self dividedValue:green withDivisorRange:[result rangeAtIndex:5] inString:text];
				
				double blue = [[text substringWithRange:[result rangeAtIndex:6]] doubleValue];
				blue = [self dividedValue:blue withDivisorRange:[result rangeAtIndex:7] inString:text];
				
				double alpha = [[text substringWithRange:[result rangeAtIndex:8]] doubleValue];
				alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:9] inString:text];
				
				if (foundColorType == OMColorTypeNSRGBACalibrated) {
					foundColor = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
				} else {
					foundColor = [NSColor colorWithDeviceRed:red green:green blue:blue alpha:alpha];
				}
				foundColorRange = colorRange;
				*stop = YES;
			}
		}];
	}
	
	if (!foundColor) {
		[_whiteNSColorRegex enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
			NSRange colorRange = [result range];
			if (selectedRange.location >= colorRange.location && NSMaxRange(selectedRange) <= NSMaxRange(colorRange)) {
				NSString *deviceOrCalibrated = [text substringWithRange:[result rangeAtIndex:1]];
				double white = [[text substringWithRange:[result rangeAtIndex:2]] doubleValue];
				white = [self dividedValue:white withDivisorRange:[result rangeAtIndex:3] inString:text];
				
				double alpha = [[text substringWithRange:[result rangeAtIndex:4]] doubleValue];
				alpha = [self dividedValue:alpha withDivisorRange:[result rangeAtIndex:5] inString:text];
				
				if ([deviceOrCalibrated isEqualToString:@"Device"]) {
					foundColor = [NSColor colorWithDeviceWhite:white alpha:alpha];
					foundColorType = OMColorTypeNSWhiteDevice;
				} else {
					foundColor = [NSColor colorWithCalibratedWhite:white alpha:alpha];
					foundColorType = OMColorTypeNSWhiteCalibrated;
				}
				foundColorRange = colorRange;
				*stop = YES;
			}
		}];
	}
	
	if (foundColor) {
		if (matchedRange != NULL) {
			*matchedRange = foundColorRange;
		}
		if (type != NULL) {
			*type = foundColorType;
		}
		return foundColor;
	}
	
	return nil;
}

- (double)dividedValue:(double)value withDivisorRange:(NSRange)divisorRange inString:(NSString *)text
{
	if (divisorRange.location != NSNotFound) {
		double divisor = [[[text substringWithRange:divisorRange] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/ "]] doubleValue];
		if (divisor != 0) {
			value /= divisor;
		}
	}
	return value;
}

- (NSString *)colorStringForColor:(NSColor *)color withType:(OMColorType)colorType
{
	NSString *colorString = nil;
	CGFloat red = -1.0; CGFloat green = -1.0; CGFloat blue = -1.0; CGFloat alpha = -1.0;
	color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
	[color getRed:&red green:&green blue:&blue alpha:&alpha];
		
	if (red >= 0) {
		for (NSString *colorName in _constantColorsByName) {
			NSColor *constantColor = _constantColorsByName[colorName];
			if ([constantColor isEqual:color]) {
				if (OMColorTypeIsNSColor(colorType)) {
					colorString = [NSString stringWithFormat:@"[NSColor %@Color]", colorName];
				} else {
					colorString = [NSString stringWithFormat:@"[UIColor %@Color]", colorName];
				}
				break;
			}
		}
        for (NSString *colorName in _customColorsByName) {
            NSColor *constantColor = _customColorsByName[colorName];
            if ([constantColor isEqual:color]) {
                if (OMColorTypeIsNSColor(colorType)) {
                    colorString = [NSString stringWithFormat:@"[NSColor %@Color]", colorName];
                } else {
                    colorString = [NSString stringWithFormat:@"[UIColor %@Color]", colorName];
                }
                break;
            }
        }
		if (!colorString) {
			if (fabs(red - green) < 0.001 && fabs(green - blue) < 0.001) {
                if (colorType == OMColorTypeUIRGBA || colorType == OMColorTypeUIWhite || colorType == OMColorTypeUIConstant) {
					colorString = [NSString stringWithFormat:@"[UIColor colorWithWhite:%.3f alpha:%.3f]", red, alpha];
				} else if (colorType == OMColorTypeUIRGBAInit || colorType == OMColorTypeUIWhiteInit) {
					colorString = [NSString stringWithFormat:@"[[UIColor alloc] initWithWhite:%.3f alpha:%.3f]", red, alpha];
				} else if (colorType == OMColorTypeNSConstant || colorType == OMColorTypeNSRGBACalibrated || colorType == OMColorTypeNSWhiteCalibrated) {
					colorString = [NSString stringWithFormat:@"[NSColor colorWithCalibratedWhite:%.3f alpha:%.3f]", red, alpha];
				} else if (colorType == OMColorTypeNSRGBADevice || colorType == OMColorTypeNSWhiteDevice) {
					colorString = [NSString stringWithFormat:@"[NSColor colorWithDeviceWhite:%.3f alpha:%.3f]", red, alpha];
				}
			} else {
                if (colorType == OMColorTypeSwiftUIRGBAInit) {
                    colorString = [NSString stringWithFormat:@"UIColor(red: %.3f, green: %.3f, blue: %.3f, alpha: %.3f)", red, green, blue, alpha];
                } else if (colorType == OMColorTypeUIRGBA || colorType == OMColorTypeUIWhite || colorType == OMColorTypeUIConstant) {
					colorString = [NSString stringWithFormat:@"[UIColor colorWithRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
				} else if (colorType == OMColorTypeUIRGBAInit || colorType == OMColorTypeUIWhiteInit) {
					colorString = [NSString stringWithFormat:@"[[UIColor alloc] initWithRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
				} else if (colorType == OMColorTypeNSConstant || colorType == OMColorTypeNSRGBACalibrated || colorType == OMColorTypeNSWhiteCalibrated) {
					colorString = [NSString stringWithFormat:@"[NSColor colorWithCalibratedRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
				} else if (colorType == OMColorTypeNSRGBADevice || colorType == OMColorTypeNSWhiteDevice) {
					colorString = [NSString stringWithFormat:@"[NSColor colorWithDeviceRed:%.3f green:%.3f blue:%.3f alpha:%.3f]", red, green, blue, alpha];
				}
			}
		}
	}
	return colorString;
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
