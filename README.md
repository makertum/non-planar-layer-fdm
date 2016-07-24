# Slic3r Post-Processing Script For Non-Planar Layer FDM (Perl)
Warps boring, planar G-code from Slic3r (or any other slicer) into wavy shapes. This repository accompanies the corresponding [Hackaday article](http://wp.me/pk3lN-U1O).

## Features
- wavyness-ramps, -in and -out points
- extrusion compensation
- fully configurable through start- and end-gcode, no script modifications required
- configurable displacement
- custom displacement function through Perl expression

## Printing parameters and default values
- set via `; some_parameter = 2` in start or end G-code (or anywhere else)
- available via `$parameters{"some_parameter"} in the script`
- script parameters:
  - `; wave_amplitude = 2.0` [mm] the maximum amplitude of the wavyness
  - `; wave_length = 20.0` [mm] the wave length in xy direction of the waves
  - `; wave_length_2 = 200.0` [mm] an additional wave length parameter, currently only used for testing the wing function
  - `; wave_in = 0.4` [mm] the z-position where it starts getting wavy, should be somewhere above the first layer
  - `; wave_out = 30.0`[mm] the z-position where it stops beeing wavy
  - `; wave_ramp = 10.0` [mm] the length of the transition between not wavy at all and maximum wavyness
  - `; wave_max_segment_length = 1.0` # [mm] max. length of the wave segments, smaller values give a better approximation
  - `; wave_digits = 4` [1] accuracy of output G-code
  - `; wave_function = wave` [String/Perl] wave function, can be "wave", "wing", or any Perl expression (i.e. `abs($x-$paramters{"bed_center_x"})`), which may make use of `$x` or `$parameters{"bed_center_x"}` as well as any other user defined parameter

## How to use
- Have Perl installed and path variables set (Windows users: Strawberry Perl, Linux and OSX: you already have it)
- Set `Slic3r -> Preferences -> Mode` to `Expert`
- Add `; start of print` to the beginning of your G-code (ideally at the **end** of your start G-code)
- Add `; end of print` to the end of your G-code (ideally at the **beginning** of your end G-code)
- Add parameters (see above) to your start G-code as desired
- Add absolute path to the script in `Slic3r -> Print Settings -> Output options -> Post-processing scripts` (no /~ allowed)
- Make sure `Slic3r -> Printer Settings -> General -> Advanced -> Use relative E distances` is checked
- Make sure to **UNCHECK** `Slic3r -> Print Settings -> Layers and perimeters -> Vertical shells -> Spiral vase`.
- Make sure all XYZ moves between `; start of print` and `; end of print` are in absolute mode
- Optional: Check `Slic3r -> Print Settings -> Output options -> Output file -> Verbose G-code`
- Make sure the script file is executable by `chmod 755 non-planar-layer-fdm.pl`
- Slice (& Warp)!

## Examples
The example folder contains additional examples with instructions. Here's a 3D model of the Strati by Local Motors, sliced and treated with the script. The wavyness is limited to the bottom *frame-part* using the `wave_in` and `wave_out` parameters, while the rest of the chassis is untouched.
![Strati 1](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/strati_1.png)
![Strati 2](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/strati_2.png)
![Displacement](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/displacement.png)

## FAQ

### Why?
- The wave displacement transforms tensile forces (=weakness of FDM) between printed layers into shearing forces (=strength of FDM)
- smooth, curved surfaces, i.e. for aerodynamic applications
- aesthetics
- artistic purposes
- fun

### Doesn't this mess up my parts?
- Yes, totally. If you want straight parts afterwards you need to pre-warp them.
- I'm currently experimenting with ImplicitCAD for pre-warped parts.
- A pre-warping script is in the works.

### Why u no use CPAN modules, i.e. Gcode::Interpreter
- They're just not made for this kind of experiments.

## Troubleshooting

### Why doesn't it work
- Are you running Windows 8.1 and might be experiencing a Slic3r bug?
- Are you using the `Slic3r -> Print Settings -> Layers and perimeters -> Vertical shells -> Spiral vase`? This option is currently incompatible with the script.
- Did you check `Slic3r -> Printer Settings -> General -> Advanced -> Use relative E distances`?
- Did you make sure the script file is executable by `chmod 755 non-planar-layer-fdm.pl`?

## Disclaimer / License
This is a work in progress. Any suggestions are heavily welcome. All scripts in this repository are licensed under the GNU Affero General Public License, version 3. Created by Moritz Walter 2016.
