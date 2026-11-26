#import <UIKit/UIKit.h>
#import <substrate.h>

// ============ 配置 ============
// KAlert 防撤回记录的 UserDefaults key（必须与 KAlert 一致）
static NSString *const kRecalledKey = @"SGAntiRecallMessageIds";
// 标记视图的 tag（用于查找/移除旧标记）
static const NSInteger kMarkTag = 0x53475243; // 'SGRC'
// 调试日志开关：真机调试时改成 YES，会在控制台打印消息 ID 提取情况
static const BOOL kDebugLog = YES;

// 候选消息节点类名（按优先级，运行时逐个尝试）
// Swift 类在 ObjC runtime 注册的是 mangled 名 _TtC<模块长度><模块><类名长度><类名>
static NSArray<NSString *> *sg_candidateClasses(void) {
    return @[
        @"_TtC25ChatMessageBubbleItemNode25ChatMessageBubbleItemNode",
        @"_TtC28ChatMessageBubbleContentNode28ChatMessageBubbleContentNode",
        @"_TtC19ChatMessageItemView19ChatMessageItemView",
        @"ChatMessageBubbleItemNode",
        @"ChatMessageBubbleContentNode",
    ];
}

// ============ 撤回状态判断 ============
static BOOL sg_isRecalled(id msgIdValue) {
    if (!msgIdValue) return NO;
    NSArray *recalled = [[NSUserDefaults standardUserDefaults] objectForKey:kRecalledKey];
    if (![recalled isKindOfClass:[NSArray class]]) return NO;
    for (id obj in recalled) {
        if ([obj isKindOfClass:[NSNumber class]]) {
            if ([obj isEqualToNumber:(NSNumber *)msgIdValue]) return YES;
        } else if ([obj isKindOfClass:[NSString class]]) {
            if ([obj isEqualToString:[msgIdValue description]]) return YES;
        }
    }
    return NO;
}

// ============ 从消息节点提取消息 ID ============
// 这里是真机调试重点：Swift 属性是否 @objc 暴露决定哪条路径能取到 ID
// Swiftgram 消息对象的标准属性名是 messageId（readonly int，ivar _messageId）
static NSNumber *sg_extractMessageId(id node) {
    if (!node) return nil;
    NSArray<NSString *> *paths = @[
        @"messageId",
        @"message.messageId",
        @"item.message.messageId",
        @"item.message.id",
        @"message.id",
        @"item.messageId",
        @"item.id",
    ];
    for (NSString *p in paths) {
        @try {
            id v = [node valueForKeyPath:p];
            if (v) {
                if (kDebugLog) NSLog(@"[SGRecallMark] path '%@' -> %@ (%@)", p, v, [v class]);
                if ([v isKindOfClass:[NSNumber class]]) return (NSNumber *)v;
                if ([v respondsToSelector:@selector(integerValue)]) {
                    return @([v integerValue]);
                }
            }
        } @catch (NSException *e) {
            if (kDebugLog) NSLog(@"[SGRecallMark] path '%@' FAILED: %@", p, e.name);
        }
    }
    return nil;
}

// ============ 标记视图 ============
static void sg_removeMark(UIView *view) {
    for (UIView *sub in view.subviews) {
        if (sub.tag == kMarkTag) {
            [sub removeFromSuperview];
        }
    }
}

static void sg_addMark(UIView *view) {
    sg_removeMark(view);
    UILabel *mark = [[UILabel alloc] init];
    mark.tag = kMarkTag;
    mark.text = @"已撤回";
    mark.font = [UIFont boldSystemFontOfSize:11];
    mark.textColor = [UIColor systemOrangeColor];
    mark.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.85];
    mark.layer.cornerRadius = 4;
    mark.layer.masksToBounds = YES;
    mark.textAlignment = NSTextAlignmentCenter;
    [view addSubview:mark];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    [mark.topAnchor constraintEqualToAnchor:view.topAnchor constant:2].active = YES;
    [mark.rightAnchor constraintEqualToAnchor:view.rightAnchor constant:-2].active = YES;
}

// ============ Hook 实现 ============
static void (*orig_layoutSubviews)(id self, SEL _cmd) = NULL;

static void hooked_layoutSubviews(id self, SEL _cmd) {
    orig_layoutSubviews(self, _cmd);
    NSNumber *msgId = sg_extractMessageId(self);
    if (kDebugLog) {
        NSLog(@"[SGRecallMark] node=%@ msgId=%@", [self class], msgId);
    }
    if (msgId && sg_isRecalled(msgId)) {
        sg_addMark(self);
    }
}

%ctor {
    @autoreleasepool {
        for (NSString *cn in sg_candidateClasses()) {
            Class cls = NSClassFromString(cn);
            if (!cls) cls = objc_getClass(cn.UTF8String);
            if (cls) {
                if (kDebugLog) {
                    NSLog(@"[SGRecallMark] hooking %@", cls);
                }
                MSHookMessageEx(cls, @selector(layoutSubviews),
                                (IMP)hooked_layoutSubviews, (IMP *)&orig_layoutSubviews);
                break;
            }
        }
    }
}
