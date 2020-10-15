.data

.LC0: .asciz  "hello"

.text

.globl start
start:

        movq $0x2000004, %rax
        movq $1, %rdi
        leaq .LC0(%rip), %rsi
        movq $5, %rdx
        syscall
        xorq %rax, %rax
        xorq %rdi, %rdi
        xorq %rsi, %rsi

        movq $0, %rdi
        movl $0x2000001, %eax           # exit 0
        syscall
