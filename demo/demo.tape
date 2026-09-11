# honepad live console. Run demo/setup.sh first, then:
#   sed "s|__ROOT__|$PWD|g" demo/demo.tape > /tmp/honepad-demo.tape
#   vhs /tmp/honepad-demo.tape
Output "demo/demo.gif"
Set Shell bash
Set FontSize 16
Set Width 900
Set Height 560
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Set CursorBlink false
Set Framerate 25

Hide
Type "export HOME=__ROOT__/demo/home HONEPAD_ROOT=__ROOT__ PATH=__ROOT__/.venv/bin:$PATH"
Enter
Type "cd __ROOT__ && clear"
Enter
Type "honepad start bank_system python3"
Enter
Sleep 2s
Show

Sleep 2s
Type "1"
Sleep 5s
Type "q"
Sleep 1s
