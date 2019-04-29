//
//  ESCVideoToolboxYUVToH264DecoderTool.m
//  ESCVideoToolBoxEncodeAndDecodeH264Demo
//
//  Created by xiang on 2019/4/29.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "ESCVideoToolboxYUVToH264DecoderTool.h"
#import <VideoToolbox/VideoToolbox.h>

@interface ESCVideoToolboxYUVToH264DecoderTool () {
    CMFormatDescriptionRef  mFormatDescription;
    VTDecompressionSessionRef mDecodeSession;
    
}

@property(nonatomic,assign)int width;

@property(nonatomic,assign)int height;

@property(nonatomic,strong)dispatch_queue_t decoderQueue;

@property(nonatomic,strong)NSData* spsData;

@property(nonatomic,strong)NSData* ppsData;

@property(nonatomic,assign)BOOL getSpsDataAndPpsData;

@end

@implementation ESCVideoToolboxYUVToH264DecoderTool

- (instancetype)initWithDelegate:(id)delegate width:(int)width height:(int)height {
    if (self = [super init]) {
        self.delegate = delegate;
        self.width = width;
        self.height = height;
        self.decoderQueue = dispatch_queue_create("decodequeue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)setupDecoder {
    uint8_t *spsPoint = (uint8_t *)[self.spsData bytes];
    uint8_t *ppsPoint = (uint8_t *)[self.ppsData bytes];
    size_t spsSize = self.spsData.length;
    size_t ppsSize = self.ppsData.length;
    const uint8_t* parameterSetPointers[2] = {spsPoint, ppsPoint};
    const size_t parameterSetSizes[2] = {spsSize, ppsSize};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &mFormatDescription);
    
    BOOL canAccept = VTDecompressionSessionCanAcceptFormatDescription(mDecodeSession, mFormatDescription);
    if (!canAccept) {
        if(status == noErr) {
            
            CFDictionaryRef attrs = NULL;
            const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
            uint32_t v = kCVPixelFormatType_420YpCbCr8Planar;
            const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
            attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
            
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = NULL;
            
            status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                  mFormatDescription,
                                                  NULL, attrs,
                                                  &callBackRecord,
                                                  &mDecodeSession);
            CFRelease(attrs);
        } else {
            NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
        }
    }
    return YES;
}

void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
//    NSLog(@"函数回调，解码完成  %@",*outputPixelBuffer);
    
}


- (void)decodeFrameToYUV:(NSData *)H264Data {
    dispatch_async(self.decoderQueue, ^{
        //f主要是为了关键帧解析,提取sps和pps
        uint8_t *videoData = (uint8_t *)[H264Data bytes];
        int lastJ = 0;
        
        for (int i = 0; i < H264Data.length; i++) {
            //读取头
            if (videoData[i] == 0x00 &&
                videoData[i + 1] == 0x00 &&
                videoData[i + 2] == 0x00 &&
                videoData[i + 3] == 0x01) {
                if (i > 0) {
                    //                NSLog(@"%d===%d",type,NALU);
                    int frame_size = i - lastJ;
                    [self decodeData:&videoData[lastJ] length:frame_size];
                    lastJ = i;
                }
            }else if (i == H264Data.length - 1) {
                int frame_size = i - lastJ + 1;
                [self decodeData:&videoData[lastJ] length:frame_size];
                lastJ = i;
            }
        }
    });
}

- (void)endH264Data {
    dispatch_async(self.decoderQueue, ^{
        [self destroy];
        if (self.delegate && [self.delegate respondsToSelector:@selector(endDecoder)]) {
            [self.delegate endDecoder];
        }
    });
}

- (void)decodeData:(uint8_t *)data length:(int)length {
    //对数据进行分类
    uint32_t unitLength = length - 4;
    unitLength = CFSwapInt32HostToBig(unitLength);
    uint8_t *tem = malloc(length);
    memcpy(tem, &unitLength, 4);
    memcpy(tem + 4, data + 4, length - 4);
    
    uint8_t NALU = data[4];
    int type = NALU & 0x1f;
    if (type == 7 && self.spsData == nil) {
        //sps
        self.spsData = [NSData dataWithBytes:tem + 4 length:length - 4];
    }else if (type == 8 && self.ppsData == nil){
        //pps
        self.ppsData = [NSData dataWithBytes:tem + 4 length:length - 4];
    }else if (type == 5 && self.getSpsDataAndPpsData == YES) {
        //i帧
        [self decodeVideoFrame:tem length:length];
    }else if (type == 1 && self.getSpsDataAndPpsData == YES) {
        //p和b帧 非关键帧
        [self decodeVideoFrame:tem length:length];
    }else if(type == 6) {
        //SEI
    }
    //初始化解码器
    if (self.getSpsDataAndPpsData == NO) {
        if (self.ppsData != nil && self.spsData != nil) {
            self.getSpsDataAndPpsData = YES;
            [self setupDecoder];
        }
    }

}

- (void)decodeVideoFrame:(uint8_t *)data length:(int)length {
    //解码i帧及b帧
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (mDecodeSession) {
        CMBlockBufferRef blockBuffer = NULL;
        
        OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                              (void*)data, length,
                                                              kCFAllocatorNull,
                                                              NULL, 0, length,
                                                              0, &blockBuffer);
        if(status == kCMBlockBufferNoErr) {
            CMSampleBufferRef sampleBuffer = NULL;
            const size_t sampleSizeArray[] = {length};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,
                                               mFormatDescription,
                                               1, 0, NULL, 1, sampleSizeArray,
                                               &sampleBuffer);
            if (status == kCMBlockBufferNoErr && sampleBuffer) {
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags flagOut = 0;
                // 默认是同步操作。
                // 调用didDecompress，返回后再回调
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(mDecodeSession,
                                                                          sampleBuffer,
                                                                          flags,
                                                                          &outputPixelBuffer,
                                                                          &flagOut);
                
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"IOS8VT: Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
                } else if(decodeStatus != noErr) {
                    NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
                }else if(decodeStatus == noErr){
//                    NSLog(@"success");
                }
                
                CFRelease(sampleBuffer);
            }
            CFRelease(blockBuffer);
        }
    }
    free(data);
    //提取outputpixelbuffer里面的数据
    [self copyYUV420DataToDelegateWithPixelBuffer:outputPixelBuffer];
//    NSLog(@"同步回调   %@",outputPixelBuffer);
    CVPixelBufferRelease(outputPixelBuffer);

}

- (void)copyYUV420DataToDelegateWithPixelBuffer:(CVPixelBufferRef)sampleBuffer {
    if (self.delegate && [self.delegate respondsToSelector:@selector(decoder:ydata:udata:vdata:)]) {
        
//        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(sampleBuffer, kCVPixelBufferLock_ReadOnly);
        void *y_data = CVPixelBufferGetBaseAddressOfPlane(sampleBuffer, 0);
        void *u_data = CVPixelBufferGetBaseAddressOfPlane(sampleBuffer, 1);
        void *v_data = CVPixelBufferGetBaseAddressOfPlane(sampleBuffer, 2);
        
        size_t width = CVPixelBufferGetWidth(sampleBuffer);
        size_t height = CVPixelBufferGetHeight(sampleBuffer);
    
        NSData *ydata = [NSData dataWithBytes:y_data length:width * height];
        NSData *uData = [NSData dataWithBytes:u_data length:width * height / 4];
        NSData *vData = [NSData dataWithBytes:v_data length:width * height / 4];

        CVPixelBufferUnlockBaseAddress(sampleBuffer, kCVPixelBufferLock_ReadOnly);
        
        [self.delegate decoder:self ydata:ydata udata:uData vdata:vData];
        
    }
    
    
}

- (void)destroy {
   
    if(mDecodeSession) {
        VTDecompressionSessionInvalidate(mDecodeSession);
        CFRelease(mDecodeSession);
        mDecodeSession = NULL;
    }
    
    if(mFormatDescription) {
        CFRelease(mFormatDescription);
        mFormatDescription = NULL;
    }
}

@end
