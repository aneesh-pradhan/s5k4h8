# Samsung S5K4H8 Camera Sensor Driver

Mainline Linux V4L2 sub-device driver for the Samsung S5K4H8 8 megapixel
CMOS image sensor with MIPI CSI-2 interface.

## Hardware

- **Sensor**: Samsung S5K4H8 (8 MP, 1/4" optical format)
- **Interface**: 4-lane MIPI CSI-2 D-PHY
- **Link frequency**: 280 MHz (560 Mbps/lane)
- **External clock**: 24 MHz MCLK
- **Output format**: SGRBG10 (RAW10)
- **Native resolution**: 3264×2448

## Supported Modes

| Mode | Resolution | Frame Rate | Notes |
|------|------------|------------|-------|
| Full | 3264×2448 | ~25 fps | Native array |
| Bin | 1632×1224 | ~30 fps | 2×2 binning |

## Controls

- Exposure (V4L2_CID_EXPOSURE)
- Analogue gain (V4L2_CID_ANALOGUE_GAIN)
- VBLANK (V4L2_CID_VBLANK)
- Link frequency (read-only)
- Pixel rate (read-only)
- fwnode Location/Rotation

## Provenance

Register programming sequences are adapted from the Rockchip vendor driver
(Fuzhou Rockchip Electronics Co., Ltd., 2017). Register I/O uses mainline
`v4l2-cci`.

The driver was developed for the Motorola Moto E4 (`perry`, MSM8917) and
tested with mainline CAMSS and libcamera (~24 fps full-resolution capture).

## Upstream Status

**Preparation series ready, not yet submitted.**

Patches in `patches/` are formatted for `linux-media`:

1. `0001-dt-bindings-...` — Device tree binding schema
2. `0002-media-i2c-...` — Driver implementation

These are **not yet mailed**. A new explicit go is required before
submission to `linux-media@vger.kernel.org`.

## Integration

### Device Tree

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

### Kernel Config

```
CONFIG_VIDEO_S5K4H8=m
```

## License

GPL-2.0-only. See [LICENSE](LICENSE).

Register tables adapted from Rockchip vendor driver (GPL-2.0).

## Author

Aneesh Pradhan \<aneeshpradhan@acm.org\>
