#!/usr/bin/env perl
# Copyright 2017 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the OpenSSL license (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html
#
# ====================================================================
# Written by Andy Polyakov <appro@openssl.org> for the OpenSSL
# project. The module is, however, dual licensed under OpenSSL and
# CRYPTOGAMS licenses depending on where you obtain it. For further
# details see http://www.openssl.org/~appro/cryptogams/.
# ====================================================================
#
# Keccak-1600 for x86_86.
#
# June 2017.
#
# Below code is [lane complementing] KECCAK_2X implementation (see
# sha/keccak1600.c) with C[5] and D[5] held in register bank. Though
# instead of actually unrolling the loop pair-wise I simply flip
# pointers to T[][] and A[][] at the end of round. Since number of
# rounds is even, last round writes to A[][] and everything works out.

my @A = map([ 8*$_-100, 8*($_+1)-100, 8*($_+2)-100,
              8*($_+3)-100, 8*($_+4)-100 ], (0,5,10,15,20));

my @C = ("%rax","%rbx","%rcx","%rdx","%rbp");
my @D = map("%r$_",(8..12));
my @T = map("%r$_",(13..14));
my $iotas = "%r15";

my @rhotates = ([  0,  1, 62, 28, 27 ],
                [ 36, 44,  6, 55, 20 ],
                [  3, 10, 43, 25, 39 ],
                [ 41, 45, 15, 21,  8 ],
                [ 18,  2, 61, 56, 14 ]);

$code.=<<___;
.text

.type	__KeccakF1600,\@function
.align	32
__KeccakF1600:
	mov	$A[4][0](%rdi),@C[0]
	mov	$A[4][1](%rdi),@C[1]
	mov	$A[4][2](%rdi),@C[2]
	mov	$A[4][3](%rdi),@C[3]
	mov	$A[4][4](%rdi),@C[4]
	jmp	.Loop

.align	32
.Loop:
	xor	$A[0][0](%rdi),@C[0]
	xor	$A[0][1](%rdi),@C[1]
	xor	$A[0][2](%rdi),@C[2]
	xor	$A[0][3](%rdi),@C[3]
	xor	$A[0][4](%rdi),@C[4]

	xor	$A[1][0](%rdi),@C[0]
	xor	$A[1][1](%rdi),@C[1]
	xor	$A[1][2](%rdi),@C[2]
	xor	$A[1][3](%rdi),@C[3]
	xor	$A[1][4](%rdi),@C[4]

	xor	$A[2][0](%rdi),@C[0]
	xor	$A[2][1](%rdi),@C[1]
	xor	$A[2][2](%rdi),@C[2]
	xor	$A[2][3](%rdi),@C[3]
	xor	$A[2][4](%rdi),@C[4]

	xor	$A[3][0](%rdi),@C[0]
	xor	$A[3][1](%rdi),@C[1]
	xor	$A[3][2](%rdi),@C[2]
	xor	$A[3][3](%rdi),@C[3]
	xor	$A[3][4](%rdi),@C[4]

	mov	@C[2],@T[0]
	rol	\$1,@C[2]
	xor	@C[0],@C[2]		# D[1] = ROL64(C[2], 1) ^ C[0]

	rol	\$1,@C[0]
	xor	@C[3],@C[0]		# D[4] = ROL64(C[0], 1) ^ C[3]

	rol	\$1,@C[3]
	xor	@C[1],@C[3]		# D[2] = ROL64(C[3], 1) ^ C[1]

	rol	\$1,@C[1]
	xor	@C[4],@C[1]		# D[0] = ROL64(C[1], 1) ^ C[4]

	rol	\$1,@C[4]
	xor	@T[0],@C[4]		# D[3] = ROL64(C[4], 1) ^ C[2]
___
	my @E = @D;
	@D = (@C[1],@C[2],@C[3],@C[4],@C[0]);
	@C = @E;
$code.=<<___;
	mov	$A[0][0](%rdi),@C[0]
	mov	$A[1][1](%rdi),@C[1]
	mov	$A[2][2](%rdi),@C[2]
	mov	$A[3][3](%rdi),@C[3]
	mov	$A[4][4](%rdi),@C[4]

	xor	@D[0],@C[0]
	xor	@D[1],@C[1]
	xor	@D[2],@C[2]
	xor	@D[3],@C[3]
	xor	@D[4],@C[4]

	rol	\$$rhotates[1][1],@C[1]
	rol	\$$rhotates[2][2],@C[2]
	rol	\$$rhotates[3][3],@C[3]
	rol	\$$rhotates[4][4],@C[4]

	mov	@C[1],@T[0]
	or	@C[2],@C[1]
	xor	@C[0],@C[1]		#           C[0] ^ ( C[1] | C[2])
	xor	($iotas),@C[1]
	lea	8($iotas),$iotas
	mov	@C[1],$A[0][0](%rsi)	# R[0][0] = C[0] ^ ( C[1] | C[2]) ^ iotas[i]

	mov	@C[4],@T[1]
	and	@C[3],@C[4]
	xor	@C[2],@C[4]		#           C[2] ^ ( C[4] & C[3])
	mov	@C[4],$A[0][2](%rsi)	# R[0][2] = C[2] ^ ( C[4] & C[3])

	not	@C[2]
	or	@C[3],@C[2]
	xor	@T[0],@C[2]		#           C[1] ^ (~C[2] | C[3])
	mov	@C[2],$A[0][1](%rsi)	# R[0][1] = C[1] ^ (~C[2] | C[3])

	and	@C[0],@T[0]
	xor	@T[1],@T[0]		#           C[4] ^ ( C[1] & C[0])
	mov	@T[0],$A[0][4](%rsi)	# R[0][4] = C[4] ^ ( C[1] & C[0])

	or	@C[0],@T[1]
	xor	@C[3],@T[1]		#           C[3] ^ ( C[4] | C[0])
	mov	@T[1],$A[0][3](%rsi)	# R[0][3] = C[3] ^ ( C[4] | C[0])


	mov	$A[0][3](%rdi),@C[0]
	mov	$A[1][4](%rdi),@C[1]
	mov	$A[2][0](%rdi),@C[2]
	mov	$A[3][1](%rdi),@C[3]
	mov	$A[4][2](%rdi),@C[4]

	xor	@D[3],@C[0]
	xor	@D[4],@C[1]
	xor	@D[0],@C[2]
	xor	@D[1],@C[3]
	xor	@D[2],@C[4]

	rol	\$$rhotates[0][3],@C[0]
	rol	\$$rhotates[1][4],@C[1]
	rol	\$$rhotates[2][0],@C[2]
	rol	\$$rhotates[3][1],@C[3]
	rol	\$$rhotates[4][2],@C[4]

	mov	@C[0],@T[0]
	or	@C[4],@C[0]
	xor	@C[3],@C[0]		#           C[3] ^ (C[0] |  C[4])
	mov	@C[0],$A[1][3](%rsi)	# R[1][3] = C[3] ^ (C[0] |  C[4])

	mov	@C[1],@T[1]
	and	@T[0],@C[1]
	xor	@C[4],@C[1]		#           C[4] ^ (C[1] &  C[0])
	mov	@C[1],$A[1][4](%rsi)	# R[1][4] = C[4] ^ (C[1] &  C[0])

	not	@C[4]
	or	@C[3],@C[4]
	xor	@C[2],@C[4]		#           C[2] ^ (~C[4] | C[3])
	mov	@C[4],$A[1][2](%rsi)	# R[1][2] = C[2] ^ (~C[4] | C[3])

	and	@C[2],@C[3]
	xor	@T[1],@C[3]		#           C[1] ^ (C[3] &  C[2])
	mov	@C[3],$A[1][1](%rsi)	# R[1][1] = C[1] ^ (C[3] &  C[2])

	or	@C[2],@T[1]
	xor	@T[0],@T[1]		#           C[0] ^ (C[1] |  C[2])
	mov	@T[1],$A[1][0](%rsi)	# R[1][0] = C[0] ^ (C[1] |  C[2])


	mov	$A[0][1](%rdi),@C[0]
	mov	$A[1][2](%rdi),@C[1]
	mov	$A[2][3](%rdi),@C[2]
	mov	$A[3][4](%rdi),@C[3]
	mov	$A[4][0](%rdi),@C[4]

	xor	@D[1],@C[0]
	xor	@D[2],@C[1]
	xor	@D[3],@C[2]
	xor	@D[4],@C[3]
	xor	@D[0],@C[4]

	rol	\$$rhotates[0][1],@C[0]
	rol	\$$rhotates[1][2],@C[1]
	rol	\$$rhotates[2][3],@C[2]
	rol	\$$rhotates[3][4],@C[3]
	rol	\$$rhotates[4][0],@C[4]

	mov	@C[2],@T[0]
	and	@C[3],@C[2]
	xor	@C[1],@C[2]		#            C[1] ^ ( C[2] & C[3])
	mov	@C[2],$A[2][1](%rsi)	# R[2][1] =  C[1] ^ ( C[2] & C[3])

	mov	@C[4],@T[1]
	not	@C[3]
	and	@C[3],@C[4]
	xor	@T[0],@C[4]		#            C[2] ^ ( C[4] & ~C[3])
	mov	@C[4],$A[2][2](%rsi)	# R[2][2] =  C[2] ^ ( C[4] & ~C[3])

	or	@C[1],@T[0]
	xor	@C[0],@T[0]		#            C[0] ^ ( C[2] | C[1])
	mov	@T[0],$A[2][0](%rsi)	# R[2][0] =  C[0] ^ ( C[2] | C[1])

	and	@C[0],@C[1]
	xor	@T[1],@C[1]		#            C[4] ^ ( C[1] & C[0])
	mov	@C[1],$A[2][4](%rsi)	# R[2][4] =  C[4] ^ ( C[1] & C[0])

	or	@T[1],@C[0]
	xor	@C[3],@C[0]		#           ~C[3] ^ ( C[0] | C[4])
	mov	@C[0],$A[2][3](%rsi)	# R[2][3] = ~C[3] ^ ( C[0] | C[4])


	mov	$A[0][4](%rdi),@C[0]
	mov	$A[1][0](%rdi),@C[1]
	mov	$A[2][1](%rdi),@C[2]
	mov	$A[3][2](%rdi),@C[3]
	mov	$A[4][3](%rdi),@C[4]

	xor	@D[4],@C[0]
	xor	@D[0],@C[1]
	xor	@D[1],@C[2]
	xor	@D[2],@C[3]
	xor	@D[3],@C[4]

	rol	\$$rhotates[0][4],@C[0]
	rol	\$$rhotates[1][0],@C[1]
	rol	\$$rhotates[2][1],@C[2]
	rol	\$$rhotates[3][2],@C[3]
	rol	\$$rhotates[4][3],@C[4]

	mov	@C[2],@T[0]
	or	@C[3],@C[2]
	xor	@C[1],@C[2]		#            C[1] ^ ( C[2] | C[3])
	mov	@C[2],$A[3][1](%rsi)	# R[3][1] =  C[1] ^ ( C[2] | C[3])

	mov	@C[4],@T[1]
	not	@C[3]
	or	@C[3],@C[4]
	xor	@T[0],@C[4]		#            C[2] ^ ( C[4] | ~C[3])
	mov	@C[4],$A[3][2](%rsi)	# R[3][2] =  C[2] ^ ( C[4] | ~C[3])

	and	@C[1],@T[0]
	xor	@C[0],@T[0]		#            C[0] ^ ( C[2] & C[1])
	mov	@T[0],$A[3][0](%rsi)	# R[3][0] =  C[0] ^ ( C[2] & C[1])

	or	@C[0],@C[1]
	xor	@T[1],@C[1]		#            C[4] ^ ( C[1] | C[0])
	mov	@C[1],$A[3][4](%rsi)	# R[3][4] =  C[4] ^ ( C[1] | C[0])

	and	@T[1],@C[0]
	xor	@C[3],@C[0]		#           ~C[3] ^ ( C[0] & C[4])
	mov	@C[0],$A[3][3](%rsi)	# R[3][3] = ~C[3] ^ ( C[0] & C[4])


	mov	$A[0][2](%rdi),@C[0]
	mov	$A[1][3](%rdi),@C[1]
	mov	$A[2][4](%rdi),@C[2]
	mov	$A[3][0](%rdi),@C[3]
	mov	$A[4][1](%rdi),@C[4]
	xchg	%rsi,%rdi

	xor	@D[2],@C[0]
	xor	@D[3],@C[1]
	xor	@D[4],@C[2]
	xor	@D[0],@C[3]
	xor	@D[1],@C[4]

	rol	\$$rhotates[0][2],@C[0]
	rol	\$$rhotates[1][3],@C[1]
	rol	\$$rhotates[2][4],@C[2]
	rol	\$$rhotates[3][0],@C[3]
	rol	\$$rhotates[4][1],@C[4]

	mov	@C[0],@T[0]
	and	@C[1],@C[0]
	xor	@C[4],@C[0]		#            C[4] ^ ( C[0] & C[1])
	mov	@C[0],$A[4][4](%rdi)	# R[4][4] =  C[4] ^ ( C[0] & C[1])

	mov	@C[2],@T[1]
	not	@C[1]
	and	@C[1],@C[2]
	xor	@T[0],@C[2]		#            C[0] ^ ( C[2] & ~C[1])
	mov	@C[2],$A[4][0](%rdi)	# R[4][0] =  C[0] ^ ( C[2] & ~C[1])

	or	@C[4],@T[0]
	xor	@C[3],@T[0]		#            C[3] ^ ( C[0] | C[4])
	mov	@T[0],$A[4][3](%rdi)	# R[4][3] =  C[3] ^ ( C[0] | C[4])

	and	@C[3],@C[4]
	xor	@T[1],@C[4]		#            C[2] ^ ( C[4] & C[3])
	mov	@C[4],$A[4][2](%rdi)	# R[4][2] =  C[2] ^ ( C[4] & C[3])

	or	@T[1],@C[3]
	xor	@C[1],@C[3]		#           ~C[1] ^ ( C[2] | C[3])
	mov	@C[3],$A[4][1](%rdi)	# R[4][1] = ~C[1] ^ ( C[2] | C[3])

	mov	@C[2],@D[4]		# harmonize with the loop top
	mov	@C[3],@D[0]
	mov	@C[4],@D[1]
	mov	@T[0],@D[2]
	mov	@C[0],@D[3]

	test	\$255,$iotas
	jnz	.Loop

	lea	-192($iotas),$iotas	# rewind iotas
	ret
.size	__KeccakF1600,.-__KeccakF1600

.globl	KeccakF1600
.type	KeccakF1600,\@function
.align	32
KeccakF1600:
	push	%rbx
	push	%rbp
	push	%r12
	push	%r13
	push	%r14
	push	%r15

	lea	100(%rdi),%rdi		# size optimization
	sub	\$200,%rsp

	notq	$A[0][1](%rdi)
	notq	$A[0][2](%rdi)
	notq	$A[1][3](%rdi)
	notq	$A[2][2](%rdi)
	notq	$A[3][2](%rdi)
	notq	$A[4][0](%rdi)

	lea	iotas(%rip),$iotas
	lea	100(%rsp),%rsi		# size optimization

	call	__KeccakF1600

	notq	$A[0][1](%rdi)
	notq	$A[0][2](%rdi)
	notq	$A[1][3](%rdi)
	notq	$A[2][2](%rdi)
	notq	$A[3][2](%rdi)
	notq	$A[4][0](%rdi)
	lea	-100(%rdi),%rdi		# preserve A[][]

	add	\$200,%rsp

	pop	%r15
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbp
	pop	%rbx
	ret
.size	KeccakF1600,.-KeccakF1600
___

{ my ($A_flat,$inp,$len,$bsz) = ("%rdi","%rsi","%rdx","%rcx");
     ($A_flat,$inp) = ("%r8","%r9");
$code.=<<___;
.globl	SHA3_absorb
.type	SHA3_absorb,\@function
.align	32
SHA3_absorb:
	push	%rbx
	push	%rbp
	push	%r12
	push	%r13
	push	%r14
	push	%r15

	lea	100(%rdi),%rdi		# size optimization
	sub	\$232,%rsp

	mov	%rsi,$inp
	lea	100(%rsp),%rsi		# size optimization

	notq	$A[0][1](%rdi)
	notq	$A[0][2](%rdi)
	notq	$A[1][3](%rdi)
	notq	$A[2][2](%rdi)
	notq	$A[3][2](%rdi)
	notq	$A[4][0](%rdi)
	lea	iotas(%rip),$iotas

	mov	$bsz,216-100(%rsi)	# save bsz

.Loop_absorb:
	cmp	$bsz,$len
	jc	.Ldone_absorb

	shr	\$3,$bsz
	lea	-100(%rdi),$A_flat

.Lblock_absorb:
	mov	($inp),%rax
	lea	8($inp),$inp
	xor	($A_flat),%rax
	lea	8($A_flat),$A_flat
	sub	\$8,$len
	mov	%rax,-8($A_flat)
	dec	$bsz
	jnz	.Lblock_absorb

	mov	$inp,200-100(%rsi)	# save inp
	mov	$len,208-100(%rsi)	# save len
	call	__KeccakF1600
	mov	200-100(%rsi),$inp	# pull inp
	mov	208-100(%rsi),$len	# pull len
	mov	216-100(%rsi),$bsz	# pull bsz
	jmp	.Loop_absorb

.align	32
.Ldone_absorb:
	mov	$len,%rax		# return value

	notq	$A[0][1](%rdi)
	notq	$A[0][2](%rdi)
	notq	$A[1][3](%rdi)
	notq	$A[2][2](%rdi)
	notq	$A[3][2](%rdi)
	notq	$A[4][0](%rdi)

	add	\$232,%rsp

	pop	%r15
	pop	%r14
	pop	%r13
	pop	%r12
	pop	%rbp
	pop	%rbx
	ret
.size	SHA3_absorb,.-SHA3_absorb
___
}
{ my ($A_flat,$out,$len,$bsz) = ("%rdi","%rsi","%rdx","%rcx");
     ($out,$len,$bsz) = ("%r12","%r13","%r14");

$code.=<<___;
.globl	SHA3_squeeze
.type	SHA3_squeeze,\@function
.align	32
SHA3_squeeze:
	push	%r12
	push	%r13
	push	%r14

	shr	\$3,%rcx
	mov	$A_flat,%r8
	mov	%rsi,$out
	mov	%rdx,$len
	mov	%rcx,$bsz
	jmp	.Loop_squeeze

.align	32
.Loop_squeeze:
	cmp	\$8,$len
	jb	.Ltail_squeeze

	mov	(%r8),%rax
	lea	8(%r8),%r8
	mov	%rax,($out)
	lea	8($out),$out
	sub	\$8,$len		# len -= 8
	jz	.Ldone_squeeze

	dec	%rcx			# bsz--
	jnz	.Loop_squeeze

	call	KeccakF1600
	mov	$A_flat,%r8
	mov	$bsz,%rcx
	jmp	.Loop_squeeze

.Ltail_squeeze:
	mov	%r8, %rsi
	mov	$out,%rdi
	mov	$len,%rcx
	.byte	0xf3,0xa4		# rep	movsb

.Ldone_squeeze:
	pop	%r14
	pop	%r13
	pop	%r12
	ret
.size	SHA3_squeeze,.-SHA3_squeeze
___
}
$code.=<<___;
.align	256
	.quad	0,0,0,0,0,0,0,0
.type	iotas,\@object
iotas:
	.quad	0x0000000000000001
	.quad	0x0000000000008082
	.quad	0x800000000000808a
	.quad	0x8000000080008000
	.quad	0x000000000000808b
	.quad	0x0000000080000001
	.quad	0x8000000080008081
	.quad	0x8000000000008009
	.quad	0x000000000000008a
	.quad	0x0000000000000088
	.quad	0x0000000080008009
	.quad	0x000000008000000a
	.quad	0x000000008000808b
	.quad	0x800000000000008b
	.quad	0x8000000000008089
	.quad	0x8000000000008003
	.quad	0x8000000000008002
	.quad	0x8000000000000080
	.quad	0x000000000000800a
	.quad	0x800000008000000a
	.quad	0x8000000080008081
	.quad	0x8000000000008080
	.quad	0x0000000080000001
	.quad	0x8000000080008008
.size	iotas,.-iotas
.asciz	"Keccak-1600 absorb and squeeze for x86_64, CRYPTOGAMS by <appro\@openssl.org>"
___

print $code;

close STDOUT;
