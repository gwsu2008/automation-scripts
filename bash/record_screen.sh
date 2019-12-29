# This code is under WTFPL (http://en.wikipedia.org/wiki/WTFPL)
# The code comes with no gaurantees of any kind though!
# Usage 
# record_screen.sh <time_in_seconds_to_record_screen> <folder_in_which_to_dump_movie_file>

start_recording_screen()
{
  result=`osascript -e \
      'set outfile to '$1'
      tell application "System Events"
           activate
           set UI elements enabled to true
       end tell
       tell application "QuickTime Player"
           activate
           close every window saving no
           new screen recording
           document "Screen Recording" start
           delay '$2'
           document "Screen Recording" stop
       end tell
       tell application "System Events"
        tell process "QuickTime Player"
           delay 1
           tell window 1
              keystroke "s" using {command down, shift down}
              delay 1 # wait for the sheet
              keystroke outfile
              delay 3
              key code 36
              delay 0.5
              key code 36
              delay 10 #wait for export
           end tell
        end tell
       end tell
       '`
  echo $result
}

TIME_TO_RECORD_SCREEN_FOR=${1}
FILE_TO_MOVE_SCREEN_RECORDING_TO="${2}/movie.mov"

start_recording_screen ${TIME_TO_RECORD_SCREEN_FOR} ${FOLDER_TO_MOVE_SCREEN_RECORDING_TO}

