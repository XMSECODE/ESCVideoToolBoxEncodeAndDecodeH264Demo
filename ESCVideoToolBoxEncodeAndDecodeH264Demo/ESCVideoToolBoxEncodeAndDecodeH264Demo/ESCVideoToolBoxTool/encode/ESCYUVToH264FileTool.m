//
//  ESCSaveToH264FileTool.m
//  ESCCameraH264Demo
//
//  Created by xiang on 2018/6/20.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCYUVToH264FileTool.h"
#import "ESCVideoToolboxYUVToH264EncoderTool.h"

@interface ESCYUVToH264FileTool () <ESCVideoToolboxYUVToH264EncoderToolDelegate>

@property(nonatomic,strong)ESCVideoToolboxYUVToH264EncoderTool* yuvToH264EncoderTool;

@property(nonatomic,strong)NSFileHandle* fileHandle;

@property(nonatomic,assign)NSInteger frameID;

@property(nonatomic,assign)VTCompressionSessionRef EncodingSession;

@property(nonatomic,assign)NSInteger width;

@property(nonatomic,assign)NSInteger height;

@property(nonatomic,assign)NSInteger frameRate;

@property(nonatomic,assign)BOOL initComplete;

@property(nonatomic,strong)dispatch_queue_t recordQueue;

@property(nonatomic,strong)NSFileHandle* yuvDataReadFileHandle;

@property(nonatomic,copy)void(^complete)(void);

@end

@implementation ESCYUVToH264FileTool


/**
 yuv文件转h264压缩文件
 */
- (void)yuvToH264EncoderWithVideoWidth:(NSInteger)width height:(NSInteger)height yuvFilePath:(NSString *)yuvFilePath h264FilePath:(NSString *)h264FilePath frameRate:(NSInteger)frameRate complete:(void(^)(void))complete {
    
    self.complete = complete;
    self.yuvDataReadFileHandle = [NSFileHandle fileHandleForReadingAtPath:yuvFilePath];
    NSInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:yuvFilePath error:nil] fileSize];
    
    [self setupVideoWidth:width height:height frameRate:frameRate h264FilePath:h264FilePath];
    
    while(1) {
        unsigned long long  l =  [self.yuvDataReadFileHandle offsetInFile];
        if (l >= fileSize) {
            [self.yuvDataReadFileHandle closeFile];
            break;
        }
        NSData *yuvData = [self.yuvDataReadFileHandle readDataOfLength:width * height * 3 / 2];
        
        [self encoderYUVData:yuvData];
    }
    [self yuvDataIsEnd];
    
}

/**
 yuv流转h264压缩文件
 */
- (void)setupVideoWidth:(NSInteger)width
                 height:(NSInteger)height
              frameRate:(NSInteger)frameRate
           h264FilePath:(NSString *)h264FilePath {
    self.filePath = h264FilePath;
    if (self.filePath) {
        self.recordQueue = dispatch_queue_create("recordQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_async(self.recordQueue, ^{
            [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:self.filePath contents:nil attributes:nil];
            self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
            self.width = width;
            self.height = height;
            self.frameRate = frameRate;
            ESCVideoToolboxYUVToH264EncoderTool *tool = [[ESCVideoToolboxYUVToH264EncoderTool alloc] init];
            self.yuvToH264EncoderTool = tool;
            [self.yuvToH264EncoderTool setupVideoWidth:width height:height frameRate:frameRate delegate:self];
        });
    }
}

/**
 填充需要压缩的yuv流数据
 */
- (void)encoderYUVData:(NSData *)yuvData {
    [self.yuvToH264EncoderTool encoderYUVData:yuvData];
}

- (void)yuvDataIsEnd {
    [self.yuvToH264EncoderTool endYUVDataStream];
}

#pragma mark - ESCVideoToolboxYUVToH264EncoderToolDelegate
- (void)encoder:(ESCVideoToolboxYUVToH264EncoderTool *)encoder h264Data:(void *)h264Data dataLenth:(NSInteger)lenth {
    NSData *h264data = [NSData dataWithBytes:h264Data length:lenth];
//    NSLog(@"接收到数据==%d",h264data.length);
    [self.fileHandle writeData:h264data];
}

- (void)encoderEnd:(ESCVideoToolboxYUVToH264EncoderTool *)encoder {
    dispatch_async(self.recordQueue, ^{
        if (self.fileHandle) {
            [self.fileHandle closeFile];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.complete) {
                self.complete();
            }
        });
    });
}

@end
