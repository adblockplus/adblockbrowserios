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

#import "UIImage+Transform.h"

@implementation UIImage (Transform)

- (UIImage *)imageScaledToWidth:(CGFloat)width height:(CGFloat)height
{
    CGRect newRect = CGRectMake(0, 0, width, height);
    if ((height > 0) && (width == 0.0)) {
        CGFloat ratio = height / self.size.height;
        newRect.size.width = self.size.width * ratio;
    } else if ((height == 0.0) && (width > 0)) {
        CGFloat ratio = width / self.size.width;
        newRect.size.height = self.size.height * ratio;
    }
    UIGraphicsBeginImageContextWithOptions(newRect.size, NO, 0.0);
    [self drawInRect:newRect];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

- (UIImage *)downscaledToHeight:(CGFloat)height
{
    UIImage *ret = self;
    if (ret.size.height > height) {
        CGFloat ratio = height / ret.size.height;
        CGSize newSize = CGSizeMake(ret.size.width * ratio, height);
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
        [ret drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
        ret = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return ret;
}

- (UIImage *)imageCroppedToSize:(CGSize)size
{
    CGRect newRect = CGRectMake(0, 0,
        size.width * self.scale,
        size.height * self.scale);

    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], newRect);
    UIImage *result = [UIImage imageWithCGImage:imageRef
                                          scale:self.scale
                                    orientation:self.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

@end
