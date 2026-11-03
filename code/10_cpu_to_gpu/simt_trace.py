"""simt_trace.py: watch a warp execute, lane by lane, with its active mask.
Run: python simt_trace.py
This is a stripped-down version of the GPU core's behavior (same IF/ELSE/ENDIF/BRANY rules),
written as plain text instructions so you can follow every step.
"""
LANES = 4


def run(program, title, init=None):
    print(f"\n=== {title} ===")
    regs = [dict(r1=0, r2=0, r3=0, r7=0) for _ in range(LANES)]
    for lane in range(LANES):
        regs[lane]["tid"] = lane
        if init:
            regs[lane].update(init(lane))
    mask = [True] * LANES
    stack = []
    labels = {ins[1]: i for i, ins in enumerate(program) if ins[0] == "LABEL"}
    pc, steps = 0, 0
    names = sorted(k for k in regs[0] if k != "tid")
    print(f"{'pc':>2} {'instruction':<22} mask   " + "  ".join(f"{n:>13}" for n in names))
    while pc < len(program) and steps < 200:
        ins = program[pc]
        op = ins[0]
        if op == "LABEL":
            pc += 1
            continue
        steps += 1
        npc = pc + 1
        text = " ".join(str(x) for x in ins)
        if op == "SET":            # SET rd, value_function(lane_regs)   (per lane, masked)
            _, rd, fn, _desc = ins
            text = f"{rd} = {_desc}"
            for l in range(LANES):
                if mask[l]:
                    regs[l][rd] = fn(regs[l])
        elif op == "IF":           # push mask, keep lanes where cond != 0
            stack.append(mask[:])
            mask = [m and regs[l][ins[1]] != 0 for l, m in enumerate(mask)]
        elif op == "ELSE":         # lanes that were active before IF but not in the IF part
            mask = [t and not m for t, m in zip(stack[-1], mask)]
        elif op == "ENDIF":        # restore the mask from before the IF
            mask = stack.pop()
        elif op == "BRANY":        # warp-wide jump if ANY active lane has cond != 0
            if any(m and regs[l][ins[1]] != 0 for l, m in enumerate(mask)):
                npc = labels[ins[2]]
        elif op == "EXIT":
            print(f"{pc:>2} {'EXIT':<22} {''.join('1' if m else '.' for m in mask)}")
            break
        cols = "  ".join("[" + ",".join(f"{regs[l][n]:>2}" for l in range(LANES)) + "]" for n in names)
        print(f"{pc:>2} {text:<22} {''.join('1' if m else '.' for m in mask)}   {cols}")
        pc = npc
    print("(mask: 1 = lane active, . = lane switched off. Columns show [lane0,lane1,lane2,lane3].)")


# ---- Example 1: if (tid is odd) r3 = tid * 10; else r3 = tid + 100;
ifelse = [
    ("SET", "r1", lambda r: r["tid"] & 1, "tid & 1"),
    ("IF", "r1"),
    ("SET", "r3", lambda r: r["tid"] * 10, "tid * 10"),
    ("ELSE",),
    ("SET", "r3", lambda r: r["tid"] + 100, "tid + 100"),
    ("ENDIF",),
    ("EXIT",),
]
run(ifelse, "IF / ELSE: odd lanes take one path, even lanes the other")

# ---- Example 2: a loop where lanes finish at different times
# each lane counts down from (tid + 1): lane 0 loops once, lane 3 loops four times
loop = [
    ("SET", "r7", lambda r: int(r["r2"] > 0), "(r2 > 0)"),
    ("LABEL", "loop"),
    ("IF", "r7"),
    ("SET", "r3", lambda r: r["r3"] + 1, "r3 + 1   (work)"),
    ("SET", "r2", lambda r: r["r2"] - 1, "r2 - 1"),
    ("SET", "r7", lambda r: int(r["r2"] > 0), "(r2 > 0)"),
    ("ENDIF",),
    ("BRANY", "r7", "loop"),
    ("EXIT",),
]
run(loop, "LOOP: lanes drop out one by one, the warp loops until the LAST lane finishes",
    init=lambda lane: {"r2": lane + 1})
