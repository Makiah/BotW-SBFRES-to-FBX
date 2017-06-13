cd ToPNGConvert

FOR /r %%f in (*.*) do (
	"..\..\Libraries\ImageMagick\magick.exe" "%%f" -separate -swap 0,2 -combine "%%~nf.png"
)