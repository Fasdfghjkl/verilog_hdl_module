# Run inside an open Vivado project:
#   source <repository>/ip/create_dds_wave_rom.tcl
#
# The HDL expects a native single-port ROM named "dds_wave_rom" with one-cycle
# read latency and ports clka/ena/addra/douta.

set script_dir [file dirname [file normalize [info script]]]
set coe_file   [file normalize [file join $script_dir waveform.coe]]

if {[llength [get_ips -quiet dds_wave_rom]] != 0} {
    error "IP dds_wave_rom already exists; remove or rename it before sourcing this script"
}

create_ip -name blk_mem_gen \
          -vendor xilinx.com \
          -library ip \
          -version 8.4 \
          -module_name dds_wave_rom

set_property -dict [list \
    CONFIG.Interface_Type {Native} \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Write_Width_A {16} \
    CONFIG.Write_Depth_A {256} \
    CONFIG.Read_Width_A {16} \
    CONFIG.Enable_A {Use_ENA_Pin} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortA_Output_of_Memory_Core {false} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File $coe_file \
    CONFIG.Fill_Remaining_Memory_Locations {true} \
    CONFIG.Remaining_Memory_Locations {0} \
] [get_ips dds_wave_rom]

generate_target all [get_ips dds_wave_rom]

puts "Created dds_wave_rom: 256 x 16-bit, one-cycle synchronous read"
puts "Waveform source: $coe_file"
