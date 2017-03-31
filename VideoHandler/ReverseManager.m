//
//  ReverseManager.m
//  VideoHandler
//
//  Created by 刘士伟 on 2017/3/30.
//  Copyright © 2017年 刘士伟. All rights reserved.
//

#import "ReverseManager.h"
#import <AVFoundation/AVFoundation.h>
#define kVideoPath NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject
typedef void (^CompletePaths)();


@interface ReverseManager()
@property(assign)int videoNum;
@property(strong,nonatomic)NSMutableArray *paths;
@property(strong,nonatomic)NSFileManager *filemanager;
@end

@implementation ReverseManager

+(instancetype)defaultManager{
    static ReverseManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ReverseManager alloc] init];
    });
    return manager;
}

-(instancetype)init{
    if (self == [super init]) {
        self.paths = [NSMutableArray array];
        self.filemanager = [NSFileManager defaultManager];
    }
    return self;
}


-(void)reverseVideoWithPath:(NSString *)path outputPath:(NSString *)outputPath Complete:(void (^)())complete{
    self.videoNum = 0;
    //分割
    [self trimWithAssetPath:path startPoint:kCMTimeZero complete:^ {
        self.videoNum = 0;
        //反转
        [self reversePathsComplete:^ {
            //合并
            [self mergeVideosWithPaths:self.paths outputPath:outputPath completed:^{
                complete();
            }];
        }];
    }];
}




//递归分割视频把路径存到数组里

- (void)trimWithAssetPath:(NSString*)assetPath startPoint:(CMTime)startPoint
                 complete:(CompletePaths)complete{
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:assetPath]];
    
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    
    if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        assetVideoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
    }
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        assetAudioTrack = [asset tracksWithMediaType:AVMediaTypeAudio][0];
    }
    
    NSError *error = nil;
    CMTime assetTime = [asset duration];
    
    
    CMTime sub1Time = CMTimeSubtract(startPoint,assetTime);
    if (CMTimeGetSeconds(sub1Time) == 0) {
        if(complete){
            complete(self.paths);
        }
        return;
    }
    
    CMTime  intervalTime = CMTimeMake(assetTime.timescale, assetTime.timescale);
    
    CMTime endTime = CMTimeAdd(startPoint, intervalTime);
    
    CMTime subTime = CMTimeSubtract(endTime,assetTime);
    
    if (CMTimeGetSeconds(subTime) > 0){
        intervalTime = CMTimeSubtract(intervalTime,subTime);
        endTime = CMTimeAdd(startPoint, intervalTime);
    }
    
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    
    // Insert half time range of the video and audio tracks from AVAsset
    AVMutableCompositionTrack *compositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(startPoint, intervalTime) ofTrack:assetVideoTrack atTime:kCMTimeZero error:&error];
    
    
    AVMutableCompositionTrack *compositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(startPoint, intervalTime) ofTrack:assetAudioTrack atTime:kCMTimeZero error:&error];
    
    NSString *outPath = [kVideoPath stringByAppendingPathComponent: [NSString stringWithFormat:@"%d.mp4", self.videoNum]];
    self.videoNum++;
    
    NSURL *mergeFileURL = [NSURL fileURLWithPath:outPath];
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mutableComposition presetName:AVAssetExportPresetHighestQuality];
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    //        exporter.videoComposition = mixVideoComposition;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        [self.paths addObject:outPath];
        [self trimWithAssetPath:assetPath startPoint:endTime complete:complete];
    }];
    
}



//递归反转

- (void)reversePathsComplete:(CompletePaths)complete{
    if (self.videoNum == self.paths.count) {
        complete(self.paths);
        return;
    }
    NSString *path = self.paths[self.videoNum];
    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
    NSString *reversePath = [NSString stringWithFormat:@"reverse%d.mp4", self.videoNum];
    NSString *pathStr = [kVideoPath stringByAppendingPathComponent:reversePath];
    NSURL *outputUrl = [NSURL fileURLWithPath:pathStr];
    [self assetByReversingAsset:asset outputURL:outputUrl complete:^(AVAsset *asset) {
        NSError *error = nil;
        [self.filemanager removeItemAtPath:self.paths[self.videoNum] error:&error];
        
        [self.paths replaceObjectAtIndex:self.videoNum withObject:pathStr];
        self.videoNum++;
        [self reversePathsComplete:complete];
    }];
}
//反转视频具体方法
- (void)assetByReversingAsset:(AVAsset *)asset outputURL:(NSURL *)outputURL complete:( void (^)(AVAsset *asset))complete{
    NSError *error;
    
    // Initialize the reader
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
    
    NSDictionary *readerOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], kCVPixelBufferPixelFormatTypeKey, nil];
    AVAssetReaderTrackOutput* readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack
                                                                                        outputSettings:readerOutputSettings];
    [reader addOutput:readerOutput];
    [reader startReading];
    
    // read in the samples
    NSMutableArray *samples = [[NSMutableArray alloc] init];
    
    CMSampleBufferRef sample;
    
    while((sample = [readerOutput copyNextSampleBuffer])) {
        [samples addObject:(__bridge id)sample];
        CFRelease(sample);
    }
    
    // Initialize the writer
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outputURL
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @(videoTrack.estimatedDataRate), AVVideoAverageBitRateKey,
                                           nil];
    NSDictionary *writerOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                          AVVideoCodecH264, AVVideoCodecKey,
                                          [NSNumber numberWithInt:videoTrack.naturalSize.width], AVVideoWidthKey,
                                          [NSNumber numberWithInt:videoTrack.naturalSize.height], AVVideoHeightKey,
                                          videoCompressionProps, AVVideoCompressionPropertiesKey,
                                          nil];
    AVAssetWriterInput *writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                     outputSettings:writerOutputSettings
                                                                   sourceFormatHint:(__bridge CMFormatDescriptionRef)[videoTrack.formatDescriptions lastObject]];
    [writerInput setExpectsMediaDataInRealTime:NO];
    
    // Initialize an input adaptor so that we can append PixelBuffer
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:writerInput sourcePixelBufferAttributes:nil];
    
    [writer addInput:writerInput];
    
    [writer startWriting];
    [writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp((__bridge CMSampleBufferRef)samples[0])];
    
    // Append the frames to the output.
    // Notice we append the frames from the tail end, using the timing of the frames from the front.
    for(NSInteger i = 0; i < samples.count; i++) {
        // Get the presentation time for the frame
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp((__bridge CMSampleBufferRef)samples[i]);
        // take the image/pixel buffer from tail end of the array
        CVPixelBufferRef imageBufferRef = CMSampleBufferGetImageBuffer((__bridge CMSampleBufferRef)samples[samples.count - i - 1]);
        
        while (!writerInput.readyForMoreMediaData) {
            [NSThread sleepForTimeInterval:0.01];
        }
        
        [pixelBufferAdaptor appendPixelBuffer:imageBufferRef withPresentationTime:presentationTime];
        
    }
    
    [writer finishWritingWithCompletionHandler:^{
        complete([AVAsset assetWithURL:outputURL]);
    }];
    
}


//合并视频

- (void)mergeVideosWithPaths:(NSArray *)paths outputPath:(NSString *)outputPath completed:(void(^)())completed {
    if (!paths.count) return;
 
        AVMutableComposition* mixComposition = [[AVMutableComposition alloc] init];
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        videoTrack.preferredTransform = CGAffineTransformIdentity;
        
        for (int i = 0; i < paths.count; i++) {
            AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:paths[i]]];
            
            AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo]firstObject];
            
            NSError *errorVideo = nil;
            
            BOOL bl = [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:assetVideoTrack atTime:kCMTimeZero error:&errorVideo];
            NSLog(@"errorVideo:%@--%d",errorVideo,bl);
            NSError *error = nil;
            [self.filemanager removeItemAtPath:paths[i] error:&error];
            
        }
        
        NSURL *mergeFileURL = [NSURL fileURLWithPath:outputPath];
        
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
        exporter.outputURL = mergeFileURL;
        exporter.outputFileType = AVFileTypeQuickTimeMovie;
        //        exporter.videoComposition = mixVideoComposition;
        exporter.shouldOptimizeForNetworkUse = YES;
        [exporter exportAsynchronouslyWithCompletionHandler:^{
           
            dispatch_async(dispatch_get_main_queue(), ^{
                completed();
            });
        }];
   
}




@end
