//
//  GenseeVideo.m
//  手机学堂
//
//  Created by Wilson on 2017/8/24.
//
//

#import "GenseeVideo.h"
#import "JSONKit.h"
#import "HTTPRequestManager.h"
#import "UIImageView+AFNetworking.h"
#import <PlayerSDK/PlayerSDK.h>
#import "UIView+Toast.h"

#define ScreenWidth [UIScreen mainScreen].bounds.size.width
#define ScreenHeight [UIScreen mainScreen].bounds.size.height
#define BarWidth 50.f
#define iconWidth 35.f

//默认封面图
static NSString *defaultCoverImg = @"gensee_default_cover.jpg";
//直播密码
static NSString *PASSWORD = @"watchPassword";
//直播id
static NSString *WEBCASTID = @"webCastID";
//直播类型
static NSString *TYPE = @"serviceType";
//直播域名
static NSString *kDOMAIN = @"domain";
//直播状态
static NSString *STATUS = @"status";
//问题
static NSString *QUESTION = @"question";

#pragma mark - res code
//code
static NSString *CODE = @"code";
//data
static NSString *DATA = @"data";
//发生错误
static NSString *ERROR = @"0";
//正常
static NSString *DEFAULT = @"200";
//请求成功，返回详情数据
static NSString *DETAIL = @"1";
//请求成功，返回文档数据
static NSString *DOC = @"2";
//请求成功，收到聊天数据
static NSString *CHAT = @"3";
//请求成功，返回问答数据
static NSString *QA = @"4";
//返回
static NSString *BACK = @"5";
//分享
static NSString *SHARE = @"6";
//收藏
static NSString *COLLECT = @"7";
//收键盘
static NSString *BLUR = @"9";

//缺少参数
static NSString *PARAMS_ERR = @"缺少参数";

#define CurrMode                     [UIScreen instancesRespondToSelector:@selector(currentMode)]
#define ModelSize                    [[UIScreen mainScreen] currentMode].size
#define iPhone4_4S                   (CurrMode? CGSizeEqualToSize(CGSizeMake(640, 960), ModelSize) : NO)
#define iPhone5_5S_5C                (CurrMode? CGSizeEqualToSize(CGSizeMake(640, 1136), ModelSize) : NO)
#define iPhone6_6S                   (CurrMode? CGSizeEqualToSize(CGSizeMake(750, 1334), ModelSize) : NO)
#define iPhone6plus_6Splus           (CurrMode? CGSizeEqualToSize(CGSizeMake(1242, 2208), ModelSize) : NO)
#define iPhone6ZoomMode              (CurrMode? CGSizeEqualToSize(CGSizeMake(640, 1136),ModelSize):NO)
#define iPhone6plusZoomMode          (CurrMode? CGSizeEqualToSize(CGSizeMake(1125, 2001),ModelSize):NO)

@interface GenseeVideo ()<GSPPlayerManagerDelegate,GSPDocViewDelegate>
{
    CGRect _videoRect;//记录视频窗口原始尺寸
}
@property (nonatomic, strong) CDVInvokedUrlCommand * openCommand;

@property (nonatomic, strong) CDVInvokedUrlCommand * receiveMsgCommand;

@property (nonatomic, strong) CDVInvokedUrlCommand * receiveQACommand;

@property (nonatomic, strong) CDVInvokedUrlCommand * backCommand;

@property (nonatomic, strong) CDVInvokedUrlCommand * shareCommand;

@property (nonatomic, strong) CDVInvokedUrlCommand * collectCommand;

@property (nonatomic, strong) CDVInvokedUrlCommand * handupCommand;

@property (nonatomic, assign) long uid; //直播权限返回uid

//这是展示互动的直播管理类，所有的管理都通过这个类来触发
@property (nonatomic, strong) GSPPlayerManager * playerManager;

//用于显示直播视频的类
@property (nonatomic, strong) GSPVideoView * videoView;

//用于直播文档的类
@property (nonatomic, strong) GSPDocView * docView;

//doccontainer
@property (nonatomic, strong) UIView * docContainer;

//videocontainer
@property (nonatomic, weak) UIView * videoContainer;

//toolBar
@property (nonatomic, strong) UIView *toolBar;

//functionBar
@property (nonatomic, strong) UIView *functionBar;

//如果直播没开启视频，则显示这个defaultView
@property (nonatomic, weak) UIImageView * defaultView;

//关闭视频显示的图片
@property (nonatomic, strong) UIImageView * hiddenView;

//控制全屏按钮
@property (nonatomic, strong) UIButton *fullScreenBtn;

//收藏按钮
@property (nonatomic, strong) UIButton *collectBtn;

//分享按钮
@property (nonatomic, strong) UIButton *shareBtn;

//直播是否被收藏
@property (nonatomic, assign) BOOL hasCollcted;

//是否举手
@property (nonatomic, assign) BOOL isHandup;

//是否关闭视频
@property (nonatomic, assign) BOOL isCloseVideo;

//是否有视频
@property (nonatomic, assign) BOOL hasVideo;

//是否全屏
@property (nonatomic, assign) BOOL isFullScreen;

//是否有文档
@property (nonatomic, assign) BOOL hasDoc;

//是否当前文档界面
@property (nonatomic, assign) BOOL isDocView;

//键盘弹起监听
@property (nonatomic, strong) id notificationObserver1;
//键盘收回监听
@property (nonatomic, strong) id notificationObserver2;
@end

@implementation GenseeVideo

- (void)dealloc {
    [self.playerManager leave];
    [[NSNotificationCenter defaultCenter] removeObserver:self.notificationObserver1];
    [[NSNotificationCenter defaultCenter] removeObserver:self.notificationObserver2];

}

#pragma mark - init gensee
//初始化直播
- (void)openGensee:(CDVInvokedUrlCommand *)command {
    //标示是首次进入直播，还是切换直播源
    BOOL changeGensee = NO;
    //标示该直播是否被收藏
    self.hasCollcted = NO;
    //标示是否举手
    self.isHandup = NO;
    //标示是否关闭视频
    self.isCloseVideo = NO;
    //是否全屏
    self.isFullScreen = NO;
    //是否有文档
    self.hasDoc = NO;
    //是否当前为文档界面
    self.isDocView = NO;
    //默认没视频
    self.hasVideo = NO;
    
    if(self.playerManager) {
        //切换播放源
        changeGensee = YES;
        [self.playerManager leave];
    }
    __weak __typeof(self) weakSelf = self;
   self.notificationObserver1 = [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
       CGRect frame = weakSelf.videoContainer.frame;
       frame.origin.y = 20;
       weakSelf.videoContainer.frame = frame;
    }];
    self.notificationObserver2 = [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        CGRect frame = weakSelf.videoContainer.frame;
        frame.origin.y = 64;
        weakSelf.videoContainer.frame = frame;
    }];
    self.openCommand = command;
    CDVPluginResult * result = nil;

    //请求域名access
    NSString * access = [command argumentAtIndex:0];
    //系统中的直播id
    NSString * genseeId = [command argumentAtIndex:2];
    //当前用户的昵称
    
    if(access == nil || genseeId == nil || ![access length] || ![genseeId length]) {
        //如果没传数据过来，则return
        NSDictionary *json = @{CODE:ERROR,DATA:PARAMS_ERR};
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
        [self.commandDelegate runInBackground:^{
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
        [result setKeepCallbackAsBool:YES];
        return;
    }
    
    //先请求权限、直播详情信息，之后再根据返回信息初始化直播
    [self genseeAccessRequest:command genseeOnChange:changeGensee];
}

//请求一下，看是否有参与直播的权限
- (void)genseeAccessRequest:(CDVInvokedUrlCommand *)command genseeOnChange:(BOOL)changeGensee{
    
    //请求域名access
    NSString * access = [command argumentAtIndex:0];
    //系统中的直播id
    NSString * genseeId = [command argumentAtIndex:3];
    //请求cookie
    NSString * cookie = [command argumentAtIndex:4];
    //授权
    NSArray * strs = [cookie componentsSeparatedByString:@"="];
    NSString * authorization = @"";
    if(strs && strs.count) {
        authorization = [strs lastObject];
    }
    NSDictionary * headers = @{@"Cookie":cookie,
                               @"Authorization":authorization};
    
    NSDictionary * dict = @{@"genseeId":genseeId};
    
    __block CDVPluginResult * result = nil;
    __weak __typeof(self) weakSelf = self;

    //获取播放权限
    [[HTTPRequestManager shareInstance] post:access params:dict header:headers success:^(HTTPRequestManager *manager, id model) {
        NSNumber *uid = [model objectForKey:@"uid"];
        NSNumber *errCode = [model objectForKey:@"errCode"];
        if ((NSNull *)uid != [NSNull null]) {
            self.uid = [[model objectForKey:@"uid"] longLongValue];
        }
        if (errCode == nil) {
            [self genseeDetailRequest:command genseeOnChange:changeGensee];
        } else {
            NSString *errMsg = @"";
            switch ([errCode longLongValue]) {
                case 40314:
                    errMsg = @"您当前的网络不稳定，请重试";
                    break;
                case 40304:
                    errMsg = @"直播创建失败";
                    break;
                case 40901:
                    errMsg = @"用户不在受众范围内";
                    break;
                case 40305:
                    errMsg = @"当前直播参与人数超出限制，不允许继续参加";
                    break;
                case 40308:
                    errMsg = @"该资源已不存在";
                    break;
                case 40309:
                    errMsg = @"您暂无该资源浏览权限，去看看其它资源吧";
                    break;
                case 900005:
                    errMsg = @"该资源已不存在";
                    break;
                default:
                    break;
            }
            NSDictionary *json = @{CODE:ERROR,DATA:errMsg};
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
            [weakSelf leave];
            [self.commandDelegate runInBackground:^{
                [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        }
        
    } failed:^(HTTPRequestManager *manager, NSError *error) {
        NSDictionary *json = @{CODE:ERROR,DATA:@"请求权限失败"};
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
        [weakSelf leave];
        [self.commandDelegate runInBackground:^{
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
        NSLog(@"http authErr:%@",error);
    }];
}

//请求直播详情信息，并返回js端
- (void)genseeDetailRequest:(CDVInvokedUrlCommand *)command genseeOnChange:(BOOL)changeGensee {
    //请求域名detail
    NSString * detail = [command argumentAtIndex:1];
    //系统中的直播id
    NSString * genseeId = [command argumentAtIndex:3];
    //请求cookie
    NSString * cookie = [command argumentAtIndex:4];
    //授权
    NSArray * strs = [cookie componentsSeparatedByString:@"="];
    NSString * authorization = @"";
    if(strs && strs.count) {
        authorization = [strs lastObject];
    }
    detail = [NSString stringWithFormat:@"%@/%@",detail,genseeId];
    
    NSDictionary * header = @{@"Cookie":cookie,
                              @"Authorization":authorization};
    
    __block CDVPluginResult * result = nil;
    __weak __typeof(self) weakSelf = self;

    //获取直播详情信息
    [[HTTPRequestManager shareInstance] get:detail headers:header success:^(HTTPRequestManager *manager, id model) {
        
        NSDictionary * data = model;
        //查看当前直播是否被收藏了
        [self hasCollect:data command:command genseeOnchange:changeGensee];
        
    } failed:^(HTTPRequestManager *manager, NSError *error) {
        //请求失败了，返回错误信息
        NSDictionary *json = @{CODE:ERROR,DATA:@"获取直播详情失败"};
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
        [self.commandDelegate runInBackground:^{
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
        NSLog(@"genseDetailErr:%@",error);
    }];
}

- (void)hasCollect:(NSDictionary *)data command:(CDVInvokedUrlCommand *)command genseeOnchange:(BOOL)changeGensee {
    //请求域名
    NSString * hasCollect = [command argumentAtIndex:2];
    //系统中的直播id
    NSString * genseeId = [command argumentAtIndex:3];
    //请求cookie
    NSString * cookie = [command argumentAtIndex:4];
    //授权
    NSArray * strs = [cookie componentsSeparatedByString:@"="];
    NSString * authorization = @"";
    if(strs && strs.count) {
        authorization = [strs lastObject];
    }
    hasCollect = [NSString stringWithFormat:@"%@%@",hasCollect,genseeId];
    
    NSDictionary * header = @{@"Cookie":cookie,
                              @"Authorization":authorization};
    
    __block CDVPluginResult * result = nil;
    __weak __typeof(self) weakSelf = self;

    //获取直播详情信息
    [[HTTPRequestManager shareInstance] get:hasCollect headers:header success:^(HTTPRequestManager *manager, id model) {
        
        NSDictionary * dict = model;
        NSString * collectID = [dict objectForKey:@"id"];
        self.hasCollcted = collectID && ![collectID isKindOfClass:[NSNull class]] ? YES : NO;
        //创建直播
        [self createGensee:data command:command genseeOnChange:changeGensee];
        
    } failed:^(HTTPRequestManager *manager, NSError *error) {
        //请求失败了，返回错误信息
        NSDictionary *json = @{CODE:ERROR,DATA:@"获取直播详情失败"};
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
        [self.commandDelegate runInBackground:^{
            [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
        NSLog(@"DetailErr:%@",error);
    }];
    
}

//创建直播控件gensee
- (void)createGensee:(NSDictionary *)data command:(CDVInvokedUrlCommand *)command genseeOnChange:(BOOL)changeGensee {
    //解析直播详情参数
    NSMutableDictionary * resultData =[[NSMutableDictionary alloc] initWithDictionary:[self genseeDetailDataParse:data]];
    //返回详情信息给js
    CDVPluginResult * result = nil;
    NSDictionary * jsonDict = @{CODE:DETAIL,DATA:data};
    
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[jsonDict JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
    if(![[resultData objectForKey:STATUS] isEqualToString:@"2"]) {
        //只有进行中的才需要初始化直播控件，否则return
        return;
    }
    if(!changeGensee) {
        //创建直播管理类
        _playerManager = [[GSPPlayerManager alloc] init];
        _playerManager.delegate = self;
        
        [self initUIWithData:resultData command:command];
    }
    
    //新建直播参数，用于匹配相应的直播
    GSPJoinParam * joinParam = [GSPJoinParam new];
    joinParam.domain = [resultData objectForKey:kDOMAIN];
    joinParam.serviceType = [[resultData objectForKey:TYPE] isEqualToString:@"1"] ? GSPServiceTypeTraining : GSPServiceTypeWebcast;
    joinParam.webcastID = [resultData objectForKey:WEBCASTID];
    joinParam.nickName = [command argumentAtIndex:5];
    joinParam.customUserID = self.uid;
    joinParam.watchPassword = [resultData objectForKey:PASSWORD];
    
    //加入直播
    [_playerManager joinWithParam:joinParam];
}

- (void)initUIWithData:(NSDictionary *)resultData command:(CDVInvokedUrlCommand *)command {
    self.viewController.view.backgroundColor = [UIColor colorWithRed:243.f/255.f green:243.f/255.f blue:243.f/255.f alpha:1.f];
    self.viewController.view.frame = [UIScreen mainScreen].bounds;
    CGFloat kScreenWidth = ScreenWidth;
    //按这个比例算出来高宽
    CGFloat videoHeight  = (kScreenWidth * 243) / kScreenWidth;
    if(iPhone4_4S || iPhone5_5S_5C || iPhone6ZoomMode) {
        videoHeight = (kScreenWidth * 9) / 16 + 15;
    } else if (iPhone6_6S) {
        videoHeight = (kScreenWidth * 9) / 16 + 20;
    } else if (iPhone6plusZoomMode) {
        videoHeight = (kScreenWidth * 9) / 16 + 12;
    }
    UIView * container = [[UIView alloc] initWithFrame:CGRectMake(0, 64, kScreenWidth, videoHeight)];
    [container setBackgroundColor:[UIColor clearColor]];
    _videoRect = container.frame;
    [self.viewController.view addSubview:container];
    self.videoContainer = container;
    
    GSPVideoView * videoView = [[GSPVideoView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(container.frame), CGRectGetHeight(container.frame))];
    [container addSubview:videoView];
    videoView.videoLayer.videoGravity = AVLayerVideoGravityResize;

    UIView *docContainer = [[UIView alloc] initWithFrame:CGRectMake(0, videoHeight+46+25+44, ScreenWidth, ScreenHeight-CGRectGetHeight(container.frame)-46-25-44)];
    docContainer.backgroundColor = [UIColor colorWithRed:243.f/255.f green:243.f/255.f blue:243.f/255.f alpha:1.f];
    docContainer.hidden = YES;
    self.docContainer = docContainer;
    [self.viewController.view addSubview:docContainer];

    GSPDocView *docView = [[GSPDocView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth, CGRectGetHeight(docContainer.frame))];
    docView.center = CGPointMake(ScreenWidth/2.f, CGRectGetHeight(docContainer.frame)/2.f);
    docView.backgroundColor = [UIColor colorWithRed:243.f/255.f green:243.f/255.f blue:243.f/255.f alpha:1.f];
    [docView setGlkBackgroundColor:243 green:243 blue:243];
    docView.pdocDelegate = self;
    docView.zoomEnabled = YES;
    docView.gSDocModeType = ScaleAspectFitEx;
    self.docView = docView;
    [docContainer addSubview:docView];

//    UIImageView * defaultView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(videoView.frame), CGRectGetHeight(videoView.frame))];
//
//    NSString *coverUrl = [command argumentAtIndex:6];
//    //请求cookie
//    NSString * cookie = [command argumentAtIndex:4];
//    //授权
//    NSArray * strs = [cookie componentsSeparatedByString:@"="];
//    NSString * authorization = @"";
//    if(strs && strs.count) {
//        authorization = [strs lastObject];
//    }
//    NSDictionary * header = @{@"Cookie":cookie,
//                              @"Authorization":authorization};
//
//    coverUrl = [NSString stringWithFormat:@"%@%@",coverUrl,[resultData objectForKey:@"cover"]];
//    AFImageDownloader *downloader = [UIImageView sharedImageDownloader];
//    HTTPRequestManager *httpManager = [HTTPRequestManager shareInstance];
//    httpManager.manager.responseSerializer = [AFImageResponseSerializer serializer];
//    [httpManager.manager.requestSerializer setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:coverUrl]];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            if (imgData) {
//                defaultView.image = [UIImage imageWithData:imgData];
//            } else {
//                defaultView.image = [UIImage imageNamed:defaultCoverImg];
//            }
//        });
//    });

//    [videoView addSubview:defaultView];
//    self.defaultView = defaultView;
    
    UIImageView *hiddenView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, videoHeight)];
    hiddenView.image = [UIImage imageNamed:@"noVideo"];
    self.hiddenView = hiddenView;
    [self.videoContainer addSubview:hiddenView];
    
    UIView * topContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(container.frame), BarWidth)];
    [topContainer setBackgroundColor:[UIColor clearColor]];
    topContainer.hidden = YES;
    self.toolBar = topContainer;
    [self.videoContainer addSubview:topContainer];
    
    //返回键
    UIButton * backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(10, 10, iconWidth, iconWidth);
    [backBtn setBackgroundImage:[UIImage imageNamed:@"back_icon"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    [topContainer addSubview:backBtn];
    
    //分享键
    UIButton * shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    shareBtn.frame = CGRectMake(CGRectGetWidth(topContainer.frame) - 10 - iconWidth, 10, iconWidth, iconWidth);
    self.shareBtn = shareBtn;
    [shareBtn setBackgroundImage:[UIImage imageNamed:@"share_icon"] forState:UIControlStateNormal];
    [shareBtn addTarget:self action:@selector(share) forControlEvents:UIControlEventTouchUpInside];
    [topContainer addSubview:shareBtn];
    
    //收藏键
    UIButton * collectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    collectBtn.frame = CGRectMake(CGRectGetMinX(shareBtn.frame) - 10 - iconWidth, 10, iconWidth, iconWidth);
    self.collectBtn = collectBtn;
    NSString * imageName = self.hasCollcted ? @"collect_icon_pre" : @"collect_icon_nor";
    [collectBtn setBackgroundImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    [collectBtn addTarget:self action:@selector(collect:) forControlEvents:UIControlEventTouchUpInside];
    [topContainer addSubview:collectBtn];
    
     UIView *functionView = [[UIView alloc] initWithFrame:CGRectMake(kScreenWidth-BarWidth ,10+BarWidth , BarWidth, videoHeight-(10+BarWidth))];
    functionView .backgroundColor = [UIColor clearColor];
    self.functionBar = functionView;
    [self.videoContainer addSubview:functionView];

    UIButton *handupBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    handupBtn.frame = CGRectMake(CGRectGetWidth(functionView.frame)-10-iconWidth, 0, iconWidth, iconWidth);
    [handupBtn setBackgroundImage:[UIImage imageNamed:@"handup"] forState:UIControlStateNormal];
    [handupBtn addTarget:self action:@selector(handup:) forControlEvents:UIControlEventTouchUpInside];
    [functionView addSubview:handupBtn];

    UIButton *closeVideoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeVideoBtn.frame = CGRectMake(CGRectGetMinX(handupBtn.frame), CGRectGetMaxY(handupBtn.frame)+10, iconWidth, iconWidth);
    [closeVideoBtn setBackgroundImage:[UIImage imageNamed:@"close_screen"] forState:UIControlStateNormal];
    [closeVideoBtn addTarget:self action:@selector(closeVideo) forControlEvents:UIControlEventTouchUpInside];
    [functionView addSubview:closeVideoBtn];
    
    UIButton *fullBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    fullBtn.frame = CGRectMake(CGRectGetMinX(closeVideoBtn.frame), CGRectGetMaxY(closeVideoBtn.frame)+10, iconWidth, iconWidth);
    self.fullScreenBtn = fullBtn;
    [fullBtn setBackgroundImage:[UIImage imageNamed:@"full_screen"] forState:UIControlStateNormal];
    [fullBtn addTarget:self action:@selector(fullScreen:) forControlEvents:UIControlEventTouchUpInside];
    
    [functionView addSubview:fullBtn];
    
    _playerManager.videoView = videoView;
    _playerManager.docView = docView;
}

//解析直播详情信息
- (NSDictionary *)genseeDetailDataParse:(NSDictionary *)data {
    NSMutableDictionary * resultData = [NSMutableDictionary dictionary];
    
    //domain
    NSString * domain = [data objectForKey:@"attendeeShortJoinUrl"];
    if (domain && (NSNull *) domain != [NSNull null]) {
        NSArray * strs = [domain componentsSeparatedByString:@"//"];
        domain = [strs count] > 1 ? [[[strs objectAtIndex:1] componentsSeparatedByString:@"/"] firstObject] : @"";
    }
        //webCastID
    NSString * webCastID = [data objectForKey:@"webCastId"]?[data objectForKey:@"webCastId"]:@"";
    
    //直播status 0 未发布 1未开始 2进行中 3已结束 4已撤销
    NSString * status = [NSString stringWithFormat:@"%@",[data objectForKey:@"status"]];
    
    //serviceType 1training 其他webcast
    NSString * serviceType = [NSString stringWithFormat:@"%@",[data objectForKey:@"type"]];
    
    //直播口令
    NSString * watchPassword = [serviceType isEqualToString:@"1"] ? [data objectForKey:@"clientAttendeeToken"] : [data objectForKey:@"attendeeToken"];
    
    //封面图
    NSString * cover = [NSString stringWithFormat:@"%@",[data objectForKey:@"cover"] ? [data objectForKey:@"cover"] : @""];
    
    [resultData setObject:domain forKey:kDOMAIN];
    [resultData setObject:webCastID forKey:WEBCASTID];
    [resultData setObject:status forKey:STATUS];
    [resultData setObject:serviceType forKey:TYPE];
    [resultData setObject:watchPassword forKey:PASSWORD];
    [resultData setObject:cover forKey:@"cover"];
    
    return resultData;
}

#pragma mark - gensee delegate functions
//加入直播回调
- (void)playerManager:(GSPPlayerManager *)playerManager didReceiveSelfJoinResult:(GSPJoinResult)joinResult {
    
    CDVPluginResult *result = nil;
    NSDictionary * json = @{};
    NSString *msg = nil;

    if(joinResult == GSPJoinResultOK) {
        //加入直播成功
        NSLog(@"成功加入直播");
        msg = @"您已加入成功";
    } else {
        switch (joinResult) {
            case GSPJoinResultLICENSE:
                msg = @"人数已满";
                break;
                case GSPJoinResultTimeout:
                msg = @"连接超时";
                break;
                case GSPJoinResultCONNECT_FAILED:
                msg = @"连接失败";
                break;
                case GSPJoinResultREJOIN:
                msg = @"您的账号在另一地点登录，您被迫下线";
                break;
                case GSPJoinResultTOO_EARLY:
                msg = @"直播尚未开始";
                break;
            default:
                msg = @"连接错误";
                break;
                
        }
    }
    json = @{CODE:ERROR,DATA:msg};
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.openCommand.callbackId];
    }];
}

/**
 *  自己离开了直播，会调用此代理
 *
 *  @param playerManager 调用该代理的直播管理实例
 *  @param reason        离开直播的原因
 */
- (void)playerManager:(GSPPlayerManager *)playerManager didSelfLeaveFor:(GSPLeaveReason)reason {
    CDVPluginResult *result = nil;
    NSDictionary * json = @{};
    NSString *msg = nil;
    switch (reason) {
        case GSPLeaveReasonClosed:
            msg = @"直播间已经被关闭";
            break;
        default:
            msg = @"已退出直播间";
            break;
    }
    json = @{CODE:ERROR,DATA:msg};
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.openCommand.callbackId];
    }];
}

/**
 *  收到聊天信息代理
 *
 *  @param playerManager 调用该代理的直播管理实例
 *  @param message       收到的聊天信息
 */
- (void)playerManager:(GSPPlayerManager *)playerManager didReceiveChatMessage:(GSPChatMessage *)message {
    
    //收到消息后，回传给js
    CDVPluginResult * result = nil;
    NSString * time = [NSString stringWithFormat:@"%lld",message.receiveTime];
    if(time.length > 10) {
        time = [time substringToIndex:10];
    }
    NSDictionary * dict = @{@"content":message.text,
                            @"senderName":message.senderName,
                            @"senderUserID":[NSString stringWithFormat:@"%lld",message.senderUserID],
                            @"sendTime":[NSNumber numberWithDouble:time.doubleValue]
                            };
    
    NSDictionary * json = @{CODE:CHAT,DATA:dict};
    
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[json JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.receiveMsgCommand.callbackId];
    }];
}

/**
 *  收到问答信息代理
 *
 *  @param playerManager 调用该代理的直播管理实例
 *  @param qaDatas       收到的问答信息数组，数组成员为GSPQaData实例
 */
- (void)playerManager:(GSPPlayerManager *)playerManager didReceiveQaData:(NSArray *)qaDatas {
    
    GSPQaData * qData = [qaDatas objectAtIndex:0];
    NSString * time = [NSString stringWithFormat:@"%lld",qData.time];
    NSString * ownerName = qData.ownerName;
    NSString * resName = @"";
    NSString * qContent = qData.content;
    NSString * rContent = @"";

    NSString * isCanceled = [NSString stringWithFormat:@"%d",qData.isCanceled];
    NSString * isQuestion = [NSString stringWithFormat:@"%d",qData.isQuestion];
    NSString * qId = qData.questionID;
    NSDictionary *resDict = @{};

    if (qaDatas.count > 1) {
        GSPQaData * rData = [qaDatas objectAtIndex:1];
        time = [NSString stringWithFormat:@"%lld",rData.time];
        resName = rData.ownerName;
        rContent = rData.content;
        qId = rData.questionID;
        isCanceled = [NSString stringWithFormat:@"%d",rData.isCanceled];
        isQuestion = [NSString stringWithFormat:@"%d",rData.isQuestion];
    }
    if(time.length > 10) {
        time = [time substringToIndex:10];
    }
    
    resDict = @{@"time": [NSNumber numberWithInt:time.intValue],
                @"ownerName": ownerName,
                @"resName":resName,
                @"qContent": qContent,
                @"rContent": rContent,
                @"questionId": qId,
                @"isCanceled":isCanceled,
                @"isQuestion":isQuestion};

    NSDictionary * jsonResult = @{CODE:QA,DATA:@{QUESTION:resDict}};

    
    //收到消息后，回传给js
    CDVPluginResult * result = nil;
    
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[jsonResult JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [weakSelf.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.receiveQACommand.callbackId];
    }];
}

//直播的视频开启了，把默认图片隐藏
- (void)playerManagerDidVideoBegin:(GSPPlayerManager *)playerManager {
//    [self.defaultView setHidden:YES];
    self.hasVideo = YES;
    self.hiddenView.hidden = YES;
    self.isCloseVideo = NO;
}

//视频返回数据
- (void)playerManager:(GSPPlayerManager*)playerManager didReceiveVideoData:(const unsigned char*)data height:(int)height width:(int)width {
    
}

//直播的视频关闭了，显示暂无视频
- (void)playerManagerDidVideoEnd:(GSPPlayerManager *)playerManager {
//    [self.defaultView setHidden:NO];
//    [self.defaultView setHidden:YES];
    self.hiddenView.hidden = NO;
    self.isCloseVideo = YES;
    self.hasVideo = NO;
}

/**
 *  自己是否被禁言
 *
 *  @param playerManager 调用该代理的直播管理实例
 *  @param bMute         是否被禁言，YES表示被禁言
 */
- (void)playerManager:(GSPPlayerManager*)playerManager isSelfMute:(BOOL)bMute {
    
}
/**
 *  文档切换事件代理
 *
 *  @param playerManager 调用该代理的直播管理实例
 */
- (void)playerManagerDidDocumentSwitch:(GSPPlayerManager*)playerManager {
    NSLog(@"DOC SWITCH");
}
/**
 *  文档关闭事件代理
 *
 *  @param playerManager 调用该代理的直播管理实例
 */

-(void)playerManagerDidDocumentClose:(GSPPlayerManager *)playerManager {
    NSLog(@"DOC CLOSE");
    self.hasDoc = NO;
    self.docContainer.hidden = YES;
}

//文档代理
-(void)docViewPOpenFinishSuccess:(GSPDocPage *)page docID:(unsigned int)docID {
    self.hasDoc = YES;
    if (self.isDocView) {
        self.docContainer.hidden = NO;
    }
}

#pragma mark - js call native
//从js过来之后，先注册一个native回传js的通道CDVInvokedUrlCommand对象
- (void)receivceMessage:(CDVInvokedUrlCommand *)command {
    //注册回传通道对象
    self.receiveMsgCommand = command;
}

//从js调用过来，发送消息聊天 command中带了需要发送的content
- (void)sendMessageForAll:(CDVInvokedUrlCommand *)command {
    
    CDVPluginResult * result = nil;
    //从js传过来的content
    NSString *content = [command argumentAtIndex:0];
    //判断一下，如果没有传发送内容，则回调“发送失败”
    if(content != nil && [content length] > 0) {
        //这是gensee sdk中的类，专门用于发送消息内容封装
        GSPChatMessage * gspMessage = [GSPChatMessage new];
        gspMessage.text = content;
        gspMessage.msgID = [[NSUUID UUID] UUIDString];
        gspMessage.senderName = self.playerManager.selfUserInfo.userName;
        gspMessage.senderUserID = self.playerManager.selfUserInfo.userID;
        gspMessage.chatType = GSPChatTypePublic;
        gspMessage.receiveTime = [[NSDate date] timeIntervalSince1970];
        //发送消息， chatWithAll是展示互动的api
        BOOL sendSuc = [_playerManager chatWithAll:gspMessage];
        //发送聊天成功后回传给js的字典
        NSMutableDictionary * dict = [[NSMutableDictionary alloc] initWithDictionary: @{@"senderName":gspMessage.senderName ? gspMessage.senderName : @"",
            @"content":gspMessage.text ? gspMessage.text : @"",
            @"senderUserID":[NSString stringWithFormat:@"%lld",gspMessage.senderUserID],
            @"sendTime":[NSNumber numberWithDouble:gspMessage.receiveTime]}];
        
        //把数据封装成固定的格式 key：code， value：3 用来js收到回传的数据后，标示这个回传的信息为聊天消息
        NSDictionary * jsonResult = @{CODE:CHAT,DATA:dict};
        
        if(sendSuc) {
            [dict setObject:@"1" forKey:@"sendSuc"];
            //回传的数据以jsong格式回传  [jsonResult JSONString]
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[jsonResult JSONString]];
        } else {
            //如果发送失败，则回传发送失败
            jsonResult = @{CODE:ERROR,DATA:@"发送失败"};
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[jsonResult JSONString]];
        }
    } else {
        //如果js没有把要发送的content传过来，则回传“参数错误”
        NSDictionary *json = @{CODE:ERROR,DATA:PARAMS_ERR};
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
    }
    //所有的回传数据都准备好后，调用这个方法开始回传给js
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

//从js调用过来，发送问答内容 command中带了需要发送的content
- (void)sendQA:(CDVInvokedUrlCommand *)command {
    CDVPluginResult * result = nil;
    
    NSString *content = [command argumentAtIndex:0];
    
    if(content != nil && [content length] > 0) {
        
        GSPQaData *message = [GSPQaData new];
        message.content = content;
        message.ownnerID = self.playerManager.selfUserInfo.userID;
        message.ownerName = self.playerManager.selfUserInfo.userName;
        message.time = [[NSDate date] timeIntervalSince1970];
        message.isQuestion = YES;
        message.questionID = [[NSUUID UUID] UUIDString] ;
        if([self.playerManager askQuestion:message.questionID content:content]) {
            NSDictionary * dict = @{@"ownerName":message.ownerName ? message.ownerName : @"",
                                    @"qContent":message.content ? message.content : @"",
                                    @"time":[NSNumber numberWithLong:message.time],
                                             @"isQuestion":@"1",@"isCanceled":@"0",
                                    @"questionId":message.questionID,@"sendSuc":@"1"};
            NSDictionary * jsonResult = @{CODE:QA,DATA:@{QUESTION:dict}};
            
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[jsonResult JSONString]];
        } else {
            NSDictionary *json = @{CODE:ERROR,DATA:@"发送失败"};
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
        }
    
    } else {
        NSDictionary *json = @{CODE:ERROR,DATA:PARAMS_ERR};
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[json JSONString]];
    }
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

//js方注册了进入app后台的监听，如果手机从前台进入后台，会从js调用到这个方法，在原生将直播的声音关掉
- (void)disableGensee:(CDVInvokedUrlCommand *)command {
//    [self.playerManager enableAudio:NO];
    
}

//js方注册了进入app前台的监听，如果手机从后台进入前台，会从js调用到这个方法，在原生将直播的声音开启
- (void)enableGensee:(CDVInvokedUrlCommand *)command {
//    [self.playerManager enableAudio:YES];
}

//js点分享时，会注册一个回传通道
- (void)shareAction:(CDVInvokedUrlCommand *)command {
    self.shareCommand = command;
}

//收藏回调
- (void)collectionAction:(CDVInvokedUrlCommand *)command {
    
    self.collectCommand = command;
}

//返回上一页回调
- (void)backwardAction:(CDVInvokedUrlCommand *)command {
//    [self.cdvResult setKeepCallbackAsBool:YES];
    self.backCommand = command;
    NSString *arg1 = [command argumentAtIndex:0];
    if ([arg1 isEqualToString:@"leave"]) {
        [self leave];
    }
}

//点击js中的聊天按钮时，注册一下native回传js聊天内容的通道
- (void)receivceQA:(CDVInvokedUrlCommand *)command {
    self.receiveQACommand = command;
}

//举手监听
-(void)listenHandup:(CDVInvokedUrlCommand *)command {
    self.handupCommand = command;
}

-(void)collectToast:(CDVInvokedUrlCommand *)commnad {
    NSString *msg = [commnad argumentAtIndex:0];
    if (self.isDocView || self.isFullScreen) {
        [self showToast:msg duration:2.f];
    }
}

//点了收藏功能，回调js的收藏方法
- (void)collect:(UIButton *)sender {
    
    self.hasCollcted = !self.hasCollcted;
    NSString * imageName = self.hasCollcted ? @"collect_icon_pre" : @"collect_icon_nor";
    [sender setBackgroundImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    
    CDVPluginResult * result = nil;
    NSDictionary * dict = @{CODE:COLLECT};
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[dict JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.collectCommand.callbackId];
    }];
}

//点了分享功能，回调js的分享方法
- (void)share {

    if (self.isFullScreen) {
        [self fullScreen:self.fullScreenBtn];
    }
    CDVPluginResult * result = nil;
    NSDictionary * dict = @{CODE:SHARE};
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[dict JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.shareCommand.callbackId];
    }];
}

//离开直播
- (void)leave {
    [self.videoContainer setFrame:CGRectZero];
    [self.videoContainer removeFromSuperview];
    [self.docContainer setFrame:CGRectZero];
    [self.docContainer removeFromSuperview];
    [self.playerManager.docView clearPageAndAnno];
    [self.playerManager leave];
    [self.playerManager invalidate];
    self.playerManager = nil;
}

//点了返回上一页按钮，回调js的返回方法
- (void)back {
    
    if (self.isFullScreen) {
        [self fullScreen:self.fullScreenBtn];
        return;
    }
    [self leave];
    
    CDVPluginResult * result = nil;
    NSDictionary * dict = @{CODE:BACK};
    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[dict JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.backCommand.callbackId];
    }];
}

- (void)handup:(UIButton *)sender {
    NSDictionary * dict = @{};
    dict = @{CODE:BLUR,DATA:@"收键盘"};
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[dict JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.handupCommand.callbackId];
    }];
    self.isHandup = !self.isHandup;
    NSString *imageName = @"";
    NSString *msg = @"";
    BOOL isSuccess = [self.playerManager handup:self.isHandup];

    if (self.isHandup == YES && isSuccess){
        imageName = @"handup_pre";
        msg = @"举手成功";
//        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[dict JSONString]];
//        [result setKeepCallbackAsBool:YES];
//        __weak __typeof(self) weakSelf = self;
        
//        [self.commandDelegate runInBackground:^{
//            [weakSelf.commandDelegate sendPluginResult:result callbackId:self.handupCommand.callbackId];
//        }];
    } else {
        imageName = @"handup";
        if (!isSuccess) {
//            dict = @{CODE:HANDUP,DATA:@"举手失败"};
//            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[dict JSONString]];
//            [result setKeepCallbackAsBool:YES];
//            __weak __typeof(self) weakSelf = self;
//            [self.commandDelegate runInBackground:^{
//                [weakSelf.commandDelegate sendPluginResult:result callbackId:self.handupCommand.callbackId];
//            }];
        } else {
            msg = @"取消举手成功";
        }
    }
    [self showToast:msg duration:2.f];
    [sender setBackgroundImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
    
}

-(void)toggleDocView:(CDVInvokedUrlCommand *)command {
    NSNumber *flag = [command argumentAtIndex:0];
    NSLog(@"%d",[flag boolValue]);
    self.isDocView = [flag boolValue];
    if (self.isDocView) {
        if (self.hasDoc) {
            self.docContainer.hidden = NO;
        } else {
            self.docContainer.hidden = YES;
        }
    } else {
        self.docContainer.hidden = YES;
    }
}

- (void)closeVideo {
    if (self.hasVideo) {
        self.isCloseVideo = !self.isCloseVideo;
        self.hiddenView.hidden = !self.isCloseVideo;
    }
}
- (void)fullScreen:(UIButton *)sender {
    NSDictionary * dict = @{};
    dict = @{CODE:BLUR,DATA:@"收键盘"};
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[dict JSONString]];
    [result setKeepCallbackAsBool:YES];
    __weak __typeof(self) weakSelf = self;
    [self.commandDelegate runInBackground:^{
        [weakSelf.commandDelegate sendPluginResult:result callbackId:self.handupCommand.callbackId];
    }];
    //强制旋转
    if (!self.isFullScreen) {
        [UIView animateWithDuration:0.1 animations:^{
            self.viewController.view.transform = CGAffineTransformMakeRotation(M_PI/2);
            self.viewController.view.bounds = CGRectMake(0, 0, ScreenHeight, ScreenWidth);
            self.videoContainer.bounds = CGRectMake(0, 0, ScreenHeight, ScreenWidth);
            self.videoContainer.center = CGPointMake(ScreenHeight/2.f, ScreenWidth/2.f);
            self.hiddenView.frame = self.videoContainer.frame;
            self.hiddenView.center = self.videoContainer.center;
            self.playerManager.videoView.frame = self.videoContainer.frame;
            self.playerManager.videoView.center = self.videoContainer.center;
            self.shareBtn.frame = CGRectMake(ScreenHeight - 10 - iconWidth, 10, iconWidth, iconWidth);
            self.shareBtn.hidden = YES;
            self.collectBtn.frame = CGRectMake(CGRectGetMinX(self.shareBtn.frame) - 10 - iconWidth, 10, iconWidth, iconWidth);
            self.toolBar.frame = CGRectMake(0, 0, ScreenHeight, BarWidth);
            self.collectBtn.hidden = YES;
            self.functionBar.frame = CGRectMake(ScreenHeight-BarWidth, (10+BarWidth), BarWidth, ScreenWidth-(10+BarWidth));
            self.isFullScreen = YES;
            self.toolBar.hidden = NO;
            self.docContainer.hidden = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
        }];
    } else {
        [UIView animateWithDuration:0.1 animations:^{
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
            self.viewController.view.bounds = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
            CGRect frame = _videoRect;
            frame = CGRectMake(frame.origin.x, 0, frame.size.width, frame.size.height);
            self.videoContainer.frame = _videoRect;
            self.playerManager.videoView.frame = frame;
            self.hiddenView.frame = frame;
            self.toolBar.frame = CGRectMake(0, 0, ScreenWidth, BarWidth);
            self.shareBtn.frame = CGRectMake(ScreenWidth - 10 - iconWidth, 10, iconWidth, iconWidth);
            self.collectBtn.frame = CGRectMake(CGRectGetMinX(self.shareBtn.frame) - 10 - iconWidth, 10, iconWidth, iconWidth);
            self.shareBtn.hidden = NO;
            self.collectBtn.hidden = NO;
            self.functionBar.frame = CGRectMake(ScreenWidth-BarWidth, (10+BarWidth), BarWidth, ScreenHeight-(10+BarWidth));
            self.isFullScreen = NO;
            self.toolBar.hidden = YES;
            self.viewController.view.transform = CGAffineTransformIdentity;
        }];
    }
    NSString *image = self.isFullScreen ? @"zoom_screen" : @"full_screen";
    [sender setBackgroundImage:[UIImage imageNamed:image] forState:UIControlStateNormal];
}
- (void)showToast:(NSString *)msg duration:(NSTimeInterval)duration {
    [self.viewController.view hideToasts];
    CSToastStyle *style = [CSToastManager sharedStyle];
    style.cornerRadius = 5.f;
    style.messageFont = [UIFont systemFontOfSize:14];
    style.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.65];
    CGFloat width = self.viewController.view.bounds.size.width;
    CGFloat height = self.viewController.view.bounds.size.height;
    if (width>height) {
        [self.viewController.view makeToast:msg duration:duration position:[NSValue valueWithCGPoint:CGPointMake(ScreenHeight/2.f, ScreenWidth-70)] style:style];
    } else {
        [self.viewController.view makeToast:msg duration:duration position:[NSValue valueWithCGPoint:CGPointMake(ScreenWidth/2.f, ScreenHeight-70)] style:style];
    }
}

-(void)orientation:(CDVInvokedUrlCommand *)command {
    BOOL isLandscape = [[command argumentAtIndex:0] boolValue];
    NSNumber *landscapeFlag = [command argumentAtIndex:1] ? [command argumentAtIndex:1] : @1;
    if (isLandscape) {
        if ([landscapeFlag isEqual: @2]) {
            [UIView animateWithDuration:0.1 animations:^{
                self.viewController.view.transform = CGAffineTransformMakeRotation(-M_PI/2);
                self.viewController.view.bounds = CGRectMake(0, 0, ScreenHeight, ScreenWidth);
            }];
        } else {
            [UIView animateWithDuration:0.1 animations:^{
                self.viewController.view.transform = CGAffineTransformMakeRotation(M_PI/2);
                self.viewController.view.bounds = CGRectMake(0, 0, ScreenHeight, ScreenWidth);
            }];
        }
    } else {
        [UIView animateWithDuration:0.1 animations:^{
            self.viewController.view.bounds = CGRectMake(0, 0, ScreenWidth, ScreenHeight);
            self.viewController.view.transform = CGAffineTransformIdentity;
        }];
    }
}
@end
