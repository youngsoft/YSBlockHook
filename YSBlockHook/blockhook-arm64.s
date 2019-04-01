//
//  blockhook-arm64.s
//  YSBlockHook
//
//  Created by oubaiquan on 2019/3/29.
//  Copyright © 2019 Youngsoft. All rights reserved.
//


#ifdef __arm64__

.macro ENTRY /* name */
.text
.align 5
.private_extern    $0
$0:
.endmacro


.macro END_ENTRY /* name */
LExit$0:
.endmacro


// void blockhook(...);
ENTRY _blockhook

stp q6, q7, [sp, #-0x20]!
stp q4, q5, [sp, #-0x20]!
stp q2, q3, [sp, #-0x20]!
stp q0, q1, [sp, #-0x20]!
stp x6, x7, [sp, #-0x10]!
stp x4, x5, [sp, #-0x10]!
stp x2, x3, [sp, #-0x10]!
stp x0, x1, [sp, #-0x10]!
stp x8, x30, [sp, #-0x10]!

//执行日志打印函数。
bl _blockhookLog

ldp x8, x30, [sp], #0x10
ldp x0, x1, [sp], #0x10
ldp x2, x3, [sp], #0x10
ldp x4, x5, [sp], #0x10
ldp x6, x7, [sp], #0x10
ldp q0, q1, [sp], #0x20
ldp q2, q3, [sp], #0x20
ldp q4, q5, [sp], #0x20
ldp q6, q7, [sp], #0x20

ldr x16, [x0, #0x18]
ldr x16, [x16]
br x16

END_ENTRY _blockhook

// void blockhook_stret(...);
ENTRY _blockhook_stret
b _blockhook
END_ENTRY _blockhook_stret

#endif
