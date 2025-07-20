# Nix Badge

This repo contains KiCad files and Nix expressions for fabricating
the Nix Badge using [JLCPCB](https://jlcpcb.com).

![](/img/badge-jlc-render.png)

## Building

- `nix build ^*`
    - Gerbers are in `result`
    - Fab output (`nixos_1.zip` Gerber archive; `bom.csv` and `positions.csv` for placement) are in `result-fab`
    - Renders are in `result-render`
    - DRC and ERC checks are in `result-check`

## Nix Flake Logo

Use [NixOS/branding](https://github.com/NixOS/branding) and produce the output
`.#nixos-branding.artifacts.internal.nixos-logomark-default-gradient-none`.

## Reference design

This badge is based on the schematic for the [Qwiic Pocket Development Board](https://www.sparkfun.com/sparkfun-qwiic-pocket-development-board-esp32-c6.html)
by [SparkFun Electronics](https://www.sparkfun.com/), released under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

## "Packaging" svg2shenzhen

_This process probably should have a derivation_

- Download release at https://github.com/badgeek/svg2shenzhen
- Unpack to ~/.config/inkscape/extensions/svg2shenzhen-extension-$version
- `nix-shell -p python3 autoPatchelfHook`
- `chmod +x svg2shenzhen-*/svg2shenzhen/*.py`
- `patchShebangs svg2shenzhen-*`
- `autoPatchelf svg2shenzhen-*`

Create your svg layer stackup in Inkscape. Run the plugin and export a KiCad project.

If you'd like a set of zone polys that knockout a copper fill, use `script/makezones.rb` on the
exported KiCad project. Unfortunately the next step is quite manual, you'll have to take
the output of that and put it into a replacement location in the KiCad PCB project. I usually
draw a zone and then manually replace it, then copy-paste the generated component containing solder mask
and Ctrl-move on top of it.

## Colorful silkscreens

Currently unsupported, even though JLCPCB has supported them since [early 2025](https://jlcpcb.com/blog/multi-color-silkscreen-pcb)
and it would be neat to use the exact NixOS colors with a white ENIG PCB. In the meantime, the blue PCB design
looks close enough.

We package [JLC-FCTS-RE](https://github.com/Xerbo/JLC-FCTS-RE) with a patch to allow choosing the IV and key for decryption.
Note [this Mastodon thread](https://mastodon.social/@arturo182/111372039141259892). If you'd like to decrypt a valid export,
you can set a breakpoint and click the Gerber export button from EasyEDA (search the JS sources for
`-----BEGIN PUBLIC KEY-----` to collect them from the web frontend).

Note that _both_ IV and key are encrypted with [RSA-OAEP](https://datatracker.ietf.org/doc/html/rfc8017#section-7.1),
so you can't decrypt the files afterwards without setting breakpoints on the frontend or otherwise logging out the IV
and key. Encryption is simpler than decryption since the public key is known and JLC-FCTS-RE simply generates a random
IV and key.

The larger problem is that there isn't currently a way to generate silkscreen SVGs that are actually valid.
All attempts have so far resulted in breaking JLCPCB's preview, even if the gerbers are modified in-place
to look like they were produced by EasyEDA. Check the commit history for previous attempts.

There likely needs to be a more complex build step to generate these SVGs from the combination of a background base layer,
edge cuts, and silkscreen zones knocked out by the solder mask layer, on both sides of the board. While it all seems
doable from KiCad, all the pieces aren't working together yet.

## Fabrication playbook

Unfortunately you can't just `deploy-rs` to JLCPCB.

- Upload the gerber bundle
- Configure fabrication options
    - Base material: FR4
    - Delivery Format: Single PCB (panels were actually more expensive)
    - Color: Blue
    - Thickness: 1.0 or 1.6mm. Original dev sample batch was done with 1mm thickness PCB.
    - Surface finish: Leadfree HASL
    - Silkscreen: High Precision
    - Vias: Untented
    - Mark on PCB: Order Number (specify position)
    - Confirm production file: yes
    - Min via hole size: 0.3mm
    - Board outline tolerance: 0.1mm (precision)
- Configure assembly options
    - Assembly Side: both sides
    - Edge rails: Added by JLCPCB
    - Confirm placement: yes
    - Bake components: [C5349954](https://jlcpcb.com/partdetail/XINGLIGHT-XL_1615RGBCWS2812B/C5349954)
    - Solder paste: Medium temp
        - High temperature (non-RoHS) will fry the LEDs
    - Packaging: For real runs, do ESD+Cardboard
- Upload bom.csv and positions.csv from the fab output as BOM and centroid files
    - Note that a couple components are deliberately left out
- Make sure that parts for U1 and U2 are chosen correctly
    - Voltage regulator
        - [Richtek RT9080-33GJ5](https://jlcpcb.com/partdetail/RichtekTech-RT908033GJ5/C841192)
    - Power switch
        - [C7498220](https://jlcpcb.com/partdetail/Lian_XinTechnology-XDMK_12C0125/C7498220)
- Ensure polarity and rotation of Q1, U1, D5, S2, and R14 are all correct using the web UI
    - The first order didn't have any of them correct, but JLC fixed them manually

Lead time is expected to be ~10 days.

## Trimmings

- Battery holders ([BA1AAAPC](https://www.onlinecomponents.com/en/productdetail/memory-protection-devices/ba1aaapc-50288403.html))
- Batteries (ton of AAA [from Amazon](https://www.amazon.com/dp/B07S2LN343))
- Pin headers ([Amazon](https://www.amazon.com/dp/B00UBWKQLA))
- Lanyards ([Amazon](https://www.amazon.com/dp/B0D4HK6VMV))

## Cost

150 badges with all the trimmings will run you about $2500+ with $650 of tariffs.

Small orders are likely less than $500.
