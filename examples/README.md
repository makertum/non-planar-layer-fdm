# Examples
Example files for the Slic3r post-processing script for non-planar layer FDM.

## How to use
- Save the content of this repository to your local drive
- Read the general instructions of this repository
- Load the `Slic3r_config_bundle.ini` into Slic3r. It contains the following settings:
  - *Printing*
    - Cube1
    - Cube2
    - Cube3
    - Wing
  - *Printer*
    - Cube1
    - Cube2
    - Cube3
    - Wing
- Add absolute path to the script (`path/to/non-planar-layer-fdm.pl`) to the imported *Printing* settings (Cube1-4 and Wing).
- Slice the example files with the corresponding settings (see below).
- Check the results in your favorite G-code visualizer (Repetier Host is recommended).

## Examples
### 1. Cube with gradual displacement
- STL-file: `cube1.stl`
- Slic3r Settings:
  - Printing: Cube1
  - Printer: Cube1
- Expected result:
  ![Cube1](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/cube1.png)

### 2. Cube with wavy top surface
- STL-file: `cube2.stl`
- Slic3r Settings:
  - Printing: Cube2
  - Printer: Cube2
- Expected result:
  ![Cube1](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/cube2.png)

### 2. Cube with pattern on top
- STL-file: `cube3.stl`
- Slic3r Settings:
  - Printing: Cube3
  - Printer: Cube3
- Expected result:
  ![Cube1](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/cube3.png)

### 3. Wing
- STL-file: `wing.stl`
- Slic3r Settings:
  - Printing: Wing
  - Printer: Wing
- Expected result:
  ![Cube1](https://github.com/makertum/non-planar-layer-fdm/raw/master/images/wing.png)
