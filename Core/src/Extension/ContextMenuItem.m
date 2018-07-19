/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "ContextMenuItem.h"
#import "Utils.h"
#import "ObjCLogger.h"

#import <KittCore/KittCore-Swift.h>

#define KEY_TARGET_URLS @"targetUrlPatterns"
#define KEY_DOCUMENT_URLS @"documentUrlPatterns"
#define KEY_ENABLED @"enabled"
#define KEY_CONTEXTS @"contexts"
#define KEY_TITLE @"title"

static NSDictionary *menuContextTypeMapping;

@interface ContextMenuItem () {
    NSArray *contexts;
}

@property (nonatomic, strong) NSMutableDictionary *properties;

@end

@implementation ContextMenuItem

@synthesize grayscaleIcon = _grayscaleIcon;

+ (void)initialize
{
    menuContextTypeMapping = @{
        @"all" : @(MenuContext_All),
        @"page" : @(MenuContext_WholeWebPage),
        @"selection" : @(MenuContext_TextSelection),
        @"link" : @(MenuContext_LinkLongTap)
    };
}

- (id)initWithMenuId:(NSString *)menuId originExtension:(BrowserExtension *)originExtension
{
    self = [super init];
    if (self) {
        _buttonIndex = NSNotFound;
        _menuId = menuId;
        contexts = @[ @(MenuContext_WholeWebPage) ];
        // default when chrome.contextMenus.create doesn't define any context
        _originExtension = originExtension;
    }
    return self;
}

- (void)setInitialProperties:(NSDictionary *)properties error:(NSError *__autoreleasing *)error
{
    // deep mutable copy
    _properties = [NSMutableDictionary dictionaryWithDictionary:properties];
    [self exchangeStringsForRegexesInPropertyForKey:KEY_TARGET_URLS error:error];
    if (!*error) {
        [self exchangeStringsForRegexesInPropertyForKey:KEY_DOCUMENT_URLS error:error];
    }
    NSArray *contextsRaw = properties[KEY_CONTEXTS];
    if (contextsRaw && ([contextsRaw count] > 0)) {
        NSMutableArray *contextsMutable = [NSMutableArray arrayWithCapacity:[contextsRaw count]];
        for (NSString *contextStr in contextsRaw) {
            NSNumber *contextNr = menuContextTypeMapping[contextStr];
            if (contextNr) {
                [contextsMutable addObject:contextNr];
            } else {
                LogError(@"contextMenus unsupported context '%@'", contextStr);
            }
        }
        contexts = [NSArray arrayWithArray:contextsMutable];
    }
}

- (void)mergeWithProperties:(NSDictionary *)properties error:(NSError *__autoreleasing *)error
{
    // the properties dictionary must be kept mutable, so make a mutable copy
    // of the incoming dictionary and the merge its values with the existing dictionary
    NSMutableDictionary *mergeDict = [NSMutableDictionary dictionaryWithDictionary:properties];
    // update properties may be just partial, simply reassigning it to the value
    // would destroy the existing ones. Must copy the update over the existing values
    for (NSString *updateKey in mergeDict) {
        [_properties setObject:[mergeDict objectForKey:updateKey] forKey:updateKey];
        if ([updateKey isEqualToString:KEY_TARGET_URLS]) {
            [self exchangeStringsForRegexesInPropertyForKey:KEY_TARGET_URLS error:error];
        } else if ([updateKey isEqualToString:KEY_DOCUMENT_URLS]) {
            [self exchangeStringsForRegexesInPropertyForKey:KEY_DOCUMENT_URLS error:error];
        }
        if (*error) {
            break;
        }
    }
}

- (NSArray *)arrayOfRegexesForDocumentURL
{
    return [_properties objectForKey:KEY_DOCUMENT_URLS];
}
- (NSArray *)arrayOfRegexesForTargetURL
{
    return [_properties objectForKey:KEY_TARGET_URLS];
}

- (BOOL)isEnabled
{
    NSNumber *value = [_properties objectForKey:KEY_ENABLED];
    return value ? [value boolValue] : NO;
}

- (BOOL)isApplicableToContext:(MenuContextType)contextType
{
    // According to chrome spec, specific context "launcher" does not fall under "all"
    // but we don't support "launcher" at all, so the condition is fine
    return [contexts containsObject:@(contextType)] || [contexts containsObject:@(MenuContext_All)];
}

- (NSString *)title
{
    return [_properties objectForKey:KEY_TITLE];
}

- (void)exchangeStringsForRegexesInPropertyForKey:(NSString *)key
                                            error:(NSError *__autoreleasing *)error
{
    NSMutableArray *strings = [_properties objectForKey:key];
    if (!strings) {
        strings = [NSMutableArray new];
    }
    NSArray *regexes = (strings && [strings count]) ? [Utils arrayOfRegexesFromArrayOfChromeGlobStrings:strings error:error]
                                                    : [NSArray new];
    // set regardless of error, so that properties hold instances of
    // NSRegularExpression instead of NSString
    [_properties setObject:regexes forKey:key];
}

- (UIImage *)grayscaleIcon
{
    // According to documentation, icon in UIActivity can't be colored.
    // Alpha channel is used for color, so we need to create grayscaled image stored
    // in alpha channel.
    // Icon is loaded only one time.
    NSError *error;

    if (_grayscaleIcon == nil) {

        // Preferred height of icon on different devices
        CGFloat height = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? BrowserExtension.iphoneShareIconHeight : BrowserExtension.ipadShareIconHeight;

        UIImage *pngImage = [self.originExtension imageForContext:ManifestContextIconWholeExtension
                                                       withHeight:height
                                                            error:&error];
        if (error) {
            goto END;
        }

        CGFloat scale = [[UIScreen mainScreen] scale];
        CGRect imageRect = CGRectMake(0, 0, height * scale, height * scale);

        //Pixel Buffer
        uint32_t *piPixels = (uint32_t *)malloc(imageRect.size.width * imageRect.size.height * sizeof(uint32_t));
        if (piPixels == NULL) {
            error = [NSError errorWithDomain:@"Kitt" code:0 userInfo:@{ NSLocalizedDescriptionKey : @"Requested memory cannot be allocated." }];
            goto END;
        }

        memset(piPixels, 0, imageRect.size.width * imageRect.size.height * sizeof(uint32_t));

        //Drawing image in the buffer
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(piPixels, imageRect.size.width, imageRect.size.height, 8, sizeof(uint32_t) * imageRect.size.width, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);

        CGContextDrawImage(context, imageRect, pngImage.CGImage);

        //Copying the alpha values to the red values of the image and setting the alpha to 1
        for (uint32_t y = 0; y < imageRect.size.height; y++) {
            for (uint32_t x = 0; x < imageRect.size.width; x++) {
                uint8_t *rgbaValues = (uint8_t *)&piPixels[y * (uint32_t)imageRect.size.width + x];

                //alpha = 0, red = 1, green = 2, blue = 3.

                // Compute averange color
                uint32_t sum = (rgbaValues[1] + rgbaValues[2] + rgbaValues[3]) / 3;
                // Invert color
                sum = (255 - sum);
                // Mask by alpha
                sum = (sum * rgbaValues[0]) / 255;
                rgbaValues[0] = sum;
            }
        }

        //Creating image whose red values will preserve the alpha values
        CGImageRef newCGImage = CGBitmapContextCreateImage(context);
        _grayscaleIcon = [[UIImage alloc] initWithCGImage:newCGImage scale:scale orientation:UIImageOrientationUp];
        CGImageRelease(newCGImage);

        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        free(piPixels);
    }
END:

    // Handle error
    if (error) {
        UIAlertView *alert = [Utils alertViewWithError:error
                                                 title:@"Extension icon"
                                              delegate:nil];
        [alert show];

        // Do not try to load image from manifest next time.
        _grayscaleIcon = [UIImage new];
        return _grayscaleIcon;
    }

    return _grayscaleIcon;
}

- (NSString *)activityType
{
    return [NSString stringWithFormat:@"(Kitt,%@,%@)", self.originExtension.extensionId, self.menuId];
}

@end
