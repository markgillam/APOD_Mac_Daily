#!/bin/sh
# picture rotation, random order, and change interval are not supported in MacOS 26(maybe, so disabled)
/usr/bin/osascript <<END
tell application "System Events"
	tell every desktop
		-- set picture rotation to 1 -- 0=off | 1=interval | 2=login | 3=sleep
		-- set random order to true
		set pictures folder to "/Library/Desktop Pictures"
		-- set change interval to 3600 -- seconds
	end tell
end tell
END
