//
//  ESCVideoToolboxYUVToH264DecoderTool.h
//  ESCVideoToolBoxEncodeAndDecodeH264Demo
//
//  Created by xiang on 2019/4/29.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ESCVideoToolboxH264ToYUVDecoderTool;

@protocol ESCVideoToolboxH264ToYUVDecoderToolDelegate <NSObject>

- (void)decoder:(ESCVideoToolboxH264ToYUVDecoderTool *)decoder ydata:(NSData *)ydata udata:(NSData *)udata vdata:(NSData *)vdata;

- (void)endDecoder;

@end

@interface ESCVideoToolboxH264ToYUVDecoderTool : NSObject

@property (nonatomic, weak) id<ESCVideoToolboxH264ToYUVDecoderToolDelegate> delegate;

- (instancetype)initWithDelegate:(id)delegate;

- (void)decodeFrameToYUV:(NSData *)H264Data;

- (void)endH264Data;

@end

NS_ASSUME_NONNULL_END
