# Slic3r Post-Processing Script For Non-Planar Layer FDM (Perl)
Warps boring, planar G-Code from Slic3r (or any other slicer) into wavy shapes.

## Features
- wavyness-ramps, -in and -out points
- extrusion compensation
- configurable displacement

## Printing parameters and default values
- set via `; some_parameter = 2` in start or end G-code (or anywhere else)
- available via `$parameters{"some_parameter"} in the script`
- script parameters:
  `; wave_amplitude = 2.0` [mm] the maximum amplitude of the wavyness
  `; wave_length = 20.0` [mm] the wave length in xy direction of the waves
  `; wave_in = 0.4` [mm] the z-position where it starts getting wavy, should be somewhere above the first layer
  `; wave_out = 30.0`[mm] the z-position where it stops beeing wavy
  `; wave_ramp = 10.0` [mm] the length of the transition between not wavy at all and maximum wavyness
  `; wave_max_segment_length = 1.0` # [mm] max. length of the wave segments, smaller values give a better approximation
  `; wave_digits = 4` [1] accuracy of output g-code

## How to use
- Have Perl installed and path variables set (Windows users: Strawberry perl, Linux OSX: you already have it)
- Add `; start of print` to the beginning of your G-code (ideally at the end of your start g-code)
- Add `; end of print` to the end of your G-code (ideally at the beginning of your end g-code)
- Set `Slic3r -> Preferences -> Mode` to `Expert`
- Add absolute path to the script in `Slic3r -> Print Settings -> Output options -> Post-processing scripts` (no /~ allowed)
- Make sure `Slic3r -> Printer Settings -> General -> Advanced -> Use relative E distances` is checked
- Optional: Check `Slic3r -> Print Settings -> Output options -> Output file -> Verbose G-code`
- Slice (& Warp)!

## FAQ

### Why?
- The wave displacement transforms tensile forces (=weakness of FDM) between printed layers into shearing forces (=strength of FDM)
- The larger contact surface area between layers may additionally strengthen the parts
- aesthetics
- artistic purposes
- fun

### Doesn't this mess up my parts?
- Yes, totally. If you want straight parts afterwards you need to pre-warp them.
- I'm currently experimenting with ImplicitCAD for pre-warped parts.

### There is a @#! in your code. You should die.
- I know those canons. It's the Perl. What was the question?

### Why u no use CPAN modules, i.e. Gcode::Interpreter
- Not because they suck, really, they're just not made for this kind of experiments

## Troubleshooting

### Why doesn't it work
- You're running Windows 8.1 and might be experiencing a Slic3r bug
- You might have missed to check `Slic3r -> Printer Settings -> General -> Advanced -> Use relative E distances`
- You're using the vase-mode in Slic3r, which is currently incompatible with the script.

## Disclaimer / License
This is a work in progress. Any suggestions are heavily welcome. All scripts in this repository are licensed under the GNU Affero General Public License, version 3. Created by Moritz Walter 2016.