//
//  ViewController.m
//  ResumeDownloadDemo
//
//  Created by commet on 17/4/1.
//  Copyright © 2017年 commet. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSURLSessionDownloadDelegate>
@property (nonatomic ,strong)NSURLSession *backgroundSession;
@property (nonatomic,strong) NSURLSessionDownloadTask *task;
@property (nonatomic ,strong)NSFileManager *fileManager;
@property (nonatomic ,strong)NSString *docPath;//documnet文件夹(作为安全目录),把暂停时的.tmp文件、resumeData和下载完成后的文件存放到这个文件夹下，
@property (nonatomic ,strong)NSString *tmpPath;//tmp文件夹
@property (nonatomic ,strong)NSString *resumeDataPath;//储存resumeData的文件路径
@property (nonatomic ,strong)NSString *docTmpFilePath;//document下tmp文件路径
@property (nonatomic ,strong)NSData *resumeData;
@property (nonatomic,assign) BOOL downloading;

@property (nonatomic,strong) NSTimer *timer;
@property (weak, nonatomic) IBOutlet UILabel *progressLab;

@end

@implementation ViewController

- (NSURLSession *)backgroundSession{
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"backgroundSessionID"];//iOS8以前用+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    });
    return session;
}

- (NSFileManager *)fileManager
{
    if (!_fileManager)
    {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    //-stringByAppendingPathComponent:将前面的路径格式和后面的普通的字符串格式链接在一起,并且以路径格式返回
    self.resumeDataPath = [self.docPath stringByAppendingPathComponent:@"resumeData.db"];
    self.tmpPath = NSTemporaryDirectory();
    self.timer = nil;
}
- (IBAction)start:(id)sender {
    [self download];
}

- (IBAction)pause:(id)sender {
    [self pauseDownload];
}

- (void)download{
    //如果设置保存间隔过长，中间杀掉进程可能会损失较多进度
    _timer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(pauseToStoreData) userInfo:nil repeats:YES];
    
    NSString *downloadURLString = @"http://sw.bos.baidu.com/sw-search-sp/software/797b4439e2551/QQ_mac_5.0.2.dmg";
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:downloadURLString]];
    
    self.resumeData = [NSData dataWithContentsOfFile:self.resumeDataPath];
    if (self.resumeData) {
        NSArray *paths = [self.fileManager subpathsAtPath:self.docPath];//查找给定路径下的所有子路径.深度查找，不限于当前层
        for (NSString *filePath in paths){
            if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
            {
                //1.先清掉tmp文件夹下的tmp文件 -removeItemAtPath:目标目录是文件
                [self.fileManager removeItemAtPath:[self.tmpPath stringByAppendingPathComponent:filePath] error:nil];
                //2.把doucment中的tmp文件复制到tmp文件夹
                self.docTmpFilePath = [_docPath stringByAppendingPathComponent:filePath];//document文件夹中tmp文件的路径
                //-copyItemAtPath:toPath:error:拷贝到目标目录的时候，如果文件已经存在则会直接失败;目标目录必须是文件(一定要以文件名结尾，而不要以文件夹结尾)
                [self.fileManager copyItemAtPath:_docTmpFilePath toPath:[self.tmpPath stringByAppendingPathComponent:filePath] error:nil];

            }
        }
        self.task = [self.backgroundSession downloadTaskWithResumeData:self.resumeData];
        self.resumeData = nil;
    }else{
        self.task = [self.backgroundSession downloadTaskWithRequest:request];
    }
    [self.task resume];
}

- (void)pauseDownload{
    __weak typeof(self) ws = self;
    [self.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        ws.task = nil;
        ws.resumeData = resumeData;
        [resumeData writeToFile:self.resumeDataPath atomically:YES];
        
        NSArray *paths = [self.fileManager subpathsAtPath:self.tmpPath];
        for (NSString *filePath in paths)
        {
            if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
            {
                //1.先清掉document文件夹中的tmp文件
                [self.fileManager removeItemAtPath:[self.docPath stringByAppendingPathComponent:filePath] error:nil];
                //2.把tmp文件夹中的tmp文件复制到document文件夹
                self.docTmpFilePath = [self.docPath stringByAppendingPathComponent:filePath];
                NSString *path = [self.tmpPath stringByAppendingPathComponent:filePath];
                [self.fileManager copyItemAtPath:path toPath:_docTmpFilePath error:nil];
            }
        }
    }];
}

//暂停下载,获取文件指针和缓存文件
- (void)pauseToStoreData
{
    if (!_downloading)
    {
        return;
    }
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self.resumeData = resumeData;
        self.task = nil;
        [resumeData writeToFile:self.resumeDataPath atomically:YES];
        NSArray *paths = [self.fileManager subpathsAtPath:self.tmpPath];
        for (NSString *filePath in paths)
        {
            if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
            {
                //1.先清掉document文件夹中的tmp文件
                [self.fileManager removeItemAtPath:[self.docPath stringByAppendingPathComponent:filePath] error:nil];
                //2.把tmp文件夹中的tmp文件复制到document文件夹
                self.docTmpFilePath = [self.docPath stringByAppendingPathComponent:filePath];
                NSString *path = [self.tmpPath stringByAppendingPathComponent:filePath];
                [self.fileManager copyItemAtPath:path toPath:_docTmpFilePath error:nil];
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.resumeData)
            {
                self.task = [self.backgroundSession downloadTaskWithResumeData:self.resumeData];
                [self.task resume];
            }
        });
    }];
}

#pragma mark NSURLSessionDownloadDelegate
//下载完成时调用
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location{
    NSLog(@"download finish %@",location);
    
    NSString *path = [self.docPath stringByAppendingPathComponent:downloadTask.response.suggestedFilename];
    NSURL *toURL = [NSURL fileURLWithPath:path];
    [self.fileManager copyItemAtURL:location toURL:toURL error:nil];
    [self.fileManager removeItemAtPath:self.resumeDataPath error:nil];
    [self.fileManager removeItemAtPath:self.docTmpFilePath error:nil];
    [_timer invalidate];
    self.downloading = NO;
}

//跟踪下载进度
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    float progress = (float)totalBytesWritten/totalBytesExpectedToWrite;
    NSLog(@"%f",progress);
    self.progressLab.text = [NSString stringWithFormat:@"%f",progress];
    self.downloading = YES;
}

//下载恢复（resume）时调用 Tells the delegate that the download task has resumed downloading.在调用downloadTaskWithResumeData:或者 downloadTaskWithResumeData:completionHandler: 方法之后这个代理方法会被调用
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    NSLog(@"%s------------fileOffset:%lld expectedTotalBytes:%lld", __func__,fileOffset,expectedTotalBytes);
}

@end
