REM ffmpeg.exe -loglevel error -f concat -safe 0 -auto_convert 0 -i files.txt -c copy output.mp4
set "FILE=%1"
if "%FILE%"=="" set "FILE=files.txt"
ffmpeg.exe -fflags +genpts -f concat -safe 0 -i %FILE% -c copy -async 1 output-combine.mp4
