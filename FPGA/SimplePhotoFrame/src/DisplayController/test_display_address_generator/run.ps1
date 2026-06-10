$ErrorActionPreference = 'Stop'

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir

if( Test-Path work ) {
	Remove-Item work -Recurse -Force
}

& vlib work
if( $LASTEXITCODE -ne 0 ) {
	exit $LASTEXITCODE
}

$source = (Resolve-Path '..\display_address_generator.v').Path
& vlog $source
if( $LASTEXITCODE -ne 0 ) {
	exit $LASTEXITCODE
}

& vlog -sv tb.sv
if( $LASTEXITCODE -ne 0 ) {
	exit $LASTEXITCODE
}

& vsim -c -t 1ps tb -do "add wave -r *; run -all; quit -f"
exit $LASTEXITCODE