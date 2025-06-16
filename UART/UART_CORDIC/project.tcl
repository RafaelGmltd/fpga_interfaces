#-----------------------------------------------------------------------------------------------
# Automatically creates a Vivado project, adds source files, runs synthesis and implementation, generates the bitstream, and programs the FPGA.

# findFiles can find files in subdirs and add it into a list
proc findFiles { basedir pattern } {

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}
    array set myArray {}
    
    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty

    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
        lappend fileList $fileName
    }
    
    # Now look for any sub direcories in the current directory
    foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
        # Recusively call the routine on the sub directory and append any
        # new files to the results
        # put $dirName
        set subDirList [findFiles $dirName $pattern]
        if { [llength $subDirList] > 0 } {
            foreach subDirFile $subDirList {
                lappend fileList $subDirFile
            }
        }
    }
    return $fileList
}
#-----------------------------------------------------------------------------------------------
# Returns the path to the currently executing Tcl script
# Stores the resulting path into the variable TclPath.
# Copies the value of TclPath to another variable PrjDir.
set TclPath [file dirname [file normalize [info script]]]
set PrjDir $TclPath
#-----------------------------------------------------------------------------------------------
# Stage 1: Specify project settings 
set PartDev "xc7a35tcpg236-1"
# set PrjDir "C:/Work/prog/adm"
# It should match the name of the directory containing the script.
set TopName "UART_CORDIC"  
#-----------------------------------------------------------------------------------------------
# Stage 2: Auto-complete part for path
# Creates the project name with the .xpr extension.
set PrjName $TopName.xpr
# Generates the path to the directory containing the source files.
set SrcDir $PrjDir/src
# Defines a variable called vivado.
set VivNm "vivado"
# Creates the path to the vivado subfolder within the project.
set VivDir $PrjDir/$VivNm
#-----------------------------------------------------------------------------------------------
# Stage 3: Delete trash in project directory
cd $PrjDir
pwd

if {[file exists $VivNm] == 1} { 
    file delete -force $VivNm 
}
file mkdir $VivNm
cd $VivDir
#-----------------------------------------------------------------------------------------------
# Stage 4: Find sources: *.vhd, *.ngc *.xci *.xco *.xdc etc.
# This stage used instead of: add_files -scan_for_includes $SrcDir
set SrcSV  [findFiles $SrcDir "*.sv"  ]
set SrcVer [findFiles $SrcDir "*.v"   ]
set SrcXDC [findFiles $SrcDir "*.xdc" ]
#-----------------------------------------------------------------------------------------------
# Stage 5: Create project and add source files
create_project -force $TopName $VivDir -part $PartDev
set_property target_language VHDL [current_project]
# Add SV source files
add_files $SrcSV
# Add XDC source files
add_files -fileset constrs_1 -norecurse $SrcXDC
# Add Verilog source files
# add_files -norecurse $SrcVer
#-----------------------------------------------------------------------------------------------
# Stage 6: Run synthesis and implementation with bitstream generation
# netlist
launch_runs synth_1
wait_on_run synth_1
open_run synth_1 -name synth_1
# place & route
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1 -name impl_1
#-----------------------------------------------------------------------------------------------
# Stage 7: Search .bit and Create hw_bitstream 
set impl_dir "$VivDir/${TopName}.runs/impl_1"
set bit_file_list [glob -nocomplain -directory $impl_dir *.bit]
if {[llength $bit_file_list] == 0} {
    puts "ERROR: Bitstream not found in $impl_dir"
    exit 1
}
set bit_file [lindex $bit_file_list 0]

create_hw_bitstream -force $bit_file
#-----------------------------------------------------------------------------------------------
# Stage 8: Open hardware manager, connect, and program the device
open_hw_manager
connect_hw_server
open_hw_target
# Select the first available device in the chain
set my_device [lindex [get_hw_devices] 0]
# Assign the .bit file for programming
set_property PROGRAM.FILE $bit_file $my_device
# Ensure the device is active
current_hw_device $my_device
refresh_hw_device -update_hw_probes false $my_device
# Clear probe files for ILA (if previously set)
set_property PROBES.FILE {} $my_device
set_property FULL_PROBES.FILE {} $my_device
# Start programming the device
program_hw_devices $my_device
# Refresh the device status after programming
refresh_hw_device $my_device
