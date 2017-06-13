You need approx. 3 gb and 10 minutes to extract all files from a gcm...

At first, run
> gcmdump supermariosunshine.gcm
to extract the files from the gcm disk image to your harddrive.

Then, copy "yaz0dec.exe" and "rarcdump.exe" into the "data" and "data/scene" subdirs of your supermariosunshine.gcm_dir. In these directories, run
> for %i in (*.szs) do yaz0dec "%i"
> for %i in (*.rarc) do rarcdump "%i"
to first unpack all szs files and then extract them from the .rarc files (the above commands work with WinXP cmd.exe, for Win98 you may have to modify the syntax).

Bye,
thakis (http://www.amnoid.de/gc/)

Version 1.0 20050213