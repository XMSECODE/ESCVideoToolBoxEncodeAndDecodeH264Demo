//
//  ESCYUVToH264FileTool.m
//  ESCVideoToolBoxEncodeAndDecodeH264Demo
//
//  Created by xiang on 2019/4/30.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "ESCH264ToYUVFileTool.h"
#import "ESCVideoToolboxYUVToH264DecoderTool.h"

@interface ESCH264ToYUVFileTool ()

@property(nonatomic,copy)void(^complete)(void);

@property(nonatomic,strong)ESCVideoToolboxYUVToH264DecoderTool* tool;

@property(nonatomic,strong)NSFileHandle* yuvHandle;

@end

@implementation ESCH264ToYUVFileTool

- (void)h264FileToYUVFileDecodeWithVideoYUVFilePath:(NSString *)yuvFilePath
                                       h264FilePath:(NSString *)h264FilePath
                                           complete:(void(^)(void))complete {
    
    self.complete = complete;
    
    NSData *h264Data = [NSData dataWithContentsOfFile:h264FilePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:yuvFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:yuvFilePath error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:yuvFilePath contents:nil attributes:nil];
    
    self.yuvHandle = [NSFileHandle fileHandleForWritingAtPath:yuvFilePath];
    
    ESCVideoToolboxYUVToH264DecoderTool *tool = [[ESCVideoToolboxYUVToH264DecoderTool alloc] initWithDelegate:self width:1280 height:720];
    self.tool = tool;
    @autoreleasepool {
        uint8_t *videoData = (uint8_t *)[h264Data bytes];
        int lastJ = 0;
        int lastType = 0;
        
        for (int i = 0; i < h264Data.length; i++) {
            //        printf("  %02x  ",videoData[i]);
            //读取头
            if (videoData[i] == 0x00 &&
                videoData[i + 1] == 0x00 &&
                videoData[i + 2] == 0x00 &&
                videoData[i + 3] == 0x01) {
                if (i >= 0) {
                    uint8_t NALU = videoData[i+4];
                    int type = NALU & 0x1f;
                    //                NSLog(@"%d===%d",type,NALU);
                    if (lastType == 5 || lastType == 1) {
                        int frame_size = i - lastJ;
                        NSData *data = [NSData dataWithBytes:&videoData[lastJ] length:frame_size];
                        [tool decodeFrameToYUV:data];
                        lastJ = i;
                    }
                    lastType = type;
                }
            }else if (i == h264Data.length - 1) {
                int frame_size = i - lastJ + 1;
                NSData *data = [NSData dataWithBytes:&videoData[lastJ] length:frame_size];
                [tool decodeFrameToYUV:data];
                lastJ = i;
            }
        }
    }
    [tool endH264Data];
}

#pragma mark - ESCVideoToolboxYUVToH264DecoderToolDelegate
- (void)decoder:(ESCVideoToolboxYUVToH264DecoderTool *)decoder ydata:(NSData *)ydata udata:(NSData *)udata vdata:(NSData *)vdata {
    NSMutableData *yuvData = [NSMutableData dataWithData:ydata];
    [yuvData appendData:udata];
    [yuvData appendData:vdata];
    if (self.yuvHandle) {
        [self.yuvHandle writeData:yuvData];
    }
}

- (void)endDecoder {
    [self.yuvHandle closeFile];
    if (self.complete) {
        self.complete();
        self.complete = nil;
    }
}

@end
