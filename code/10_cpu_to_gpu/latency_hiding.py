"""latency_hiding.py: why GPUs keep many warps. A timeline you can read.
Run: python latency_hiding.py

Model: one issue slot per cycle. Each warp runs a loop of: COMPUTE instructions, then 1 LOAD
that takes MEM_LATENCY cycles before that warp can continue. While a warp waits, the scheduler
issues from any other warp that is ready.
"""


def simulate(num_warps, mem_latency, compute=3, iterations=4, show=True, width=72):
    ready_at = [0] * num_warps          # cycle when each warp can issue again
    left = [compute] * num_warps        # compute instructions left before the next load
    iters = [iterations] * num_warps
    timeline = []
    cycle = busy = 0
    rr = 0
    while any(i > 0 for i in iters):
        issued = "."
        for k in range(num_warps):       # round-robin: first ready warp after the last one
            w = (rr + k) % num_warps
            if iters[w] > 0 and ready_at[w] <= cycle:
                busy += 1
                if left[w] > 0:          # a compute instruction
                    left[w] -= 1
                    issued = str(w)
                    ready_at[w] = cycle + 1
                else:                    # the load: the warp sleeps for mem_latency cycles
                    issued = chr(ord("A") + w)
                    ready_at[w] = cycle + mem_latency
                    left[w] = compute
                    iters[w] -= 1
                rr = w + 1
                break
        timeline.append(issued)
        cycle += 1
    util = busy / cycle
    if show:
        print(f"\nwarps={num_warps}  memory latency={mem_latency}  ->  {cycle} cycles, ALU busy {util:5.1%}")
        line = "".join(timeline)
        for i in range(0, len(line), width):
            print("   " + line[i:i + width])
    return cycle, util


if __name__ == "__main__":
    print("Legend: digit = warp N issued a compute instruction, letter = warp issued a LOAD,")
    print("        '.' = NOTHING could issue (the ALU sat idle).")
    simulate(1, 10)
    simulate(2, 10)
    simulate(4, 10)
    simulate(8, 10)

    print("\nSummary: total work is fixed per warp; see how utilization climbs with more warps.")
    print(f"{'warps':>6} {'latency 10':>12} {'latency 40':>12} {'latency 100':>12}")
    for w in (1, 2, 4, 8, 16, 32):
        cells = []
        for lat in (10, 40, 100):
            _, u = simulate(w, lat, show=False)
            cells.append(f"{u:12.1%}")
        print(f"{w:>6} " + " ".join(cells))
    print("\nLittle's law estimate: each warp issues (compute+1) instructions, then waits L cycles.")
    print("To always have someone ready you need about (L + compute + 1) / (compute + 1) warps:")
    print("for L=40, compute=3 that is (40+4)/4 = 11 warps.")
    print("The table needs MORE than 11, because here all warps start at the same moment and hit")
    print("memory together (they bunch up), and only 4 iterations run, so start-up and the tail count.")
    print("Real GPUs suffer the same bunching, which is one reason they keep even more warps resident.")
