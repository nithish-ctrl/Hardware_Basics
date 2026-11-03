"""tiny_asm.py: assembler for tiny_cpu. Turns readable text into the 16-bit hex the CPU runs.
Run: python tiny_asm.py sum.s sum.hex
"""
import sys

OPCODES = {"LI": 0x0, "ADD": 0x1, "SUB": 0x2, "ADDI": 0x3, "JMP": 0x4,
           "JNZ": 0x5, "LD": 0x6, "ST": 0x7, "HALT": 0xF}


def reg(tok):                       # "r2" -> 2
    return int(tok.strip().lower().lstrip("r"))


def num(tok, labels):               # "10", "0x80", "-1", "[128]" or a label
    tok = tok.strip().strip("[]")
    if tok in labels:
        return labels[tok]
    return int(tok, 0) & 0xFF       # & 0xFF turns -1 into 0xFF (two's complement)


def encode(op, rd=0, rs=0, imm=0):
    #        [15:12]           [11:10]      [9:8]       [7:0]
    return (OPCODES[op] << 12) | (rd << 10) | (rs << 8) | imm


def assemble(text):
    lines = [l.split(";")[0].strip() for l in text.splitlines()]
    # pass 1: give every label the address of the next instruction
    labels, pc = {}, 0
    for l in lines:
        if l.endswith(":"):
            labels[l[:-1]] = pc
        elif l:
            pc += 1
    # pass 2: encode
    out = []
    for l in lines:
        if not l or l.endswith(":"):
            continue
        op, _, rest = l.partition(" ")
        op = op.upper()
        args = [a for a in rest.split(",") if a.strip()]
        if op in ("ADD", "SUB"):
            out.append(encode(op, rd=reg(args[0]), rs=reg(args[1])))
        elif op in ("LI", "ADDI", "JNZ", "LD", "ST"):
            out.append(encode(op, rd=reg(args[0]), imm=num(args[1], labels)))
        elif op == "JMP":
            out.append(encode(op, imm=num(args[0], labels)))
        elif op == "HALT":
            out.append(encode(op))
        else:
            raise SystemExit(f"unknown instruction: {l}")
    return out


if __name__ == "__main__":
    words = assemble(open(sys.argv[1]).read())
    with open(sys.argv[2], "w") as f:
        for w in words:
            f.write(f"{w:04X}\n")
    for w in words:
        print(f"{w:04X} = {w:016b}")
