
.data
.L1: .asciz "true"
.L2: .asciz "false"

.text
.globl _main
_main:
	movq $33554436, %rax
	movq $1, %rdi
	leaq .L1(%rip), %rsi
	movq $4, %rdx
	syscall
	movq $0, %rax
	movq $0, %rdi
	movq $0, %rsi
	movq $0, %rdx

	movq $33554436, %rax
	movq $1, %rdi
	leaq .L2(%rip), %rsi
	movq $5, %rdx
	syscall
	movq $0, %rax
	movq $0, %rdi
	movq $0, %rsi
	movq $0, %rdx

	movq $33554433, %rax
	movq $0, %rdi
	syscall
	movq $0, %rax
	movq $0, %rdi

