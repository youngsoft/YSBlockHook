//
//  ViewController.m
//  YSBlockHook
//
//  Created by oubaiquan on 2019/3/29.
//  Copyright © 2019 Youngsoft. All rights reserved.
//

#import "ViewController.h"
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <Block.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "fishhook.h"


extern const struct mach_header* _NSGetMachExecuteHeader(void);

//这两个全局变量保存可执行程序的代码段+数据段的开始和结束位置。
unsigned long imageTextStart = 0;
unsigned long imageTextEnd = 0;
void initImageTextStartAndEndPos()
{
    imageTextStart = (unsigned long)_NSGetMachExecuteHeader();
#ifdef __LP64__
    const struct segment_command_64 *psegment = getsegbyname("__TEXT");
#else
    const struct segment_command *psegment = getsegbyname("__TEXT");
#endif
    //imageTextEnd  等于代码段和数据段的结尾 + 对应的slide值。
    imageTextEnd = get_end() + imageTextStart - psegment->vmaddr;
}


struct Block_descriptor {
    void *reserved;
    uintptr_t size;
};

struct Block_layout {
    void *isa;
    int32_t flags; // contains ref count
    int32_t reserved;
    void  *invoke;
    struct Block_descriptor *descriptor;
};


//声明统一的block的hook函数，这个函数的定义是用汇编代码来实现，具体实现在blockhook-arm64.s/blockhook-x86_64.s中。
extern void blockhook(void);
extern void blockhook_stret(void);



/**
 替换block对象的默认invoke实现

 @param blockObj block对象
 */
void replaceBlockInvokeFunction(const void *blockObj)
{
    //任何一个block对象都可以转化为一个struct Block_layout结构体。
    struct Block_layout *layout = (struct Block_layout*)blockObj;
    if (layout != NULL && layout->descriptor != NULL)
    {
        //这里只hook一个可执行程序image范围内定义的block代码块。
        //因为imageTextStart和imageTextEnd表示可执行程序的代码范围，因此如果某个block是在可执行程序中被定义
        //那么其invoke函数地址就一定是在(imageTextStart,imageTextEnd)范围内。
        //如果将这个条件语句去除就会hook进程中所有的block对象！
        unsigned long invokePos = (unsigned long)layout->invoke;
        if (invokePos > imageTextStart && invokePos < imageTextEnd)
        {
            //将默认的invoke实现保存到保留字段，将统一的hook函数赋值给invoke成员。
            int32_t BLOCK_USE_STRET = (1 << 29);  //如果模拟器下返回的类型是一个大于16字节的结构体，那么block的第一个参数为返回的指针，而不是block对象。
            void *hookfunc = ((layout->flags & BLOCK_USE_STRET) == BLOCK_USE_STRET) ? blockhook_stret : blockhook;
            if (layout->invoke != hookfunc)
            {
                layout->descriptor->reserved = layout->invoke;
                layout->invoke = hookfunc;
            }
        }
    }
    
}



//分别保存和定义__NSStackBlock__、__NSMallocBlock__、__NSGlobalBlock__的默认的retain实现和定义新的retain实现
//在新的实现内部完成block对象的invoke函数的替换处理。
void *(*__NSStackBlock_retain_old)(void *obj, SEL cmd) = NULL;
void *__NSStackBlock_retain_new(void *obj, SEL cmd)
{
    replaceBlockInvokeFunction(obj);
    return __NSStackBlock_retain_old(obj, cmd);
}

void *(*__NSMallocBlock_retain_old)(void *obj, SEL cmd) = NULL;
void *__NSMallocBlock_retain_new(void *obj, SEL cmd)
{
    replaceBlockInvokeFunction(obj);
    return __NSMallocBlock_retain_old(obj, cmd);
}


void *(*__NSGlobalBlock_retain_old)(void *obj, SEL cmd) = NULL;
void *__NSGlobalBlock_retain_new(void *obj, SEL cmd)
{
    replaceBlockInvokeFunction(obj);
    return __NSGlobalBlock_retain_old(obj, cmd);
}

//对C语言中的__Block_copy函数和objc_retainBlock实现替换处理，这里分别保存老的实现和新的实现。
void* (*_Block_copy_old)(const void *aBlock);
void *_Block_copy_new(const void *aBlock)
{
    replaceBlockInvokeFunction(aBlock);
    return _Block_copy_old(aBlock);
}

void* (*objc_retainBlock_old)(const void *aBlock);
void *objc_retainBlock_new(const void *aBlock)
{
    replaceBlockInvokeFunction(aBlock);
    return objc_retainBlock_old(aBlock);
}


//所有block调用前都会执行blockhookLog,这里的实现就是简单的将block对象的函数符号打印出来！
void blockhookLog(void *blockObj)
{
    struct Block_layout *layout = blockObj;
    
    //注意这段代码在线上的程序是无法获取到符号信息的，因为线上的程序中会删除掉所有block实现函数的符号信息。
    Dl_info dlinfo;
    memset(&dlinfo, 0, sizeof(dlinfo));
    if (dladdr(layout->descriptor->reserved, &dlinfo))
    {
        NSLog(@"%s be called with block object:%@", dlinfo.dli_sname, blockObj);
    }
}


@interface ViewController ()

@end


@implementation ViewController

-(void)foo:(void(^)(void))block
{
    block();
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //初始化并计算可执行程序代码段和数据段的开始和结束位置。
    initImageTextStartAndEndPos();
    
    //这里采用Method Swizzling的机制来替换掉三个类的原始retain实现。
    __NSStackBlock_retain_old =(void *(*)(void*,SEL))class_replaceMethod(NSClassFromString(@"__NSStackBlock__"), sel_registerName("retain"), (IMP)__NSStackBlock_retain_new, nil);
    __NSMallocBlock_retain_old = (void *(*)(void*,SEL))class_replaceMethod(NSClassFromString(@"__NSMallocBlock__"), sel_registerName("retain"), (IMP)__NSMallocBlock_retain_new, nil);
    __NSGlobalBlock_retain_old = (void *(*)(void*,SEL))class_replaceMethod(NSClassFromString(@"__NSGlobalBlock__"), sel_registerName("retain"), (IMP)__NSGlobalBlock_retain_new, nil);
    
    //这里借助fishhook提供的方法来实现动态库中导出的C函数__Block_copy的替换，你也可以添加对objc_retainBlock函数的替换处理
    struct rebinding msg[2];
    msg[0].name = "_Block_copy";
    msg[0].replacement = _Block_copy_new;
    msg[0].replaced = (void**)&_Block_copy_old;
    msg[1].name = "objc_retainBlock";
    msg[1].replacement = objc_retainBlock_new;
    msg[1].replaced = (void**)&objc_retainBlock_old;
    rebind_symbols(msg, 2);

    //下面是实例代码。
    int a = 10;
    
    //global block
    void (^testblock1)(void) = ^()
    {
        NSLog(@"This is a Global block");
    };
    testblock1();
    
    //malloc block
    void (^testblock2)(void) = ^()
    {
        NSLog(@"This is a Malloc block:%d",a);
    };
    testblock2();
    
    
    //stack block
    [self foo:^{
        
        NSLog(@"This is a Stack block:%d",a);
    }];
    
    //结构体返回测试
    struct Block_layout (^testblock3)(void) = ^()
    {
        NSLog(@"This is a Global block for stret");
        
        return (struct Block_layout){0,0,0,0,0};
    };
    testblock3();
    
    //C语言block
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"This is a C language block:%d", a);
    });
    
}


@end
