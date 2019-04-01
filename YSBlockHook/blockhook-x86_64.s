//
//  blockhook-x86_64.s
//  YSBlockHook
//
//  Created by oubaiquan on 2019/3/29.
//  Copyright © 2019 Youngsoft. All rights reserved.
//


#ifdef __x86_64__

.macro ENTRY /* name */
.text
.align 5
.private_extern    $0
$0:
.endmacro


.macro END_ENTRY /* name */
LExit$0:
.endmacro

//void blockhook(...);
ENTRY _blockhook

    subq   $0xc8, %rsp
    movupd %xmm7, 0xb8(%rsp) //push最多8个字节，%xmm0 向量寄存器16个字节，无法用push
    movupd %xmm6, 0xa8(%rsp)
    movupd %xmm5, 0x98(%rsp)
    movupd %xmm4, 0x88(%rsp)
    movupd %xmm3, 0x78(%rsp)
    movupd %xmm2, 0x68(%rsp)
    movupd %xmm1, 0x58(%rsp)
    movupd %xmm0, 0x48(%rsp)
    movq   %r9, 0x40(%rsp)
    movq   %r8, 0x38(%rsp)
    movq   %rcx, 0x30(%rsp)
    movq   %rdx, 0x28(%rsp)
    movq   %rsi, 0x20(%rsp)
    movq   %rdi, 0x18(%rsp)
    movq   %rax, 0x10(%rsp)

    call _blockhookLog

    movupd 0xb8(%rsp), %xmm7
    movupd 0xa8(%rsp), %xmm6
    movupd 0x98(%rsp), %xmm5
    movupd 0x88(%rsp), %xmm4
    movupd 0x78(%rsp), %xmm3
    movupd 0x68(%rsp), %xmm2
    movupd 0x58(%rsp), %xmm1
    movupd 0x48(%rsp), %xmm0
    movq   0x40(%rsp), %r9
    movq   0x38(%rsp), %r8
    movq   0x30(%rsp), %rcx
    movq   0x28(%rsp), %rdx
    movq   0x20(%rsp), %rsi
    movq   0x18(%rsp), %rdi
    movq   0x10(%rsp), %rax
    addq   $0xc8, %rsp

    movq   0x18(%rdi), %rax
    movq   0x00(%rax), %rax
    jmpq *%rax

END_ENTRY _blockhook

//如果block返回的是一个超过16字节长度的结构体，则blockhook改为调用blockhook_stret。这时候对象将作为第二个参数而非第一个参数。
ENTRY _blockhook_stret

    subq  $0xc8, %rsp
    movupd %xmm7, 0xb8(%rsp) //push最多8个字节，%xmm0 向量寄存器16个字节，无法用push
    movupd %xmm6, 0xa8(%rsp)
    movupd %xmm5, 0x98(%rsp)
    movupd %xmm4, 0x88(%rsp)
    movupd %xmm3, 0x78(%rsp)
    movupd %xmm2, 0x68(%rsp)
    movupd %xmm1, 0x58(%rsp)
    movupd %xmm0, 0x48(%rsp)
    movq   %r9, 0x40(%rsp)
    movq   %r8, 0x38(%rsp)
    movq   %rcx, 0x30(%rsp)
    movq   %rdx, 0x28(%rsp)
    movq   %rsi, 0x20(%rsp)
    movq   %rdi, 0x18(%rsp)
    movq   %rax, 0x10(%rsp)

    mov %rsi, %rdi
    call _blockhookLog

    movupd 0xb8(%rsp), %xmm7
    movupd 0xa8(%rsp), %xmm6
    movupd 0x98(%rsp), %xmm5
    movupd 0x88(%rsp), %xmm4
    movupd 0x78(%rsp), %xmm3
    movupd 0x68(%rsp), %xmm2
    movupd 0x58(%rsp), %xmm1
    movupd 0x48(%rsp), %xmm0
    movq   0x40(%rsp), %r9
    movq   0x38(%rsp), %r8
    movq   0x30(%rsp), %rcx
    movq   0x28(%rsp), %rdx
    movq   0x20(%rsp), %rsi
    movq   0x18(%rsp), %rdi
    movq   0x10(%rsp), %rax
    addq   $0xc8, %rsp

    movq   0x18(%rsi), %rax
    movq   0x00(%rax), %rax
    jmpq *%rax

END_ENTRY _blockhook_stret

#endif
