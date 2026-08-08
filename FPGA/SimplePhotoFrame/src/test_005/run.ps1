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

$support_files = @(
	'gowin_rpll.v',
	'MT48LC2M32B2.v'
)

foreach( $support_file in $support_files ) {
	& vlog $support_file
	if( $LASTEXITCODE -ne 0 ) {
		exit $LASTEXITCODE
	}
}

$project_path = (Resolve-Path '..\..\SimplePhotoFrame.gprj').Path
$project_dir = Split-Path -Parent $project_path
$project_lines = Get-Content $project_path
$skip_names = @(
	'gowin_rpll.v',
	'gowin_rpll2.v',
	'gowin_clkdiv.v'
)

foreach( $line in $project_lines ) {
	if( $line -notmatch '<File path="([^"]+)" type="([^"]+)" enable="([^"]+)"' ) {
		continue
	}

	$relative_path = $Matches[1]
	$file_type = $Matches[2]
	$enabled = $Matches[3]

	if( $enabled -ne '1' ) {
		continue
	}

	if( $file_type -ne 'file.verilog' -and $file_type -ne 'file.systemverilog' ) {
		continue
	}

	$source_name = [System.IO.Path]::GetFileName( $relative_path )
	if( $skip_names -contains $source_name ) {
		continue
	}

	$source_path = (Resolve-Path (Join-Path $project_dir $relative_path)).Path
	& vlog $source_path
	if( $LASTEXITCODE -ne 0 ) {
		exit $LASTEXITCODE
	}
}

& vlog -sv tb.sv
if( $LASTEXITCODE -ne 0 ) {
	exit $LASTEXITCODE
}

vsim -c -t 1ps -voptargs=+acc tb -do "do wave.do; run -all; quit -f"
if( Test-Path log.txt ) {
	Remove-Item log.txt -Force
}

if( Test-Path transcript ) {
	Move-Item transcript log.txt -Force
}

exit $LASTEXITCODE