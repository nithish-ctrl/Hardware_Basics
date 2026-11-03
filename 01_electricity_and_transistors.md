# Lesson 1 — Electricity, Transistors and Why Hardware Has Limits

> **Why this matters for your GPU:** every limit you'll fight (maximum clock speed, power, why moving data is expensive, why "pipelining" exists) comes from the physics in this lesson. You don't need to be an electrical engineer, but you do need these few ideas to understand *why* hardware engineers make the choices they make.

---

## 1.1 Voltage, Current and Resistance

Think of electricity like water in pipes:

| Electrical idea | Water analogy | Unit | Symbol |
|---|---|---|---|
| **Voltage** | Water pressure | volt (V) | V |
| **Current** | How much water flows per second | ampere (A) | I |
| **Resistance** | How narrow the pipe is | ohm (Ω) | R |
| **Charge** | An amount of water | coulomb (C) | Q |

**Ohm's law** connects them:

```
V = I × R          (voltage = current × resistance)
```

Rearranged: `I = V / R` and `R = V / I`.

### Worked example: the LED on your FPGA board

An FPGA pin outputs **3.3 V**. An LED needs about **2.0 V** across it and about **10 mA** (0.010 A) to glow nicely. What resistor goes in series?

1. The resistor must "use up" the leftover voltage: 3.3 − 2.0 = **1.3 V**.
2. The same current flows through the LED and the resistor: 0.010 A.
3. `R = V / I = 1.3 / 0.010 = 130 Ω`.

Board designers already did this for the LEDs on your board. It's the same arithmetic.

### Power

```
P = V × I          (power in watts = volts × amps)
P = I² × R         (substitute V = I×R)
```

The LED resistor burns `1.3 V × 0.010 A = 0.013 W` (13 mW) as heat. **Every bit of power becomes heat**, and heat is what limits how big and fast a chip can be.

---

## 1.2 How "0" and "1" Are Just Voltage Ranges

Digital hardware doesn't measure exact voltages. It only asks: **is this voltage "low" or "high"?**

For the common 3.3 V standard (LVCMOS33) used on FPGA pins:

```
3.3 V ┤ ████████  definitely "1"
      │ ████████
2.0 V ┤ ────────  minimum voltage guaranteed to be read as 1 (V_IH)
      │  ??????   forbidden zone: undefined
0.8 V ┤ ────────  maximum voltage guaranteed to be read as 0 (V_IL)
      │ ████████
0.0 V ┤ ████████  definitely "0"
```

This is the magic of digital: small noise (say ±0.3 V) doesn't change the meaning. A signal at 3.1 V is still a clean "1". That's why digital circuits can be chained billions of times without errors piling up, while analog signals degrade.

Inside modern chips, the supply voltage is much lower (about 0.7–1.0 V) to save power. Same idea, smaller numbers.

---

## 1.3 The Transistor: a Switch Controlled by Voltage

A **MOSFET** transistor has three terminals that matter to us: **gate**, **source** and **drain**. The gate voltage controls whether current can flow between source and drain. **It's a voltage-controlled switch.**

There are two complementary types:

| Type | Switch is ON (conducts) when gate is | Good at pulling the output |
|---|---|---|
| **NMOS** | HIGH (1) | down to 0 (connects to ground) |
| **PMOS** | LOW (0) | up to 1 (connects to supply, Vdd) |

### The CMOS inverter (NOT gate): 2 transistors

```
          Vdd (1)
           │
        ┌──┴──┐
  in ──o┤ PMOS│   (the "o" means: ON when the gate is LOW)
        └──┬──┘
           ├────── out
        ┌──┴──┐
  in ───┤ NMOS│   ON when the gate is HIGH
        └──┬──┘
           │
          GND (0)
```

- in = 0: PMOS on, NMOS off → output connected to Vdd → **out = 1**
- in = 1: PMOS off, NMOS on → output connected to ground → **out = 0**

Exactly one switch is on at a time, so (ideally) no current flows from Vdd straight to ground. That is why **CMOS** (Complementary MOS) is so power-efficient, and why it took over the world.

### The NAND gate: 4 transistors

```
        Vdd ─────┬─────────┐
              ┌──┴──┐   ┌──┴──┐
       a ───o┤PMOS │ b─o┤PMOS │      two PMOS in PARALLEL (either can pull up)
              └──┬──┘   └──┬──┘
                 └────┬────┘
                      ├──────── out
                   ┌──┴──┐
            a ─────┤NMOS │                two NMOS in SERIES (both must be on to pull down)
                   └──┬──┘
                   ┌──┴──┐
            b ─────┤NMOS │
                   └──┬──┘
                     GND
```

The output is pulled to 0 only when **both** a and b are 1 (both series NMOS on). Otherwise at least one PMOS pulls it to 1. That's **NOT(a AND b)** = NAND.

**Key fact:** in CMOS, NAND and NOR are the *natural* gates (4 transistors each). An AND gate is a NAND followed by an inverter: 6 transistors. So chip designers think in NANDs.

---

## 1.4 Capacitance: Why Every Gate Has a Delay

Every wire and every transistor gate behaves like a tiny **capacitor**: a bucket that must be filled with charge before its voltage rises.

```
Q = C × V           (charge stored = capacitance × voltage)
```

A gate output charges the next gate's input through the resistance of its transistors. That's an **RC circuit**, and the voltage rises along a curve, not instantly:

```
V(t) = Vdd × (1 − e^(−t / RC))
```

```
Vdd ┤                 ___________________
    │            ____/
    │         __/
50% ┤ ------ /           <- the switching point
    │      _/
    │    _/
  0 ┼───/─────┬─────┬─────┬─────┬─────► time
          RC×0.69   RC   2RC   3RC
```

**When is the signal "1"?** When it crosses 50%. Solve `0.5 = 1 − e^(−t/RC)`:

```
e^(−t/RC) = 0.5   →   −t/RC = ln(0.5)   →   t = RC × ln 2 ≈ 0.69 × RC
```

### Worked example

A transistor's resistance is about R = 5 kΩ, and it drives C = 2 fF (femtofarads, 2 × 10⁻¹⁵ F) of load:

```
t = 0.69 × 5,000 × 2×10⁻¹⁵ = 6.9 × 10⁻¹² s ≈ 7 picoseconds
```

That's one gate. A path through 30 gates plus wires takes hundreds of picoseconds. **This is where "propagation delay" comes from**, and it sets the maximum clock speed (Lesson 5).

**Consequences you'll see later:**
- **More fan-out** (one output driving many inputs) means more C, which means slower. Tools duplicate heavily-loaded signals.
- **Long wires** have more C and R, which is why wires between far-apart blocks are slow, and why big chips are split into regions.
- On FPGAs, the programmable **routing** (wires + switches) is often slower than the logic itself.

---

## 1.5 Power: the Real Limit of Modern GPUs

Each time a node switches 0→1, its capacitor is filled from the supply (energy C×V² drawn, half stored, half burned as heat). When it switches 1→0, the stored half is dumped to ground. So:

```
Energy per full 0→1→0 cycle of one node  =  C × V²

Dynamic power  P = α × C × V² × f
```

- **α (activity factor):** what fraction of nodes switch each cycle (e.g. 0.1)
- **C:** total switched capacitance
- **V:** supply voltage
- **f:** clock frequency

### Worked example

A chip with 1 nF of total switched capacitance, α = 0.1, V = 1.0 V, f = 2 GHz:

```
P = 0.1 × 1×10⁻⁹ × 1.0² × 2×10⁹ = 0.2 W
```

Now see the leverage of each term:

| Change | Effect on power |
|---|---|
| Double frequency | 2× power |
| Lower voltage 1.0 → 0.8 V | 0.8² = **0.64×** power (quadratic!) |
| Lower voltage AND frequency together (DVFS) | Roughly cubic savings |
| Stop the clock to idle blocks (**clock gating**) | That block's α → 0 |

There's also **static (leakage) power**: transistors leak a little even when "off". It grows as transistors shrink.

### Why this matters so much for GPUs

A big GPU has a power budget (say 300–700 W) and a fixed cooling capacity. **Power, not transistor count, limits how fast it can run.** That's why:
- GPUs use many slower, simpler cores instead of a few fast ones (Lesson 10). Performance per watt is better.
- **Moving data costs more energy than computing on it.** Sending a bit across a chip charges a long wire (big C). Reading from DRAM charges wires that go off-chip (huge C). Roughly: a 32-bit add costs ~0.1 pJ, reading 32 bits from a nearby on-chip memory ~5 pJ, and from DRAM ~100+ pJ. This single fact explains caches, shared memory, register files, compression and tensor cores.

---

## 1.6 The Clock

A **clock** is a signal that toggles 0,1,0,1 forever at a fixed rate. It's the heartbeat that tells every flip-flop (Lesson 5) when to update.

```
      ┌───┐   ┌───┐   ┌───┐   ┌───┐
clk ──┘   └───┘   └───┘   └───┘   └──
      ↑       ↑       ↑       ↑          rising edges: this is when things happen
      |<----->|
       period T
```

```
frequency f = 1 / T          T = 1 / f
```

| Frequency | Period | Typical where |
|---|---|---|
| 25 MHz | 40 ns | VGA pixel clock (640×480) |
| 100 MHz | **10 ns** | FPGA designs (very common) |
| 200 MHz | 5 ns | Fast FPGA designs |
| 1 GHz | 1 ns | Older CPUs/GPUs |
| 2.5 GHz | 0.4 ns | Modern GPU boost clocks |

Handy conversions: `ns = 1000 / MHz` and `MHz = 1000 / ns`.

**The fundamental rule:** all the logic between two flip-flops must finish (its voltage must settle past 50% and stay there) within **one clock period**. If gates are slow (Section 1.4), the clock must be slow. Lesson 5 turns this into an exact formula.

---

## 1.7 How Chips and FPGAs Use This

- An **ASIC** (custom chip) is literally these transistors, laid out and wired permanently.
- An **FPGA** is a chip full of transistors arranged into *configurable* logic blocks and *configurable* wires. Programming it sets switches that decide what each block computes and how blocks connect. Because of all those extra switches, an FPGA is about 10–30× slower and 20–40× bigger than an ASIC for the same circuit, which is why FPGA designs run at 100–300 MHz instead of GHz.

---

## Common Misunderstandings

- **"Hardware is instant."** No. Every gate takes picoseconds, every wire adds more. Speed limits are physical.
- **"Higher clock = always better."** Power grows with f, and above a point you also need a higher voltage, so power grows much faster. GPUs win with *more* work per cycle, not just more cycles.
- **"Computing is the expensive part."** Moving data is usually more expensive in energy and time.

---

## Exercises

1. An FPGA pin (3.3 V) drives an LED with a 1.8 V drop at 5 mA. What resistor value?
2. A design runs at 150 MHz. What is the clock period in nanoseconds?
3. Using `P = α C V² f`: if you reduce V from 0.9 V to 0.75 V and keep everything else the same, by what factor does dynamic power change?
4. A gate drives 4 identical inputs instead of 1, so its load capacitance is 4× larger. What happens to its delay (using t ≈ 0.69 RC)?
5. Why can a digital signal at 3.0 V still be read as a perfect "1" on a 3.3 V pin?

<details>
<summary><b>Answers</b> (try first!)</summary>

1. Leftover voltage 3.3 − 1.8 = 1.5 V. R = 1.5 / 0.005 = **300 Ω**.
2. T = 1000 / 150 = **6.67 ns**.
3. (0.75 / 0.9)² = 0.833² ≈ **0.694**, so about 31% less power from a 17% voltage drop.
4. Delay is proportional to C, so about **4× slower** (in reality a bit less, because the gate's own internal capacitance doesn't grow). This is why high-fan-out signals get duplicated.
5. Because 3.0 V is above V_IH (2.0 V), the minimum guaranteed "1" level. Digital logic only cares which side of the thresholds a voltage is on.

</details>

---

**You're ready for the next lesson when** you can explain, in your own words, why gates have delay, why power grows with V² and f, and what a clock period is.

**Next:** [Lesson 2 — Numbers and Binary Math](02_numbers_and_binary_math.md)
