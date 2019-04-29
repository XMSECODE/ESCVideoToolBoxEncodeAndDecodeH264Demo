//
//  ESCVideoToolboxYUVToH264DecoderTool.h
//  ESCVideoToolBoxEncodeAndDecodeH264Demo
//
//  Created by xiang on 2019/4/29.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ESCVideoToolboxYUVToH264DecoderTool;

@protocol ESCVideoToolboxYUVToH264DecoderToolDelegate <NSObject>

- (void)decoder:(ESCVideoToolboxYUVToH264DecoderTool *)decoder ydata:(NSData *)ydata udata:(NSData *)udata vdata:(NSData *)vdata;

- (void)endDecoder;

@end

@interface ESCVideoToolboxYUVToH264DecoderTool : NSObject

@property (nonatomic, weak) id<ESCVideoToolboxYUVToH264DecoderToolDelegate> delegate;

- (instancetype)initWithDelegate:(id)delegate width:(int)width height:(int)height;

- (void)decodeFrameToYUV:(NSData *)H264Data;

- (void)endH264Data;

- (void)destroy;

@end

NS_ASSUME_NONNULL_END
