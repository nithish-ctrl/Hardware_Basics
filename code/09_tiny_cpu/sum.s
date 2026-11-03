; sum.s: compute 10 + 9 + ... + 1 and store it at address 128
        LI   r0, 10        ; r0 = counter
        LI   r1, 0         ; r1 = running sum
loop:
        ADD  r1, r0        ; sum = sum + counter
        ADDI r0, -1        ; counter = counter - 1
        JNZ  r0, loop      ; repeat while counter != 0
        ST   r1, [128]     ; mem[128] = sum
        HALT
