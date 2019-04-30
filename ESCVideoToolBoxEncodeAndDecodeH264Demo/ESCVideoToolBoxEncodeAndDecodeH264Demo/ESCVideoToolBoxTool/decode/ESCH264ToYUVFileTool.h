//
//  ESCYUVToH264FileTool.h
//  ESCVideoToolBoxEncodeAndDecodeH264Demo
//
//  Created by xiang on 2019/4/30.
//  Copyright © 2019 xiang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ESCH264ToYUVFileTool : NSObject

/**
 yuv文件转h264压缩文件
 */
- (void)h264FileToYUVFileDecodeWithVideoYUVFilePath:(NSString *)yuvFilePath
                                       h264FilePath:(NSString *)h264FilePath
                                           complete:(void(^)(void))complete;

@end

NS_ASSUME_NONNULL_END
