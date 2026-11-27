# Samsung S5K4H8 camera sensor driver

Mainline-style Linux V4L2 sub-device driver for the Samsung S5K4H8, the
8 megapixel rear sensor on the Motorola Moto E4 (`perry`, Qualcomm
MSM8917). The sensor speaks CCI over I2C and sends RAW10 over a 4-lane
MIPI CSI-2 link. This repository holds the driver, its devicetree
binding, and a two-patch series that applies to current linux-media.

The bring-up goal is a sensor driver that can sit in front of mainline
CAMSS and libcamera, using `v4l2-cci` for register I/O and the subdev
active-state API (`init_state`, `enable_streams`). Register tables are
adapted from the Rockchip vendor driver (GPL-2.0, Copyright (C) 2017
Fuzhou Rockchip Electronics Co., Ltd.).

## Hardware

| Item | Value |
| --- | --- |
| Device | Motorola Moto E4, codename `perry` |
| SoC | Qualcomm MSM8917 |
| Sensor | Samsung S5K4H8, 8 MP, 1/4 inch optical format |
| Chip id | `0x4088` at CCI register `0x0000` |
| Control bus | CCI / I2C, address `0x2d` |
| Pixel bus | 4-lane MIPI CSI-2 D-PHY |
| Link frequency | 280 MHz (560 Mbps/lane) |
| External clock | 24 MHz MCLK |
| Pixel format | `MEDIA_BUS_FMT_SGRBG10_1X10` (RAW10, SGRBG) |
| Supplies | `avdd` (about 2.8 V), `dovdd` (about 1.8 V), `dvdd` (about 1.2 V) |
| Reset | Active-low XSHUTDOWN, devicetree `reset-gpios` |

Power-on order in the driver: bulk regulators, then MCLK, then
XSHUTDOWN deassert, then a 10 ms settle. Streaming on and off is an
8-bit write of `0x01` or `0x00` to register `0x0100`.

| Mode | Resolution | Frame rate | Notes |
| --- | --- | --- | --- |
| Full | 3264×2448 | about 25 fps | Native array. Probe selects this mode. |
| Binned | 1632×1224 | about 30 fps | 2×2 binning of the same array |

Both modes read the full pixel array. The binned mode is 2×2 binning,
and the crop selection stays at 3264×2448.

Controls: exposure, analogue gain, vertical blanking, and read-only
horizontal blanking, link frequency, and pixel rate. Location and
rotation come from the fwnode properties on the sensor node.

On the Moto E4, with mainline-track CAMSS and the libcamera Simple
pipeline, the rear sensor captured about 24 fps at 3264×2448 SGRBG10.
`v4l2-compliance` on the sensor subdev reported 46 tests, 46 succeeded,
0 failed, 0 warnings. The front OV5695 on the same phone stayed up.

## Repository layout

| Path | Role |
| --- | --- |
| `s5k4h8.c` | Driver source. SPDX `GPL-2.0`. |
| `samsung,s5k4h8.yaml` | Devicetree binding. SPDX `(GPL-2.0-only OR BSD-2-Clause)`. |
| `patches/` | `git format-patch` series for linux-media, including the cover letter. |
| `Makefile` | Out-of-tree module build. |
| `.github/workflows/ci.yml` | checkpatch, `git am`, and an in-tree compile. |

## Kernel tree this series targets

```
repo:    https://git.linuxtv.org/media.git
branch:  next
commit:  aa0f4c41d4870a18e65772a1817af16427200371
subject: media: ipu6: Enable snooping on ipu7 isys buffers
date:    2026-11-17
version: 7.4.0-rc1 (the version string of that media tree)
```

Fetch that exact commit:

```sh
git clone https://git.linuxtv.org/media.git
cd media
git fetch origin aa0f4c41d4870a18e65772a1817af16427200371
git checkout aa0f4c41d4870a18e65772a1817af16427200371
```

`media.git` publishes `next` and `fixes`. New sensor work belongs on
`next`. See [Status and limitations](#status-and-limitations) for why
this is the baseline.

Host packages used to compile the object here: `gcc`, `make`, `flex`,
`bison`, `bc`, `libssl-dev`, `libelf-dev`. The compile below is an
x86_64 host build. The driver is portable C; the phone itself needs an
ARM kernel built for MSM8917 with the same sources and with
`CONFIG_VIDEO_S5K4H8=m`.

## Build in-tree

From a checkout of the commit above, apply the two patches (skip the
cover letter; `git am` does not take it):

```sh
git am /path/to/s5k4h8/patches/0001-*.patch \
       /path/to/s5k4h8/patches/0002-*.patch
```

That adds `drivers/media/i2c/s5k4h8.c`,
`Documentation/devicetree/bindings/media/i2c/samsung,s5k4h8.yaml`,
`CONFIG_VIDEO_S5K4H8`, the Makefile line, and a `MAINTAINERS` entry.

Enable the driver. x86_64 defconfig leaves `HAVE_CLK` off, and the
camera-sensor menu depends on it, so the common clock framework has to
be selected first. An MSM8917 or arm64 defconfig already has clocks;
keep the `VIDEO_S5K4H8` line either way.

```sh
make defconfig
./scripts/config --enable COMMON_CLK
./scripts/config --enable MEDIA_SUPPORT
./scripts/config --enable MEDIA_CAMERA_SUPPORT
./scripts/config --enable VIDEO_DEV
./scripts/config --enable VIDEO_CAMERA_SENSOR
./scripts/config --module VIDEO_S5K4H8
make olddefconfig
grep -E '^CONFIG_(VIDEO_S5K4H8|V4L2_CCI_I2C)=' .config
```

Expected:

```
CONFIG_V4L2_CCI_I2C=m
CONFIG_VIDEO_S5K4H8=m
```

Compile check, after `modules_prepare`. This is what CI runs. It
produces `drivers/media/i2c/s5k4h8.o` and does not build vmlinux.

```sh
make -j"$(nproc)" modules_prepare
make -j"$(nproc)" drivers/media/i2c/s5k4h8.o
```

A loadable `s5k4h8.ko` needs `Module.symvers` from a kernel built for
the machine that will load it. On that tree:

```sh
make -j"$(nproc)"
make -j"$(nproc)" M=drivers/media/i2c modules
sudo make M=drivers/media/i2c modules_install
sudo depmod -a
```

`modules_prepare` alone is enough for the `.o`. Linking the `.ko`
against that partial tree stops in modpost, because core and V4L2
symbols are still undefined. That is the expected result until vmlinux
has been linked.

## Build out-of-tree

Prepare the pinned media tree with the config and `modules_prepare`
steps above. From this repository:

```sh
make KDIR=/path/to/media
```

`KDIR` defaults to `/lib/modules/$(uname -r)/build`. A distro kernel
from 2024 or 2025 will fail: this driver calls
`devm_v4l2_sensor_clk_get()` and the current `set_fmt` /
`get_selection` prototypes, which take
`struct v4l2_subdev_client_info`. Point `KDIR` at the pinned media tree,
or at an MSM8917 kernel that already contains those APIs.

The same modpost rule applies. Out-of-tree `s5k4h8.o` compiles against a
`modules_prepare` tree. `s5k4h8.ko` links cleanly when that tree has a
real `Module.symvers`.

## Load

On the target, after `modules_install`:

```sh
sudo modprobe s5k4h8
```

or, from the directory that holds the module:

```sh
sudo insmod s5k4h8.ko
```

`modprobe` succeeds when the module matches the running kernel. The
driver probes a device only when a devicetree node (or an equivalent
firmware node) matches `samsung,s5k4h8` and the supplies, clock, and
reset GPIO are present. Without that node the module loads and no
sensor is registered.

Confirm probe:

```sh
dmesg | grep -i s5k4h8
```

A successful probe logs `Detected S5K4H8 sensor (id 0x4088)`.

## Device tree

Board nodes are not in this series. The snippet below is the Moto E4
shape used during bring-up: sensor on CCI I2C0 at `0x2d`, 24 MHz MCLK,
active-low reset, three supplies, four data lanes, 280 MHz link. The
GPIO number, regulator labels, and clock provider are board properties
and have to match the phone's dts. The binding example in
`samsung,s5k4h8.yaml` is the same contract with placeholder regulators.

```dts
&cci_i2c0 {
	camera@2d {
		compatible = "samsung,s5k4h8";
		reg = <0x2d>;

		clocks = <&gcc GCC_CAMSS_MCLK0_CLK>;
		clock-names = "mclk";
		assigned-clocks = <&gcc GCC_CAMSS_MCLK0_CLK>;
		assigned-clock-rates = <24000000>;

		reset-gpios = <&tlmm 35 GPIO_ACTIVE_LOW>;

		avdd-supply = <&cam_avdd>;
		dovdd-supply = <&cam_dovdd>;
		dvdd-supply = <&cam_dvdd>;

		port {
			s5k4h8_ep: endpoint {
				remote-endpoint = <&csiphy0_ep>;
				data-lanes = <1 2 3 4>;
				link-frequencies = /bits/ 64 <280000000>;
			};
		};
	};
};
```

Kernel config on the phone image:

```
CONFIG_VIDEO_S5K4H8=m
```

`VIDEO_CAMERA_SENSOR` selects the media controller, fwnode helper, and
V4L2 subdev API. The driver selects `V4L2_CCI_I2C`.

## Test with media-ctl and v4l2-ctl

These commands need the phone (or another board) booted on a kernel
that probed the sensor, plus `v4l-utils`. Names below are the ones this
driver exposes. The media device index and the I2C adapter number come
from the running system: the entity is `s5k4h8 <adapter>-002d`. Find
them first.

```sh
media-ctl -p
v4l2-ctl --list-devices
```

Full-resolution mode on pad 0. Replace the entity and `/dev/mediaN` with
what `media-ctl -p` printed. `s5k4h8 0-002d` is the name when the sensor
enumerates as address `0x2d` on `i2c-0`.

```sh
media-ctl -d /dev/media0 --set-v4l2 \
	'"s5k4h8 0-002d":0[fmt:SGRBG10_1X10/3264x2448]'
```

Binned mode:

```sh
media-ctl -d /dev/media0 --set-v4l2 \
	'"s5k4h8 0-002d":0[fmt:SGRBG10_1X10/1632x1224]'
```

Controls and a short compliance run. `v4l2-ctl --list-devices` prints the
subdev node; on the perry bring-up it was `/dev/v4l-subdev15`.

```sh
v4l2-ctl -d /dev/v4l-subdev15 --list-ctrls
v4l2-ctl -d /dev/v4l-subdev15 --set-ctrl=exposure=1024
v4l2-ctl -d /dev/v4l-subdev15 --set-ctrl=analogue_gain=32
v4l2-compliance -d /dev/v4l-subdev15
```

Capture through libcamera's Simple pipeline, once CAMSS is linked and
the pipeline handler can see the sensor:

```sh
cam -c 1 --list-controls
cam -c 1 --capture=20 --file=/tmp/frame.raw
```

Frames are packed SGRBG10. A viewer has to know the stride CAMSS used.

## What requires the physical phone

Needs the Moto E4, or another board wired to an S5K4H8 the same way:

- I2C chip-id read (`0x4088`), regulator enable, 24 MHz MCLK, and the
  reset GPIO. Probe fails closed if any of those are wrong.
- MIPI CSI-2 streaming into CAMSS, frame rate, and whether the image is
  the expected Bayer pattern.
- Live `v4l2-compliance` against `/dev/v4l-subdevN`.
- libcamera capture and the ~24 fps full-resolution result quoted above.

Does not need the phone:

- `checkpatch.pl --strict` on `s5k4h8.c` and on `patches/0001` and
  `patches/0002`.
- `git am` of those two patches onto the pinned media commit.
- Compiling `drivers/media/i2c/s5k4h8.o` (CI does this on x86_64).

The ~24 fps figure and the 46/46 compliance result are from the perry
bring-up. They were not re-run for this packaging update. The only
driver change since that bring-up is the `v4l2_subdev_client_info`
argument on `set_fmt` and `get_selection`. Callers inside the driver
pass `NULL`. The argument is unused.

## Status and limitations

The series is ready to review and has not been mailed. Sending it to
`linux-media@vger.kernel.org` needs an explicit go. Board devicetree for
perry is intentionally absent until the binding is accepted.

`git am` of `patches/0001-*.patch` and `patches/0002-*.patch` applies
cleanly on media.git `next` at `aa0f4c41d487`. That was checked by
resetting a checkout to that commit, applying both patches, and
rebuilding `s5k4h8.o`.

linux-media's public tree is <https://git.linuxtv.org/media.git>. Its
integration branch is `next`. The kernel.org repository
`mchehab/linux-media` still has a branch named `master`; that tip is
Linux 5.9 from October 2020, which predates `v4l2-cci` and the subdev
API this driver uses. The previous series in this repo was generated
against a stand-in tree (a fake `MAINTAINERS` / `Kconfig` / `Makefile`
context), so those patches could not apply to a real media tree. The
files in `patches/` replace that series.

Before mailing, rebase onto the current
<https://gitlab.freedesktop.org/linux-media/media-committers.git>
`next` branch. The media maintainer profile asks for that baseline for
new drivers, and that branch can be rebased, so it is not the commit
stored here.

`checkpatch.pl --strict` from that media tree reports no errors,
warnings, or checks on `s5k4h8.c` or on either patch. `W=1` compile of
`s5k4h8.o` is clean. Running `checkpatch -f` on the standalone yaml
warns `EMBEDDED_FILENAME` because `$id` contains the filename. The same
line inside `patches/0001` is clean, which is how upstream bindings are
reviewed.

Still out of scope: OTP and AWB calibration, horizontal and vertical
flip, test pattern, and a perry dts. CI compiles the object on x86_64.
It does not boot a phone and it does not produce an ARM `s5k4h8.ko`.

## License

`LICENSE` is the full GNU GPL version 2 text. GitHub's license detector
matches that text as `GPL-2.0`. The previous file was a six-line stub,
which GitHub reports as `NOASSERTION`. Detection reads the default
branch, so the repository sidebar updates when this lands on `main`.

SPDX headers match the kernel's convention for this kind of submission:

- `s5k4h8.c` and the out-of-tree `Makefile` use `GPL-2.0`, the same tag
  as in-tree Samsung sensors such as `s5k3m5` and `s5kjn5`.
  `MODULE_LICENSE("GPL")` is the module-loader string those drivers use.
- `samsung,s5k4h8.yaml` uses `(GPL-2.0-only OR BSD-2-Clause)`, which
  devicetree bindings in the kernel are required to use. The binding is
  therefore also available under BSD-2-Clause. The project `LICENSE`
  file is GPL-2.0, which is one of the two grants on that file.

## Author

Aneesh Pradhan \<aneeshpradhan@acm.org\>
