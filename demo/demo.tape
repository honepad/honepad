# Empty console -> start -> python3 -> bank -> L1 run/submit -> L4 win.
# L2 and L3 are hidden so the GIF can hold the firework.
#   bash demo/setup.sh
#   sed "s|__ROOT__|$PWD|g" demo/demo.tape > /tmp/honepad-demo.tape
#   vhs /tmp/honepad-demo.tape   # use vhs 0.11.0
Output "demo/demo.gif"
Set Shell bash
Set FontSize 15
Set Width 960
Set Height 640
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Set CursorBlink false
Set Framerate 25

Hide
Type "export HOME=__ROOT__/demo/home HONEPAD_ROOT=__ROOT__ PATH=__ROOT__/.venv/bin:$PATH FORCE_COLOR=1"
Enter
Type "cd __ROOT__ && bash demo/keep-solution.sh >/dev/null 2>&1 & clear"
Enter
Sleep 400ms
Show

Sleep 1400ms
Type "honepad start"
Enter
Sleep 2200ms
Type "python3"
Enter
Sleep 2000ms
Type "bank"
Enter
Sleep 2800ms
Type "1"
Sleep 3500ms
Type "2"
Sleep 500ms
Type "y"
Sleep 4000ms

Hide
Type "1"
Sleep 2800ms
Type "2"
Sleep 400ms
Type "y"
Sleep 3200ms
Type "1"
Sleep 2800ms
Type "2"
Sleep 400ms
Type "y"
Sleep 3200ms
Show

Sleep 800ms
Type "1"
Sleep 3500ms
Type "2"
Sleep 5.5s
