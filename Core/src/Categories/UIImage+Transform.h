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

#import <UIKit/UIKit.h>

@interface UIImage (Transform)

/// If one dimension is zero, will scale proportionally by the other dimension
/// If both dimensions are non zero, proportions are not assured
/// @return copy of self, scaled to new height and/or width
- (UIImage *)imageScaledToWidth:(CGFloat)width height:(CGFloat)height;

/// @return copy of self, cropped to size
- (UIImage *)imageCroppedToSize:(CGSize)size;

- (UIImage *)downscaledToHeight:(CGFloat)height;

@end
