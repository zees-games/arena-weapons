#!/usr/bin/env python3
"""Builds each gun's own layered fire sound (attack, body, open-air tail, far) from the CC0 Free Firearm Sound
Library recordings, with the layer splitting, tails and levels of dot-audio's tools/make_shot_layers.py, which this
runs rather than copies. Heavy guns get a generated low thump under the body. Two variants per gun: the take, and
the same take a few percent lower with its own tail seeds. Room tails stay the stock class's (AwShotLayers).

Needs numpy, scipy and ffmpeg. Run: python3 tools/make_fire_sounds.py [gun ...]  (default: every gun below).
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DOT_AUDIO = os.environ.get("DOT_AUDIO", os.path.join(HERE, "..", "..", "dot-audio"))
if not os.path.isdir(os.path.join(DOT_AUDIO, "tools")):
    DOT_AUDIO = "/home/gamedev/godot/dot-audio"
LIB = os.path.join(DOT_AUDIO, "source-candidates", "free-firearm-sound-library", "raw", "Prepared SFX Library")
OUT = os.path.join(HERE, "..", "addons", "arena_weapons", "assets", "sounds")

# Its helpers in their own namespace, so its OUT (dot-audio's stock folder) can never be where this writes; a checkout
# older than its main guard ends in a bare main() call, cut off here.
_src = open(os.path.join(DOT_AUDIO, "tools", "make_shot_layers.py")).read()
if _src.rstrip().endswith("\nmain()"):
    _src = _src[: _src.rindex("\nmain()")]
L = {"__name__": "make_shot_layers", "__file__": os.path.join(DOT_AUDIO, "tools", "make_shot_layers.py")}
exec(compile(_src, "make_shot_layers.py", "exec"), L)
RATE = L["RATE"]

# gun: (library folder, near take, mid-distance take, thump Hz or 0, variant 1 pitch)
GUNS = {
    "sniper": ("Tikka", "W_29P", "W_24P", 48.0, 0.95),
    "marksman": ("Arisaka", "E_25P", "E_18P", 55.0, 0.96),
    "battle_rifle": ("1917", "B_24P", "B_16P", 55.0, 0.96),
    "rifle": ("AK-47", "C_28P", "C_31P", 0.0, 0.96),
    "bullpup": ("AR-15", "D_32P", "D_24P", 0.0, 0.97),
    "carbine": ("Savage 10 .300 Blackout", "T_27P", "T_17P", 0.0, 0.97),
    "burst_rifle": ("SKS", "U_14P", "U_19P", 0.0, 0.97),
    "lmg": ("Mosin Nagant", "M_21P", "M_26P", 60.0, 0.97),
    "shotgun": ("Nova", "O_21P", "O_17P", 52.0, 0.95),
    "drum_shotgun": ("Mossberg", "N_30P", "N_26P", 58.0, 0.97),
    "pistol": ("Walther PPQ", "X_39P", "X_31P", 0.0, 0.96),
    "machine_pistol": ("Bersa", "F_47P", "F_41P", 0.0, 0.97),
    "derringer": ("Ruger Single Six", "S_14P", "S_11P", 0.0, 0.96),
    "revolver": ("Smith & Wesson 642", "V_27P", "V_22P", 0.0, 0.95),
    "smg": ("Carl Gustav M45", "G_31P", "G_20P", 0.0, 0.97),
    "minigun": ("PPSh", "P_30P", "P_16P", 0.0, 0.98),
}
VARIANTS = 2


def thump(n, hz, seed):
    """A falling low sine, the chest punch a recording at a distance loses; generated here, so no licence."""
    t = np.arange(n) / RATE
    rng = np.random.default_rng(seed)
    f = hz * (1.0 + 0.6 * np.exp(-t / 0.02)) * rng.uniform(0.97, 1.03)
    y = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / 0.11)
    return y * L["ramp"](n, 0, int(0.003 * RATE))


def pitched(x, factor):
    """[param x] played [param factor] times as fast (below 1 is lower and longer)."""
    if factor == 1.0:
        return x
    src = np.arange(0, len(x) - 1, factor)
    return np.interp(src, np.arange(len(x)), x)


def build(gun):
    folder_name, near, mid, hz, low = GUNS[gun]
    base = L["trim"](L["load"](os.path.join(LIB, folder_name, near + ".wav")))
    far_src = L["trim"](L["load"](os.path.join(LIB, folder_name, mid + ".wav")))
    folder = os.path.join(OUT, gun)
    os.makedirs(folder, exist_ok=True)
    peak = 20 * np.log10(0.89)
    gain = 10 ** (peak / 20)
    for n in range(VARIANTS):
        factor = 1.0 if n == 0 else low
        x = pitched(base, factor)
        x /= np.max(np.abs(x)) + 1e-9
        attack, body, late = L["split"](x)
        if hz > 0.0:
            body = body + 0.45 * thump(len(body), hz * factor, 90 + n)
        L["write"](os.path.join(folder, "attack_%d.ogg" % n), attack * gain, peak)
        L["write"](os.path.join(folder, "body_%d.ogg" % n), body * gain, peak)
        L["write"](os.path.join(folder, "tail_outdoor_%d.ogg" % n), L["outdoor_for"](x, late, 700 + n) * gain, L["OUTDOOR_DB"])
        f = pitched(far_src, factor)
        L["write"](os.path.join(folder, "far_%d.ogg" % n), L["far_for"](f / (np.max(np.abs(f)) + 1e-9), 40 + n) * gain, peak - 6.0)
    print(gun, VARIANTS, "variants")


for g in sys.argv[1:] or GUNS:
    build(g)
