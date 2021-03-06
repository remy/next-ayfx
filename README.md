# AYFX for NextBASIC

This project is a port of Shiru's AYFX format for NextBASIC*.

What this offers: the ability to play back sound effects on the AY-8-3912 chips without interrupting NextBASIC during runtime.

_\* If writing assembly, [Shiru's AYFX Editor](https://shiru.untergrund.net/software.shtml#old) includes source code to play the FX bank and it's likely you don't need this library._

## How it works

- A driver is loaded and is configured to point to a `BANK` that holds [your special effects](#creating-sound-effects).
- The driver waits for an interrupt and then processes a single frame of audio on the AY-8-3912 chip.
- The player can play effects using all three AY channels. When there is an empty (not playing) channel, it will be used, otherwise the one that was active for longest time will be used. AY music can't play while this version of the player is active.
- The driver will also put the selected AY chip into mono mode which boosts the volume of the sound (rather than splitting across stereo left, centre and right), this is done in the interrupt routine by repeatedly setting [NEXTREG $09](https://wiki.specnext.dev/Peripheral_4_Register)

## Usage

You will need the `ayfx.drv` file accessible to your project. Then `.install` the driver and call it's initialisation routine, then the playback routine:

```basic
10 .install "ayfx.drv"
20 LOAD "my-sfx.afb" BANK 20 : REM bank 20 is picked arbitrarily
30 DRIVER 49, 1, 20 : REM point the driver to your bank 20
40 REPEAT
50   k$ = INKEY$
60   DRIVER 49, 2, VAL k$ : REM play the fx at the numerical value k$
70 REPEAT UNTIL 0 : REM loop forever
```

You can also view the [examples](https://github.com/remy/next-ayfx/tree/main/example) directory for other NextBASIC examples.

## Using with NextDAW

Important: if you're using this driver with the NextDAW driver, make sure to **install the NextDAW driver first** otherwise you'll hear some very bad audio corruption.

## Driver API

There are currently only two routines available in the driver:

- `1, arg: $bank_id, [$ay_chip=3]` - initialise the audio to point a 16K bank and _optionally_ select an AY chip
- `2, arg: $effects_id` - start playing the given effect id

**The driver id is 49 (hex 0x31)**

## AY chip select

By default the driver uses AY chip 3. To change the AY chip used, the second argument to routine `1` is the chip number from 1 to 3 (note that 0 will default to chip 3).

This is to add compatibility with other drivers using the AY chips, allowing you, for example, to use AY chip 1 and 2 for NextDAW and AY chip 3 for special effects.

To use AY chip 1, the NextBASIC code is as follows:

```basic
30 DRIVER 49, 1, 25, 1 : REM use BANK 25 and use AY chip 1
```

## Creating Sound Effects

If you use Windows, you can install and use [Shiru's AYFX Editor](https://shiru.untergrund.net/software.shtml#old) (though it works, it doesn't quite render correctly on newer machines).

Alternatively I have created an online tool that replicates the AYFX UI (which also works offline) where you can create, edit, preview and save your own effects: https://zx.remysharp.com/audio/

Once you've designed your sound effects, **save the bank** of effects taking note of the position of the effects. This is the file you will need to load into a NextBASIC `BANK` (seen in the example on line 20).

## Known issues

The AYFX driver will playback on the 3 AY channels that were available to the 128K spectrum regardless of what's using it already. That means that if you're playing some music at the same time on the AY channels (such as using NextDAW) the sound can sometimes become _crunchy_. This is the noise mix being left on when the AYFX jumps in to play it's effect.

Your mileage will vary. I've personally found that this doesn't create too much of an audible nuisance as one effect might trigger the noise mix, but many others will set it back (it also creates some subtle variation in the music in my games).

## Possible upgrades

Though there's no priority to do so, possible upgrades include:

- De-registration of the driver (this means removing the saved user bank ID)

## License

- [MIT](https://rem.mit-license.org)
