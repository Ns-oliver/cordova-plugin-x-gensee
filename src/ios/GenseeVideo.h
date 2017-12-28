//
//  GenseeVideo.h
//  手机学堂
//
//  Created by Wilson on 2017/8/24.
//
//

#import <Cordova/CDV.h>

@interface GenseeVideo : CDVPlugin

//开启直播
- (void)openGensee:(CDVInvokedUrlCommand *)command;

//发送消息
- (void)sendMessageForAll:(CDVInvokedUrlCommand *)command;

//发送问题
- (void)sendQA:(CDVInvokedUrlCommand *)command;

//收到公共聊天消息
- (void)receivceMessage:(CDVInvokedUrlCommand *)command;

//收到问答题内容
- (void)receivceQA:(CDVInvokedUrlCommand *)command;

//监听举手回调
- (void)listenHandup:(CDVInvokedUrlCommand *)command;

//分享回调
- (void)shareAction:(CDVInvokedUrlCommand *)command;

//收藏回调
- (void)collectionAction:(CDVInvokedUrlCommand *)command;

//收藏toast
- (void)collectToast:(CDVInvokedUrlCommand *)commnad;

//返回上一页回调
- (void)backwardAction:(CDVInvokedUrlCommand *)command;

//关闭音视频
- (void)disableGensee:(CDVInvokedUrlCommand *)command;

//开启视频
- (void)enableGensee:(CDVInvokedUrlCommand *)command;

//切换文档视图
- (void)toggleDocView:(CDVInvokedUrlCommand *)command;

//切换横竖屏
- (void)orientation:(CDVInvokedUrlCommand *)command;
@end
