#Include Chrome.ahk

#Persistent  ; Keep the script running
SetTitleMatchMode, 2  ; Matches window titles containing the specified value

chromePath := "C:\Program Files\Google\Chrome\Application\chrome.exe"
profilePath := "--profile-directory=Default"  ; Modify "Profile 3" to your profile's name
url := "https://www.patreon.com/MonzterDEV"

; Launch Chrome with the specified profile
Run, %chromePath% %profilePath%

return
