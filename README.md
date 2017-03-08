# MIDI-to-CV
MIDI-to-CV conversion for Microchip 16F873A with code and schematic

converts MIDI notes to a Control Voltage using a DAC such as the DAC0808.  Works with controllers that use Active Sensing.  Ignores everything except notes, in other words no pitch bend, program changes, etc.  You must select the channel you want read on the dip switches before powering on, as this is only read once at start up.  LED is not necessary, it was an initial test to make sure code was downloaded and being read correctly by chip.  Timing blip was used to ensure correct reading of MIDI word on an oscilloscope.  

the general concept, as I only wanted to use a 4 MHz crystal, was to parse all unwanted MIDI commands in the short time before the next possible MIDI word using a flag-like "status number" that could be added to as each test was performed, then depending on the result of that status, the appropriate action would be taken.  Also, as I had to be prepared always for running status commands, the cycle either does a "half" or "full" loop depending on whether running status was in use.  

youtube vid:  https://youtu.be/QxDWno2Q0B4
