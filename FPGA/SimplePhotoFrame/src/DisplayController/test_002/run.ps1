$ErrorActionPreference = 'Stop'

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $script_dir

$log_file = Join-Path $script_dir 'log.txt'
if( Test-Path $log_file ) {
	Remove-Item $log_file -Force
}

function Invoke-And-Log {
	param(
		[string]$Exe,
		[string[]]$CommandArgs
	)

	& $Exe @CommandArgs 2>&1 | Tee-Object -FilePath $log_file -Append
	if( $LASTEXITCODE -ne 0 ) {
		exit $LASTEXITCODE
	}
}

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] run.ps1 start" | Out-File -FilePath $log_file -Encoding ascii

if( Test-Path work ) {
	Remove-Item work -Recurse -Force
}

Invoke-And-Log -Exe 'vlib' -CommandArgs @('work')

$src_files = @(
	(Resolve-Path '..\display_single_port_ram.v').Path,
	(Resolve-Path '..\display_preload_buffer.v').Path,
	(Resolve-Path '..\display_timing_generator.v').Path,
	(Resolve-Path '..\display_address_generator.v').Path,
	(Resolve-Path '..\display_fillcolor_generator.v').Path,
	(Resolve-Path '..\display_controller.v').Path
)

foreach( $src in $src_files ) {
	Invoke-And-Log -Exe 'vlog' -CommandArgs @($src)
}

Invoke-And-Log -Exe 'vlog' -CommandArgs @('-sv', 'tb.sv')
Invoke-And-Log -Exe 'vsim' -CommandArgs @('-c', '-t', '1ps', 'tb', '-do', 'add wave -r *; run -all; quit -f')

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] run.ps1 done" | Tee-Object -FilePath $log_file -Append
exit 0
