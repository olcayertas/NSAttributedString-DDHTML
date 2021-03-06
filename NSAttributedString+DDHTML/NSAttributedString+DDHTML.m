//
//  NSAttributedString+HTML.m
//
//  Created by Derek Bowen <dbowen@demiurgic.co>
//  Copyright (c) 2012-2015, Deloitte Digital
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//  * Neither the name of the <organization> nor the
//    names of its contributors may be used to endorse or promote products
//    derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "NSAttributedString+DDHTML.h"
#include <libxml/HTMLparser.h>

@implementation NSAttributedString (DDHTML)

+ (NSAttributedString *)attributedStringFromHTML:(NSString *)htmlString {
    UIFont *preferredBodyFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];

    return [self attributedStringFromHTML:htmlString
                               normalFont:preferredBodyFont
                                 boldFont:[UIFont boldSystemFontOfSize:preferredBodyFont.pointSize]
                               italicFont:[UIFont italicSystemFontOfSize:preferredBodyFont.pointSize]];
}

+ (NSAttributedString *)attributedStringFromHTML:(NSString *)htmlString boldFont:(UIFont *)boldFont italicFont:(UIFont *)italicFont {
    return [self attributedStringFromHTML:htmlString
                               normalFont:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                 boldFont:boldFont
                               italicFont:italicFont];
}

+ (NSAttributedString *)attributedStringFromHTML:(NSString *)htmlString
                                      normalFont:(UIFont *)normalFont
                                        boldFont:(UIFont *)boldFont
                                      italicFont:(UIFont *)italicFont {

    return [self attributedStringFromHTML:htmlString
                               normalFont:normalFont
                                 boldFont:boldFont
                               italicFont:italicFont
                                 imageMap:@{}];
}

+ (NSAttributedString *)attributedStringFromHTML:(NSString *)htmlString
                                      normalFont:(UIFont *)normalFont
                                        boldFont:(UIFont *)boldFont
                                      italicFont:(UIFont *)italicFont
                                        imageMap:(NSDictionary<NSString *, UIImage *> *)imageMap {

    // Parse HTML string as XML document using UTF-8 encoding
    NSData *documentData = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
    xmlDoc *document = htmlReadMemory(documentData.bytes, (int) documentData.length, nil, "UTF-8", HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR);

    if (document == NULL) {
        return [[NSAttributedString alloc] initWithString:htmlString attributes:nil];
    }

    NSMutableAttributedString *finalAttributedString = [NSMutableAttributedString new];

    xmlNodePtr currentNode = document->children;

    while (currentNode != NULL) {

        NSAttributedString *childString =
                [self attributedStringFromNode:currentNode
                                    normalFont:normalFont
                                      boldFont:boldFont
                                    italicFont:italicFont
                                      imageMap:imageMap];
        [finalAttributedString appendAttributedString:childString];

        currentNode = currentNode->next;
    }

    xmlFreeDoc(document);

    return finalAttributedString;
}

+ (NSAttributedString *)attributedStringFromNode:(xmlNodePtr)xmlNode
                                      normalFont:(UIFont *)normalFont
                                        boldFont:(UIFont *)boldFont
                                      italicFont:(UIFont *)italicFont
                                        imageMap:(NSDictionary<NSString *, UIImage *> *)imageMap {

    NSMutableAttributedString *nodeAttributedString = [NSMutableAttributedString new];

    if ((xmlNode->type != XML_ENTITY_REF_NODE) && ((xmlNode->type != XML_ELEMENT_NODE) && xmlNode->content != NULL)) {

        NSAttributedString *normalAttributedString =
                [[NSAttributedString alloc]
                        initWithString:[NSString stringWithCString:(const char *) xmlNode->content encoding:NSUTF8StringEncoding]
                            attributes:@{NSFontAttributeName: normalFont}];

        [nodeAttributedString appendAttributedString:normalAttributedString];
    }

    // Handle children
    xmlNodePtr currentNode = xmlNode->children;

    while (currentNode != NULL) {

        NSAttributedString *childString =
                [self attributedStringFromNode:currentNode
                                    normalFont:normalFont
                                      boldFont:boldFont
                                    italicFont:italicFont
                                      imageMap:imageMap];

        [nodeAttributedString appendAttributedString:childString];
        currentNode = currentNode->next;
    }

    if (xmlNode->type == XML_ELEMENT_NODE) {

        NSRange nodeAttributedStringRange = NSMakeRange(0, nodeAttributedString.length);

        // Build dictionary to store attributes
        NSMutableDictionary *attributeDictionary = [NSMutableDictionary dictionary];

        if (xmlNode->properties != NULL) {
            xmlAttrPtr attribute = xmlNode->properties;

            while (attribute != NULL) {

                NSString *attributeValue = @"";

                if (attribute->children != NULL) {
                    attributeValue = [NSString stringWithCString:(const char *) attribute->children->content
                                                        encoding:NSUTF8StringEncoding];
                }

                NSString *attributeName = [[NSString stringWithCString:(const char *) attribute->name
                                                              encoding:NSUTF8StringEncoding] lowercaseString];

                attributeDictionary[attributeName] = attributeValue;
                attribute = attribute->next;
            }
        }

        const char *nodeName = (const char *) xmlNode->name;
        size_t nodeNameLength = strlen(nodeName);

        // Bold Tag
        if (strncmp("b", nodeName, nodeNameLength) == 0 || strncmp("strong", nodeName, nodeNameLength) == 0) {

            if (boldFont) {
                [nodeAttributedString addAttribute:NSFontAttributeName value:boldFont range:nodeAttributedStringRange];
            }
        }

            // Italic Tag
        else if (strncmp("i", nodeName, nodeNameLength) == 0 || strncmp("em", nodeName, nodeNameLength) == 0) {

            if (italicFont) {
                [nodeAttributedString addAttribute:NSFontAttributeName value:italicFont range:nodeAttributedStringRange];
            }
        }

            // Underline Tag
        else if (strncmp("u", nodeName, nodeNameLength) == 0) {
            [nodeAttributedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:nodeAttributedStringRange];
        }

            // Stike Tag
        else if (strncmp("strike", nodeName, nodeNameLength) == 0) {
            [nodeAttributedString addAttribute:NSStrikethroughStyleAttributeName value:@(YES) range:nodeAttributedStringRange];
        }

            // Stoke Tag
        else if (strncmp("stroke", nodeName, nodeNameLength) == 0) {
            UIColor *strokeColor = [UIColor purpleColor];
            NSNumber *strokeWidth = @(1.0);

            if (attributeDictionary[@"color"]) {
                strokeColor = [self colorFromHexString:attributeDictionary[@"color"]];
            }
            if (attributeDictionary[@"width"]) {
                strokeWidth = @(fabs([attributeDictionary[@"width"] doubleValue]));
            }
            if (!attributeDictionary[@"nofill"]) {
                strokeWidth = @(-fabs([strokeWidth doubleValue]));
            }

            [nodeAttributedString addAttribute:NSStrokeColorAttributeName value:strokeColor range:nodeAttributedStringRange];
            [nodeAttributedString addAttribute:NSStrokeWidthAttributeName value:strokeWidth range:nodeAttributedStringRange];
        }

            // Shadow Tag
        else if (strncmp("shadow", nodeName, nodeNameLength) == 0) {

#if __has_include(<UIKit/NSShadow.h>)
            NSShadow *shadow = [[NSShadow alloc] init];
            shadow.shadowOffset = CGSizeMake(0, 0);
            shadow.shadowBlurRadius = 2.0;
            shadow.shadowColor = [UIColor blackColor];

            if (attributeDictionary[@"offset"]) {
                shadow.shadowOffset = CGSizeFromString(attributeDictionary[@"offset"]);
            }

            if (attributeDictionary[@"blurradius"]) {
                shadow.shadowBlurRadius = [attributeDictionary[@"blurradius"] floatValue];
            }

            if (attributeDictionary[@"color"]) {
                shadow.shadowColor = [self colorFromHexString:attributeDictionary[@"color"]];
            }

            [nodeAttributedString addAttribute:NSShadowAttributeName value:shadow range:nodeAttributedStringRange];
#endif

        }

            // Font Tag
        else if (strncmp("font", nodeName, nodeNameLength) == 0) {
            NSString *fontName = nil;
            NSNumber *fontSize = nil;
            UIColor *foregroundColor = nil;
            UIColor *backgroundColor = nil;

            if (attributeDictionary[@"face"]) {
                fontName = attributeDictionary[@"face"];
            }
            if (attributeDictionary[@"size"]) {
                fontSize = @([attributeDictionary[@"size"] doubleValue]);
            }
            if (attributeDictionary[@"color"]) {
                foregroundColor = [self colorFromHexString:attributeDictionary[@"color"]];
            }
            if (attributeDictionary[@"backgroundcolor"]) {
                backgroundColor = [self colorFromHexString:attributeDictionary[@"backgroundcolor"]];
            }

            if (fontName == nil && fontSize != nil) {

                [nodeAttributedString addAttribute:NSFontAttributeName
                                             value:[UIFont systemFontOfSize:[fontSize floatValue]]
                                             range:nodeAttributedStringRange];

            } else if (fontName != nil && fontSize == nil) {

                [nodeAttributedString addAttribute:NSFontAttributeName
                                             value:[self fontOrSystemFontForName:fontName size:12.0]
                                             range:nodeAttributedStringRange];

            } else if (fontName != nil) {

                [nodeAttributedString addAttribute:NSFontAttributeName
                                             value:[self fontOrSystemFontForName:fontName size:fontSize.floatValue]
                                             range:nodeAttributedStringRange];

            }

            if (foregroundColor) {
                [nodeAttributedString addAttribute:NSForegroundColorAttributeName
                                             value:foregroundColor
                                             range:nodeAttributedStringRange];
            }

            if (backgroundColor) {
                [nodeAttributedString addAttribute:NSBackgroundColorAttributeName
                                             value:backgroundColor
                                             range:nodeAttributedStringRange];
            }
        }

            // Paragraph Tag
        else if (strncmp("p", nodeName, nodeNameLength) == 0) {

            NSMutableParagraphStyle *paragraphStyle = [NSParagraphStyle defaultParagraphStyle].mutableCopy;

            if (attributeDictionary[@"align"]) {
                NSString *alignString = [attributeDictionary[@"align"] lowercaseString];

                if ([alignString isEqualToString:@"left"]) {
                    paragraphStyle.alignment = NSTextAlignmentLeft;
                } else if ([alignString isEqualToString:@"center"]) {
                    paragraphStyle.alignment = NSTextAlignmentCenter;
                } else if ([alignString isEqualToString:@"right"]) {
                    paragraphStyle.alignment = NSTextAlignmentRight;
                } else if ([alignString isEqualToString:@"justify"]) {
                    paragraphStyle.alignment = NSTextAlignmentJustified;
                }
            }

            if (attributeDictionary[@"linebreakmode"]) {
                NSString *lineBreakModeString = [attributeDictionary[@"linebreakmode"] lowercaseString];

                if ([lineBreakModeString isEqualToString:@"wordwrapping"]) {
                    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
                } else if ([lineBreakModeString isEqualToString:@"charwrapping"]) {
                    paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
                } else if ([lineBreakModeString isEqualToString:@"clipping"]) {
                    paragraphStyle.lineBreakMode = NSLineBreakByClipping;
                } else if ([lineBreakModeString isEqualToString:@"truncatinghead"]) {
                    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingHead;
                } else if ([lineBreakModeString isEqualToString:@"truncatingtail"]) {
                    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
                } else if ([lineBreakModeString isEqualToString:@"truncatingmiddle"]) {
                    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
                }
            }

            if (attributeDictionary[@"firstlineheadindent"]) {
                paragraphStyle.firstLineHeadIndent = [attributeDictionary[@"firstlineheadindent"] floatValue];
            }

            if (attributeDictionary[@"headindent"]) {
                paragraphStyle.headIndent = [attributeDictionary[@"headindent"] floatValue];
            }

            if (attributeDictionary[@"hyphenationfactor"]) {
                paragraphStyle.hyphenationFactor = [attributeDictionary[@"hyphenationfactor"] floatValue];
            }

            if (attributeDictionary[@"lineheightmultiple"]) {
                paragraphStyle.lineHeightMultiple = [attributeDictionary[@"lineheightmultiple"] floatValue];
            }

            if (attributeDictionary[@"linespacing"]) {
                paragraphStyle.lineSpacing = [attributeDictionary[@"linespacing"] floatValue];
            }

            if (attributeDictionary[@"maximumlineheight"]) {
                paragraphStyle.maximumLineHeight = [attributeDictionary[@"maximumlineheight"] floatValue];
            }

            if (attributeDictionary[@"minimumlineheight"]) {
                paragraphStyle.minimumLineHeight = [attributeDictionary[@"minimumlineheight"] floatValue];
            }

            if (attributeDictionary[@"paragraphspacing"]) {
                paragraphStyle.paragraphSpacing = [attributeDictionary[@"paragraphspacing"] floatValue];
            }

            if (attributeDictionary[@"paragraphspacingbefore"]) {
                paragraphStyle.paragraphSpacingBefore = [attributeDictionary[@"paragraphspacingbefore"] floatValue];
            }

            if (attributeDictionary[@"tailindent"]) {
                paragraphStyle.tailIndent = [attributeDictionary[@"tailindent"] floatValue];
            }

            [nodeAttributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:nodeAttributedStringRange];

            // MR - For some reason they are not adding the paragraph space when parsing the <p> tag
            [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }


            // Links
        else if (strncmp("a href", nodeName, nodeNameLength) == 0) {

            xmlChar *value = xmlNodeListGetString(xmlNode->doc, xmlNode->xmlChildrenNode, 1);

            if (value) {
                NSString *title = [NSString stringWithCString:(const char *) value encoding:NSUTF8StringEncoding];
                NSString *link = attributeDictionary[@"href"];
                [nodeAttributedString addAttribute:NSLinkAttributeName value:link range:NSMakeRange(0, title.length)];
            }
        }

            // New Lines
        else if (strncmp("br", nodeName, nodeNameLength) == 0) {
            [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }

            // Unordered lists
        else if (strncmp("ul", nodeName, nodeNameLength) == 0) {

            NSString *listItemMarker = @"";

            if (attributeDictionary[@"style"]) {

                NSString *style = [attributeDictionary[@"style"] lowercaseString];
                style = [style stringByReplacingOccurrencesOfString:@" " withString:@""];

                if ([style isEqualToString:@"list-style-type:disc"]) {
                    listItemMarker = @"● ";
                } else if ([style isEqualToString:@"list-style-type:circle"]) {
                    listItemMarker = @"○ ";
                } else if ([style isEqualToString:@"list-style-type:square"]) {
                    listItemMarker = @"■ ";
                }
            }

            xmlNodePtr currentItem = xmlNode->children;

            while (currentItem) {
                [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:listItemMarker]];
                xmlChar *value = xmlNodeListGetString(currentItem->doc, currentItem->xmlChildrenNode, 1);
                NSString *listItemString = [NSString stringWithCString:(const char *)value encoding:NSUTF8StringEncoding];
                NSAttributedString *attributedListItemString = [[NSAttributedString alloc] initWithString:listItemString];
                [nodeAttributedString appendAttributedString:attributedListItemString];
                [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                currentItem = currentItem->next;
            }
        }

            // Ordered lists
        else if (strncmp("ol", nodeName, nodeNameLength) == 0) {

            NSString *listItemMarker = @"";

            if (attributeDictionary[@"style"]) {

                NSString *style = [attributeDictionary[@"style"] lowercaseString];
                style = [style stringByReplacingOccurrencesOfString:@" " withString:@""];

                if ([style isEqualToString:@"list-style-type:armenian"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:cjk-ideographic"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:decimal"]) {

                    xmlNodePtr currentItem = xmlNode->children;
                    NSUInteger itemNumber = 0;

                    while (currentItem) {
                        NSString *itemNumberString = [NSString stringWithFormat:@"%d. ", ++itemNumber];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:itemNumberString]];
                        xmlChar *value = xmlNodeListGetString(currentItem->doc, currentItem->xmlChildrenNode, 1);
                        NSString *listItemString = [NSString stringWithCString:(const char *)value encoding:NSUTF8StringEncoding];
                        NSAttributedString *attributedListItemString = [[NSAttributedString alloc] initWithString:listItemString];
                        [nodeAttributedString appendAttributedString:attributedListItemString];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                        currentItem = currentItem->next;
                    }
                }
                else if ([style isEqualToString:@"list-style-type:decimal-leading-zero"]) {

                    xmlNodePtr currentItem = xmlNode->children;
                    NSUInteger nodeCount = 0;

                    while (currentItem) {
                        ++nodeCount;
                        currentItem = currentItem->next;
                    }

                    NSUInteger digitCount = 1;

                    while (nodeCount % 10 != nodeCount) {
                        digitCount++;
                        nodeCount %= 10;
                    }

                    NSUInteger itemNumber = 0;
                    currentItem = xmlNode->children;

                    while (currentItem) {
                        NSString *format = [NSString stringWithFormat:@"%%0%d. ", digitCount];
                        NSString *itemNumberString = [NSString stringWithFormat:format, ++itemNumber];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:itemNumberString]];
                        xmlChar *value = xmlNodeListGetString(currentItem->doc, currentItem->xmlChildrenNode, 1);
                        NSString *listItemString = [NSString stringWithCString:(const char *)value encoding:NSUTF8StringEncoding];
                        NSAttributedString *attributedListItemString = [[NSAttributedString alloc] initWithString:listItemString];
                        [nodeAttributedString appendAttributedString:attributedListItemString];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                        currentItem = currentItem->next;
                    }
                }
                else if ([style isEqualToString:@"list-style-type:georgian"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:hebrew"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:hiragana"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:hiragana-iroha"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:katakana"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:katakana-iroha"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:lower-alpha"]) {

                    xmlNodePtr currentItem = xmlNode->children;
                    char item = 'a';

                    while (currentItem) {
                        NSString *itemMarkerString = [NSString stringWithFormat:@"%c. ", item];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:itemMarkerString]];
                        xmlChar *value = xmlNodeListGetString(currentItem->doc, currentItem->xmlChildrenNode, 1);
                        NSString *listItemString = [NSString stringWithCString:(const char *)value encoding:NSUTF8StringEncoding];
                        NSAttributedString *attributedListItemString = [[NSAttributedString alloc] initWithString:listItemString];
                        [nodeAttributedString appendAttributedString:attributedListItemString];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                        currentItem = currentItem->next;
                    }
                }
                else if ([style isEqualToString:@"list-style-type:lower-greek"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-lower-latin"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-lower-roman"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:upper-alpha"]) {

                    xmlNodePtr currentItem = xmlNode->children;
                    char item = 'A';

                    while (currentItem) {
                        NSString *itemMarkerString = [NSString stringWithFormat:@"%c. ", item];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:itemMarkerString]];
                        xmlChar *value = xmlNodeListGetString(currentItem->doc, currentItem->xmlChildrenNode, 1);
                        NSString *listItemString = [NSString stringWithCString:(const char *)value encoding:NSUTF8StringEncoding];
                        NSAttributedString *attributedListItemString = [[NSAttributedString alloc] initWithString:listItemString];
                        [nodeAttributedString appendAttributedString:attributedListItemString];
                        [nodeAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
                        currentItem = currentItem->next;
                    }
                }
                else if ([style isEqualToString:@"list-style-type:upper-greek"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:upper-latin"]) {
                    //TODO
                }
                else if ([style isEqualToString:@"list-style-type:upper-roman"]) {
                    //TODO
                }
            }
        }

            // Images
        else if (strncmp("img", nodeName, nodeNameLength) == 0) {
#if __has_include(<UIKit/NSTextAttachment.h>)
            NSString *src = attributeDictionary[@"src"];
            NSString *width = attributeDictionary[@"width"];
            NSString *height = attributeDictionary[@"height"];

            if (src != nil) {
                UIImage *image = imageMap[src];
                if (image == nil) {
                    image = [UIImage imageNamed:src];
                }

                if (image != nil) {
                    NSTextAttachment *imageAttachment = [[NSTextAttachment alloc] init];
                    imageAttachment.image = image;
                    if (width != nil && height != nil) {
                        imageAttachment.bounds = CGRectMake(0, 0, [width integerValue] / 2, [height integerValue] / 2);
                    }
                    NSAttributedString *imageAttributeString = [NSAttributedString attributedStringWithAttachment:imageAttachment];
                    [nodeAttributedString appendAttributedString:imageAttributeString];
                }
            }
#endif
        }
    }

    return nodeAttributedString;
}

+ (UIFont *)fontOrSystemFontForName:(NSString *)fontName size:(CGFloat)fontSize {
    UIFont *font = [UIFont fontWithName:fontName size:fontSize];
    if (font) {
        return font;
    }
    return [UIFont systemFontOfSize:fontSize];
}

+ (UIColor *)colorFromHexString:(NSString *)hexString {

    if (hexString == nil)
        return nil;

    hexString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    char *p;
    NSUInteger hexValue = strtoul([hexString cStringUsingEncoding:NSUTF8StringEncoding], &p, 16);

    return [UIColor colorWithRed:((hexValue & 0xff0000) >> 16) / 255.0f
                           green:((hexValue & 0xff00) >> 8) / 255.0f
                            blue:(hexValue & 0xff) / 255.0f
                           alpha:1.0];
}

@end
