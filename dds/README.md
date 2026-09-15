# AXI DDS

本目录实现了一个 AXI4-Full 控制、独立 DDS 时钟运行的查表型 DDS。

模块层次与 Xilinx AXI 外设模板保持一致：

```text
axi_dds.v
└─ axi_dds_slave_full_v1_S00_AXI.v
   └─ dds_rom_core.v
      └─ dds_wave_rom（Xilinx Block Memory Generator IP）
```

顶层 `axi_dds.v` 只负责参数和端口透传；AXI 寄存器、跨时钟配置 mailbox
以及 DDS 核心实例都位于 `axi_dds_slave_full_v1_S00_AXI.v` 内。

## 数据通路

32 位相位累加器每个 `dds_aclk` 周期增加 `PHASE_INC`，加上相位偏移后取高
`ROM_ADDR_WIDTH` 位作为 ROM 地址。默认参数为：

- `PHASE_WIDTH = 32`
- `ROM_ADDR_WIDTH = 8`
- `OUTPUT_WIDTH = 16`

输出频率为：

```text
f_out = PHASE_INC * f_dds_clk / 2^PHASE_WIDTH
PHASE_INC = round(f_out * 2^PHASE_WIDTH / f_dds_clk)
```

`PHASE_OFFSET` 使用完整相位字，`0x80000000` 表示半周期（180°）。

## AXI 寄存器

所有寄存器宽度为 32 位。

| 偏移 | 名称 | 位 | 说明 |
|---:|---|---|---|
| `0x00` | CONTROL | bit 0 | 影子使能位 |
| `0x04` | PHASE_INC | 31:0 | 影子频率控制字 |
| `0x08` | PHASE_OFFSET | 31:0 | 影子相位偏移字 |
| `0x0C` | COMMAND | bit 0 | APPLY，写 1 发起配置更新 |
| `0x0C` | COMMAND | bit 1 | 与 APPLY 同时写 1，清零相位累加器 |
| `0x10` | STATUS | bit 0 | BUSY，跨时钟配置尚未确认 |
| `0x10` | STATUS | bit 1 | DDS 域实际使能状态 |
| `0x10` | STATUS | bit 2 | APPLY overrun；BUSY 时再次 APPLY 会置位，写 1 清除 |
| `0x14` | CAPABILITY | 7:0 | 输出位宽 |
| `0x14` | CAPABILITY | 15:8 | ROM 地址位宽 |
| `0x14` | CAPABILITY | 23:16 | 相位位宽 |
| `0x14` | CAPABILITY | 31:24 | 接口版本，当前为 1 |

推荐的软件更新顺序：

1. 等待 `STATUS.BUSY == 0`。
2. 写 CONTROL、PHASE_INC、PHASE_OFFSET。
3. 向 COMMAND 写 `1`；若需要从相位零点重新开始，则写 `3`。
4. 等待 `STATUS.BUSY == 0`，此时配置已在 DDS 域整体生效。

AXI 寄存器是影子值；APPLY 时会复制到专用 mailbox。即使 AXI 时钟与 DDS
时钟完全异步，多位频率字和相位字也不会被拆分采样。

## 生成 Xilinx ROM IP

在目标 Vivado 工程打开后执行：

```tcl
source <本目录>/ip/create_dds_wave_rom.tcl
```

脚本创建名为 `dds_wave_rom` 的 Xilinx Block Memory Generator
Single Port ROM。RTL 直接例化这个模块，端口必须保持为
`clka/ena/addra/douta`，并保持一拍读延迟。

自定义波形时，修改 `ip/waveform.coe` 中恰好一个周期的 256 个采样点，然后
重新生成 IP output products。改变采样点数量时，必须同时修改：

- `axi_dds` 的 `ROM_ADDR_WIDTH`；
- Tcl 脚本中的 `Write_Depth_A`；
- `.coe` 的采样点数量。

## 时序约束

`s00_axi_aclk` 与 `dds_aclk` 是异步时钟。工程级 XDC 应把两者声明为异步组，
例如将下列占位名称替换成设计中实际的时钟对象：

```tcl
set_clock_groups -asynchronous \
    -group [get_clocks <axi_clock_name>] \
    -group [get_clocks <dds_clock_name>]
```

CDC 同步寄存器已经带 `ASYNC_REG` 属性。配置多位总线由 request/acknowledge
协议保证在采样期间稳定，不应再单独对这些位增加同步寄存器。
