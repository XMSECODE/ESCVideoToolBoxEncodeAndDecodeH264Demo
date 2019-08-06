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
#import "ESCOpenGLESView.h"
#import "ESCH264View.h"

typedef struct _NaluUnit
{
    int type; //IDR or INTER：note：SequenceHeader is IDR too
    int size; //note: don't contain startCode
    unsigned char *data; //note: don't contain startCode
} NaluUnit;

@interface ViewController ()

@property(nonatomic,copy)NSString* yuvFilePath;

@property(nonatomic,copy)NSString* h264FilePath;

@property(nonatomic,strong)ESCH264ToYUVFileTool* decodeFileTool;

@property(nonatomic,strong)ESCYUVToH264FileTool* encodeFileTool;

@property(nonatomic,weak)ESCOpenGLESView* openglesView;

@property(nonatomic,weak)ESCH264View* h264View;

@property(nonatomic,strong)NSFileHandle* readFileHandle;

@property(nonatomic,weak)NSTimer* readTimer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *h264FilePath = [self getFilePathWithFileName:@"test.h264"];
    self.h264FilePath = h264FilePath;
    
    ESCOpenGLESView *openglesView = [[ESCOpenGLESView alloc] init];
    self.openglesView = openglesView;
    [self.view addSubview:self.openglesView];
    self.openglesView.showType = ESCOpenGLESViewShowTypeAspectFit;
    self.openglesView.type = ESCVideoDataTypeYUV420;
    
    ESCH264View *h264View = [[ESCH264View alloc] init];
    h264View.videoSize = CGSizeMake(1280, 720);
    [self.view addSubview:h264View];
    self.h264View = h264View;
    
    [self decodetest];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    double w = self.view.frame.size.width;
    double h = self.view.frame.size.height / 2;
    self.openglesView.frame = CGRectMake(0, 0, w, h);
    self.h264View.frame = CGRectMake(0, h, w, h);
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
            //测试YUV数据
            
            
            [self showYUVDataWithRate:20
                                width:1280
                               height:720
                             filePath:self.yuvFilePath];
            
            [self ESCH264FileShowWithh264FilePath:h264File];


        }];
    }];
    self.decodeFileTool = tool;
    

}

- (void)showYUVDataWithRate:(int)rate width:(int)width height:(int)height filePath:(NSString *)filePath {
    
    self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
    
    self.readTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / rate repeats:YES block:^(NSTimer * _Nonnull timer) {
        
        unsigned long long  l =  [self.readFileHandle offsetInFile];
        if (l >= fileSize) {
            [timer invalidate];
            [self.readFileHandle closeFile];
            return ;
        }
        NSData *yData = [self.readFileHandle readDataOfLength:width * height];
        NSData *uData = [self.readFileHandle readDataOfLength:width * height / 4];
        NSData *vData = [self.readFileHandle readDataOfLength:width * height / 4];
        
        [self.openglesView loadYUV420PDataWithYData:yData uData:uData vData:vData width:width height:height];
    }];
    
}

- (void)ESCH264FileShowWithh264FilePath:(NSString *)h264FilePath {
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:h264FilePath];
    NSData *allData = [fileHandle readDataToEndOfFile];
    uint8_t *videoData = (uint8_t*)[allData bytes];
    
    NaluUnit naluUnit;
    int cur_pos = 0;
    
    [NSTimer scheduledTimerWithTimeInterval:0.05 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if ([self ESCReadOneNaluFromAnnexBFormatH264WithNalu:&naluUnit buf:videoData buf_size:allData.length cur_pos:&cur_pos]) {
            NSData *data = [NSData dataWithBytes:naluUnit.data - 3 length:naluUnit.size + 3];
            [self.h264View pushH264DataContentSpsAndPpsData:data];
            
        }
    }];
}

- (BOOL)ESCReadOneNaluFromAnnexBFormatH264WithNalu:(NaluUnit *)nalu buf:(unsigned char *)buf buf_size:(NSInteger)buf_size cur_pos:(int *)cur_pos {
    int i = *cur_pos;
    while(i + 2 < buf_size)
    {
        if(buf[i] == 0x00 && buf[i+1] == 0x00 && buf[i+2] == 0x01) {
            i = i + 3;
            int pos = i;
            while (pos + 2 < buf_size)
            {
                if(buf[pos] == 0x00 && buf[pos+1] == 0x00 && buf[pos+2] == 0x01)
                    break;
                pos++;
            }
            if(pos+2 == buf_size) {
                (*nalu).size = pos+2-i;
            } else {
                while(buf[pos-1] == 0x00)
                    pos--;
                (*nalu).size = pos-i;
            }
            (*nalu).type = buf[i] & 0x1f;
            (*nalu).data = buf + i;
            *cur_pos = pos;
            return true;
        } else {
            i++;
        }
    }
    return false;
}

@end
