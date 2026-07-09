onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -r *
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
update
