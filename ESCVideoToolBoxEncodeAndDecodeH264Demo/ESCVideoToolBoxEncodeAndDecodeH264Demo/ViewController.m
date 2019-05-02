//
//  ViewController.m
//  ESCVideoToolBoxEncodeAndDecodeH264Demo
//
//  Created by xiang on 2019/4/29.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "ViewController.h"
#import "ESCVideoToolboxH264ToYUVDecoderTool.h"
#import "ESCYUVToH264FileTool.h"
#import "ESCH264ToYUVFileTool.h"

@interface ViewController ()

@property(nonatomic,copy)NSString* yuvFilePath;

@property(nonatomic,copy)NSString* h264FilePath;

@property(nonatomic,strong)ESCH264ToYUVFileTool* decodeFileTool;

@property(nonatomic,strong)ESCYUVToH264FileTool* encodeFileTool;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *h264FilePath = [self getFilePathWithFileName:@"test.h264"];
    self.h264FilePath = h264FilePath;
    
    [self decodetest];
}

- (NSString *)getFilePathWithFileName:(NSString *)fileName {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask , YES).lastObject;
    path = [NSString stringWithFormat:@"%@/%@",path,fileName];
    return path;
}

- (void)decodetest {
    NSString *yuvFilePath = [self getFilePathWithFileName:@"test.yuv"];
    self.yuvFilePath = yuvFilePath;
    
    ESCH264ToYUVFileTool *tool = [[ESCH264ToYUVFileTool alloc] init];
    
    NSString *h264File = [[NSBundle mainBundle] pathForResource:@"video_1280_720.h264" ofType:nil];
    NSLog(@"开始解码");
    [tool h264FileToYUVFileDecodeWithVideoYUVFilePath:yuvFilePath h264FilePath:h264File complete:^{
        NSLog(@"解码完成");
        ESCYUVToH264FileTool *encodeFileTool = [[ESCYUVToH264FileTool alloc] init];
        self.encodeFileTool = encodeFileTool;
        [self.encodeFileTool yuvToH264EncoderWithVideoWidth:1280 height:720 yuvFilePath:self.yuvFilePath h264FilePath:self.h264FilePath frameRate:25 complete:^{
            NSLog(@"编码完成");
        }];
    }];
    self.decodeFileTool = tool;
    

}

@end
