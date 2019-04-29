//
//  AmbaMachine.m
//  CameraModuleTest
//
//  Created by 刘玲 on 2019/4/29.
//  Copyright © 2019年 BFs. All rights reserved.
//

#import "AmbaMachine.h"

NSString  *tokenKey     = @"token";
NSString  *msgIdKey     = @"msg_id";
NSString  *typeKey      = @"type";
NSString  *offsetKey    = @"offset";
NSString  *featchSizeKey = @"fetch_size";
NSString *optionsKey    = @"options";
//Return keys
NSString *rvalKey = @"rval";
NSString *permissionKey = @"permission";
NSString *pwdKey = @"pwd";

//BiDirectional Key
NSString *paramKey = @"param";

//CommandStrings
NSString *startSessionCmd   = @"StartSession";
NSString *stopSessionCmd    = @"StopSession";
NSString *recordStartCmd    = @"RecStart";
NSString *recordStopCmd     = @"RecStop";
NSString *shutterCmd        = @"Shutter";
NSString *deviceInfoCmd     = @"deviceInfoCmd";
NSString *batteryLevelCmd   = @"batteryLevelCmd";
NSString *stopContPhotoSessionCmd = @"stopContPhotoSessionCmd";
NSString *recordingTimeCmd  = @"RecordingTime";
NSString *splitRecordingCmd = @"RecordingSplit";
NSString *stopVFCmd         = @"StopVF";
NSString *resetVFCmd        = @"ResetVF";
NSString *zoomInfoCmd       = @"zoomInfo";
NSString *setBitRateCmd     = @"BitRate";
NSString *startEncoderCmd   = @"StartEncoder";
NSString *changeSettingCmd  = @"ChangeSetting";
NSString *appStatusCmd      = @"uItronStat";
NSString *storageSpaceCmd   = @"storageSpace";
NSString *presentWorkingDirCmd = @"pwd";
NSString *listAllFilesCmd   = @"listAllFiles";
NSString *numberOfFilesInFolderCmd = @"numberOfFilesInFolderCmd";
NSString *changeToFolderCmd = @"changeFolder";
NSString *mediaInfoCmd      = @"mediaInfo";
NSString *getFileCmd        = @"getFile";
NSString *putFileCmd        = @"putFile";
NSString *stopGetFileCmd    = @"stopGetFile";
NSString *removeFileCmd     = @"removeFile";
NSString *fileAttributeCmd  = @"fileAttributeCmd";
NSString *formatSDMediaCmd  = @"formatSDMediaCmd";
NSString *allSettingsCmd    = @"allSettings";
NSString *getSettingValueCmd = @"getSettingValue";
NSString *getOptionsForValueCmd = @"getOptionsForValue";
NSString *setCameraParameterCmd = @"setCameraParamValue";
NSString *sendCustomJSONCmd = @"sendCustomJSONCmd";
NSString *setClientInfoCmd  = @"setClientInfoCmd";
NSString *getWifiSettingsCmd = @"getWifiSettingsCmd";
NSString *setWifiSettingsCmd = @"setWifiSettingsCmd";
NSString *getWifiStatusCmd   = @"getWifiStatusCmd";
NSString *stopWifiCmd        = @"stopWifiCmd";
NSString *startWifiCmd       = @"startWifiCmd";
NSString *reStartWifiCmd     = @"reStartWifiCmd";
NSString *querySessionCmd    = @"querySessionCmd";
NSString *AMBALOGFILE    = @"AmbaRemoteCam.txt";


//command code thats msg_id number as per amba document
const unsigned int appStatusMsgId       = 1;
const unsigned int getSettingValueMsgId = 1;
const unsigned int setCameraParameterMsgId = 2;
const unsigned int allSettingsMsgId     = 3;
const unsigned int formatSDMediaMsgId   = 4;
const unsigned int storageSpaceMsgId    = 5;
const unsigned int numberOfFilesInFolderId = 6;
const unsigned int notificationMsgId    = 7;
const unsigned int getOptionsForValueMsgId = 9;
const unsigned int deviceInfoMsgId      = 11;
const unsigned int batteryLevelMsgId    = 13;
const unsigned int zoomInfoMsgId        = 15;
const unsigned int setBitRateMsgId      = 16;


const unsigned int startSessionMsgId    = 257;
const unsigned int stopSessionMsgId     = 258;
const unsigned int resetVFMsgId         = 259;
const unsigned int stopVFMsgId          = 260;
const unsigned int setClientInfoMsgId   = 261;


const unsigned int recordStartMsgId     = 513;
const unsigned int recordStopMsgId      = 514;
const unsigned int recordingTimeMsgId   = 515;
const unsigned int splitRecordingMsgId  = 516;

const unsigned int shutterMsgId         = 769;
const unsigned int stopContPhotoSessionMsgId = 770;
const unsigned int mediaInfoMsgId       = 1026;
const unsigned int fileAttributeMsgId   = 1027;

const unsigned int removeFileMsgId      = 1281;
const unsigned int listAllFilesMsgId    = 1282;
const unsigned int changeToFolderMsgId  = 1283;
const unsigned int presentWorkingDirMsgId = 1284;
const unsigned int getFileMsgId         = 1285;
const unsigned int putFileMsgId         = 1286;
const unsigned int stopGetFileMsgId     = 1287;

const unsigned int reStartWifiMsgId     = 1537;
const unsigned int setWifiSettingsMsgId = 1538;
const unsigned int getWifiSettingsMsgId = 1539;
const unsigned int stopWifiMsgId        = 1540;
const unsigned int startWifiMsgId       = 1541;
const unsigned int getWifiStatusMsgId   = 1542;
const unsigned int querySessionHolderMsgId = 1793;

const unsigned int sendCustomJSONMsgID = 99999999; //Select some random number for custom cmd.
//
unsigned int STATUS_FLAG;
unsigned int recvResponse;

#define kAsyncTask(queue, block) dispatch_async(queue, block)

@interface AmbaMachine () <NSStreamDelegate> {
    int _sessionToken;
    
    NSString *_typeObject;
    NSString *_paramObject;
    NSInteger _offsetObject;
    NSInteger _sizeToDlObject;
    NSString  *_md5SumObject;
    NSInteger _fileAttributeValue;
    NSMutableString *tmpString;
    
    int     _curOperationCount; // 同步队列专用参数
}
@property (nonatomic, strong) NSString *tmpMsgStr;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;

@property (nonatomic, strong) __block AmbaCommand *curCommand;
// GCD
@property (nonatomic, strong) dispatch_queue_t concurrentQueue;
// NSArray
@property (nonatomic, strong) NSLock *lockOfNetwork;
@property (nonatomic, assign) BOOL isExecutingNetworkOrder;
@property (nonatomic, strong) NSMutableArray *ordersOfConcurrent;
@property (nonatomic, assign) NSUInteger maxConcurrentOperationCount;

@end

@implementation AmbaMachine

static AmbaMachine *machine;
static dispatch_once_t onceToken;

- (NSMutableArray *)ordersOfConcurrent {
    if (!_ordersOfConcurrent) {
        _ordersOfConcurrent = [NSMutableArray array];
    }
    
    return _ordersOfConcurrent;
}

#pragma mark - API

+ (instancetype)sharedMachine {
    
    dispatch_once(&onceToken, ^{
        machine = [[AmbaMachine alloc] init];
        if (machine) {
            [machine configDefaultSetting];
        }
    });
    
    return machine;
}

- (void)destoryMachine {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (onceToken) {
        machine = nil;
        onceToken = 0;
    }
}

- (void)initNetworkCommunication:(NSString *)ipAddress tcpPort:(NSInteger)tcpPortNo {
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ipAddress, (unsigned int)tcpPortNo, &readStream, &writeStream);
    self.inputStream = (__bridge NSInputStream *)readStream;
    self.outputStream = (__bridge  NSOutputStream *)writeStream;
    [self.inputStream setDelegate:self];
    [self.outputStream setDelegate:self];
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.inputStream open];
    [self.outputStream open];
    
    self.isConnected = NO;
    _sessionToken = 0;
}

- (void)disconnectFromMachine {
    
    if (self.outputStream) {
        [self.outputStream close];
    }
    if (self.inputStream) {
        [self.inputStream close];
    }
}

- (void)startSession:(ReturnBlock)block {
    
    AmbaCommand *command = [AmbaCommand command];
    command.curCommand = startSessionCmd;
    command.messageId = startSessionMsgId;
    command.taskBlock = ^{
        id commandData = [self configCommandData:startSessionMsgId];
        [self writeDataToCamera:commandData andError:nil];
    };
    command.returnBlock = block;
    
//    self.curCommand = command;
//    command.taskBlock();
    [self addOrder:command];
}

- (void)stopSession:(ReturnBlock)block {
    
    AmbaCommand *command = [AmbaCommand command];
    command.curCommand = stopSessionCmd;
    int curMessageId = stopSessionMsgId;
    command.messageId = curMessageId;
    command.taskBlock = ^{
        
        id commandData = [self configCommandData:curMessageId];
        [self writeDataToCamera:commandData andError:nil];
    };
    command.returnBlock = block;
    
//    self.curCommand = command;
//    command.taskBlock();
    [self addOrder:command];
}

- (id)configCommandData:(unsigned int)commandCode {
    
    NSDictionary *commandDict;
    
    if ( commandCode == 1 ||
        commandCode == 5 ||
        commandCode == 6 ||
        commandCode == 15
        ) { //commands with "type" only
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _typeObject, typeKey,
                       nil];
        
    } else if (commandCode == 1538 ||
               commandCode == 1283 ||
               commandCode == 1026 ||
               commandCode == 1287 ||
               commandCode == 1281 ||
               commandCode == 16   ||
               commandCode == 9    ||
               commandCode == 4 )   { //commands with "param" only
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _paramObject, paramKey,
                       nil];
    } else if (commandCode == 1285 ) {//special cases
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _paramObject, paramKey,
                       [NSNumber numberWithUnsignedInteger: _offsetObject], offsetKey,
                       [NSNumber numberWithUnsignedInteger:  _sizeToDlObject ], featchSizeKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       nil];
    }else if (commandCode ==1286) //special case
    {
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _paramObject, paramKey,
                       [NSNumber numberWithUnsignedInteger: _offsetObject], offsetKey,
                       [NSNumber numberWithUnsignedInteger:  _sizeToDlObject ], @"size",
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _md5SumObject, @"md5sum",
                       nil];
    } else if (commandCode == 1793) //special case SessionHolder
    {
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       nil];
        
    }else if (commandCode == 2 ||
              commandCode == 261)
    {
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _paramObject, paramKey,
                       _typeObject, typeKey,
                       nil];
    } else if ( commandCode == 1027)
    {
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       _paramObject, paramKey,
                       [NSNumber numberWithUnsignedInteger:_fileAttributeValue], typeKey,
                       nil];
    }
    else {
        commandDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @(_sessionToken), tokenKey,
                       [NSNumber numberWithUnsignedInteger:commandCode], msgIdKey,
                       nil];
    }
    
    return commandDict;
}

- (NSInteger)writeDataToCamera:(id)obj andError:(NSError * _Nullable __autoreleasing *)error {
    
    if (_isConnected) {
        return [NSJSONSerialization writeJSONObject:obj toStream:self.outputStream options:kNilOptions error:error];
    } else {
        if (error) {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:101 userInfo:@{NSLocalizedDescriptionKey:@"camera is no connect"}];
        }
        return 0;
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    NSLog(@"[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
        {
            NSLog(@"连接成功：%@", NSStringFromClass([aStream class]));
            [self updateConnectionStatus:YES forStream:aStream];
        }
            break;
        case NSStreamEventHasBytesAvailable:
        {
            NSLog(@"接收到上报数据");
            if (aStream == self.inputStream) {
                uint8_t buffer[1024];
                NSInteger len;
                while ([self.inputStream hasBytesAvailable]) {
                    len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        
                        NSString *responseString = [[NSString alloc] initWithBytes:buffer
                                                                            length:len
                                                                          encoding:NSASCIIStringEncoding];
                        
                        //------handle Packet Framented return from camera
                        //TODO: Implement timeout if the string does'nt make it to App
                        NSData *data = [responseString dataUsingEncoding:NSUTF8StringEncoding];
                        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                                     options:kNilOptions
                                                                                       error:nil];
                        //Store the value in a global and append data string in next call check before we call messageReceived
                        if (!jsonResponse) {
                            [tmpString appendString:responseString];
                            
                            NSLog(@"Appending pkt Fragmented Data-> %@",tmpString);                            
                            
                            data = [tmpString dataUsingEncoding:NSUTF8StringEncoding];
                            if (data) {
                                jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                               options:kNilOptions
                                                                                 error:nil];
                            }
                            if (jsonResponse){
                                [self messageReceived:tmpString];
                                //reset the tmpString to nothing
                                tmpString = [NSMutableString stringWithFormat:@""];
//                                recvResponse = 1;
//                                if (jsonTimer)
//                                    [jsonTimer invalidate];
                            }
                        } else {
//                            recvResponse = 1;
//                            if (jsonTimer)
//                                [jsonTimer invalidate];
                            
                            [self messageReceived:responseString];
                        }
                    }
                }
            }
        }
            break;
        case NSStreamEventErrorOccurred:
        {
            NSLog(@"连接出现错误");
            [self updateConnectionStatus:NO forStream:aStream];
        }
            break;
        case NSStreamEventEndEncountered:
        {
            NSLog(@"连接结束");
            [self updateConnectionStatus:NO forStream:aStream];
            
            [aStream close];
            [aStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            aStream = nil;
        }
            break;
            
        default:
            NSLog(@"Unknown Event: %lu", (unsigned long)eventCode);
            break;
    }
}

- (void)messageReceived:(id)result {
    
    NSDictionary *resultDict;
    if ([result isKindOfClass:[NSString class]]) {
        resultDict = [self convertStringToDictionary:result];
    } else {
        resultDict = (NSDictionary *)result;
    }
    
    [self handleDictResult:resultDict];
    
    [self.lockOfNetwork unlock];
}

- (void)handleDictResult:(NSDictionary *)resultDict {
    
    if ([[resultDict objectForKey:msgIdKey] isEqualToNumber:[NSNumber numberWithUnsignedInteger:notificationMsgId]]) {
        //......
    }
    else if (_curCommand.messageId == startSessionMsgId)
    {
        [self responseToStartSession:resultDict];
    }
    else if (_curCommand.messageId == stopSessionMsgId)
    {
        [self responseToStopSession:resultDict];
    }
}

#pragma mark - Handle Message

- (void)responseToStopSession:(NSDictionary *)responseDict {
    
    NSLog(@"Response to Stop Session received");
    NSLog(@":::: %@",responseDict);
    
    NSError *error;
    if ([[responseDict objectForKey:rvalKey] isEqualToNumber:[NSNumber numberWithUnsignedInteger:0]])
    {
        self.isConnected = NO;
        _sessionToken = 0;
        
        [self.inputStream close];
        [self.outputStream close];
    }
    else {
        NSLog(@"!!!!!!Unable to Disconnect!!!!!");
        error = [NSError errorWithDomain:NSURLErrorDomain code:101 userInfo:@{NSLocalizedDescriptionKey:@"camera unable to disconnect"}];
    }
    
    if (self.curCommand.returnBlock) {
        _curCommand.returnBlock(error, 0, nil, ResultTypeNone);
    }
}

- (void)responseToStartSession:(NSDictionary *)responseDict {
    
    NSLog(@"rval %@", (NSNumber *)[responseDict objectForKey:rvalKey]);
    if ([[responseDict objectForKey:rvalKey] isEqualToNumber:[NSNumber numberWithUnsignedInteger:0]])
    {
        _sessionToken = [[responseDict objectForKey:paramKey] intValue];
        NSLog(@"开启会话成功 》》》》");
        _curCommand.returnBlock(nil, 0, nil, ResultTypeNone);
    }
    // send an error message about camera refusing a lock
    else
    {
        NSLog(@"开启会话失败 》》》》Camera refuses to Start Session");
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:101 userInfo:@{NSLocalizedDescriptionKey:@"star session fail"}];
        _curCommand.returnBlock(error, 0, nil, ResultTypeNone);
    }
    NSLog(@"开启会话结果：%@", responseDict);
}

#pragma mark -

- (NSDictionary *)convertStringToDictionary:(NSString *)jsonInString
{
    
    jsonInString = [[jsonInString stringByReplacingOccurrencesOfString:@"{" withString:@""]
                    stringByReplacingOccurrencesOfString:@"}" withString:@""];
    
    
    NSMutableDictionary *convertedDictionary = [[NSMutableDictionary alloc] init];
    
    NSArray *keyValuePairArray = [jsonInString componentsSeparatedByString:@","];
    
    for(NSUInteger arrayInd = 0; arrayInd < MIN([keyValuePairArray count], 3); arrayInd++)
    {
        NSArray *singleKeyValuePair = [[keyValuePairArray objectAtIndex:arrayInd] componentsSeparatedByString:@":"];
        NSString *keyParam = [singleKeyValuePair objectAtIndex:0];
        keyParam = [keyParam stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        keyParam = [keyParam stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        
        NSString *valueParamString = [singleKeyValuePair objectAtIndex:1];
        NSNumber *valueParamNumber = [[NSNumber alloc] init];
        
        NSArray *tmpParamKeyParamArray = [[NSArray alloc] init];
        
        // if not "param:"
        if (![keyParam isEqualToString:paramKey])
        {
            valueParamNumber = [NSNumber numberWithInt:[valueParamString intValue]]; //  = [formatter numberFromString:valueParamString];
        }
        
        // if "param:"
        else
        {
            valueParamString = [[valueParamString stringByReplacingOccurrencesOfString:@"[" withString:@""]
                                stringByReplacingOccurrencesOfString:@"]" withString:@""];
            
            NSLog(@"Number of Chars %d", (unsigned int)valueParamString.length);
            
            tmpParamKeyParamArray = [valueParamString componentsSeparatedByString:@","];
            
            // See if single number
            if([tmpParamKeyParamArray count] == 1)
            {
                valueParamNumber = [NSNumber numberWithInt:[valueParamString intValue]];
            }
        }
        
        if (![keyParam isEqualToString:paramKey])
        {
            [convertedDictionary setObject:valueParamNumber forKey:keyParam];
        }
        // if "param:"
        else
        {
            // if just a number, then set to number
            if ([tmpParamKeyParamArray count] == 1)
            {
                [convertedDictionary setObject:valueParamNumber forKey:keyParam];
            }
            // else set it to string (AMBAXXX.jpg)
            else
            {
                [convertedDictionary setObject:valueParamString forKey:keyParam];
            }
        }
    } // for(NSUI...
    
    NSDictionary *returnDictionary = [convertedDictionary copy];
    
    // Print out for debugging
    
    NSEnumerator *enumerator = [returnDictionary keyEnumerator];
    NSString *key;
    while (key = [ enumerator nextObject])
    {
        NSLog(@"%@, %@", key, [returnDictionary objectForKey:key]);
    }
    
    return returnDictionary;
}
#pragma mark - Func

- (void)updateConnectionStatus:(BOOL)isConnected forStream:(NSStream *)pStream {
    
    self.isConnected = isConnected;
    if ([self.delegate respondsToSelector:@selector(ambaMachine:didUpdateConnectionStatus:forStream:)]) {
        [self.delegate ambaMachine:self didUpdateConnectionStatus:_isConnected forStream:pStream];
    }
}

- (BOOL)addOrder:(AmbaCommand *)order {

    kAsyncTask(self.concurrentQueue, ^{
        [self addNetworkOrder:order];
    });

    return true;
}

/**
 并发队列顺序执行order
 */
- (void)addNetworkOrder:(AmbaCommand *)order {
    NSLog(@"添加任务线程： %@", [NSThread currentThread]);
    [self.lockOfNetwork lock];
    [self.ordersOfConcurrent addObject:order];

    if (self.isExecutingNetworkOrder && (_curOperationCount >= self.maxConcurrentOperationCount)) {
        [self.lockOfNetwork unlock];
        return;
    }

    _curOperationCount++;
    while (self.ordersOfConcurrent.count > 0) {

        self.isExecutingNetworkOrder = YES;
        [self.lockOfNetwork unlock];

        AmbaCommand *executeOrder = [self searchOrderForHighterProperty:self.ordersOfConcurrent];
        [self synchronizeExecuteOrder:executeOrder];

        [self.lockOfNetwork lock];
        [self.ordersOfConcurrent removeObject:executeOrder];
    }
    self.isExecutingNetworkOrder = NO;
    _curOperationCount--;
    [self.lockOfNetwork unlock];
}
/**
 子类重写具体指令操作方法
 */

- (id)synchronizeExecuteOrder:(AmbaCommand *)order {

    /**
     增加具体的网络指令内容
     */
    [NSThread sleepForTimeInterval:0.5f];

    [self.lockOfNetwork lock];
    self.curCommand = order;
    order.taskBlock();

    return nil;
}

- (AmbaCommand *)searchOrderForHighterProperty:(NSArray *)orders {
    
    AmbaCommand *targetOrder = [orders firstObject];
    for (int i = 1; i < orders.count; i++) {
        AmbaCommand *tmpOrder = orders[i];
        if (targetOrder.orderPrority < tmpOrder.orderPrority) {
            targetOrder = tmpOrder;
        }
    }
    
    return targetOrder;
}

- (void)configDefaultSetting {
    
    _sessionToken = 0;
    self.tmpMsgStr = @"";
    
    // GCD
    NSString *queueName = @"bibi";
    self.concurrentQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
    self.maxConcurrentOperationCount = 1;
    _curOperationCount = 0;
}

@end
