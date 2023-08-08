.section .text

.global _start
_start:

        la      a0, string
        li      a1, 0x801FFFFC  # "stdout" address
loop:   lb      t0, 0(a0)
        beqz    t0, end
        addi    a0, a0, 1
        sb      t0, 0(a1)
        j       loop

end:    li      t0, 0x00
        sb      t0, 0(a1)
        j       end

.section .rodata
string:
.ascii "Hello World!\n"
.byte 0
