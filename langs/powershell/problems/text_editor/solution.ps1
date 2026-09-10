class Simulation {
    [string] $Buf
    [int] $Pos
    [System.Collections.Generic.List[object]] $UndoStack
    [System.Collections.Generic.List[object]] $RedoStack
    [int] $SelStart
    [int] $SelEnd
    [string] $Clip

    Simulation() {
        $this.Buf = ''
        $this.Pos = 0
        $this.UndoStack = [System.Collections.Generic.List[object]]::new()
        $this.RedoStack = [System.Collections.Generic.List[object]]::new()
        $this.SelStart = -1
        $this.SelEnd = -1
        $this.Clip = ''
    }

    hidden [void] Push() {
        $this.UndoStack.Add(@($this.Buf, $this.Pos))
        $this.RedoStack.Clear()
        $this.SelStart = -1
        $this.SelEnd = -1
    }

    [object] insert([long] $At, [string] $Text) {
        if ($At -lt 0 -or $At -gt $this.Buf.Length) {
            return 'invalid_request'
        }
        $this.Push()
        $this.Buf = $this.Buf.Substring(0, [int]$At) + $Text + $this.Buf.Substring([int]$At)
        return [string]$this.Buf.Length
    }

    [object] erase([long] $At, [long] $N) {
        if ($N -le 0 -or $At -lt 0 -or ($At + $N) -gt $this.Buf.Length) {
            return 'invalid_request'
        }
        $this.Push()
        $deleted = $this.Buf.Substring([int]$At, [int]$N)
        $this.Buf = $this.Buf.Substring(0, [int]$At) + $this.Buf.Substring([int]($At + $N))
        if ($this.Pos -gt $this.Buf.Length) {
            $this.Pos = $this.Buf.Length
        }
        return $deleted
    }

    [object] getText() {
        return $this.Buf
    }

    [object] length() {
        return [string]$this.Buf.Length
    }

    [object] move([long] $At) {
        if ($At -lt 0 -or $At -gt $this.Buf.Length) {
            return 'invalid_request'
        }
        $this.Pos = [int]$At
        return 'true'
    }

    [object] typeText([string] $Text) {
        $this.Push()
        $at = $this.Pos
        $this.Buf = $this.Buf.Substring(0, $at) + $Text + $this.Buf.Substring($at)
        $this.Pos = $at + $Text.Length
        return [string]$this.Buf.Length
    }

    [object] cursor() {
        return [string]$this.Pos
    }

    [object] undo() {
        if ($this.UndoStack.Count -eq 0) {
            return 'false'
        }
        $this.RedoStack.Add(@($this.Buf, $this.Pos))
        $snap = $this.UndoStack[$this.UndoStack.Count - 1]
        $this.UndoStack.RemoveAt($this.UndoStack.Count - 1)
        $this.Buf = $snap[0]
        $this.Pos = [int]$snap[1]
        $this.SelStart = -1
        $this.SelEnd = -1
        return 'true'
    }

    [object] redo() {
        if ($this.RedoStack.Count -eq 0) {
            return 'false'
        }
        $this.UndoStack.Add(@($this.Buf, $this.Pos))
        $snap = $this.RedoStack[$this.RedoStack.Count - 1]
        $this.RedoStack.RemoveAt($this.RedoStack.Count - 1)
        $this.Buf = $snap[0]
        $this.Pos = [int]$snap[1]
        $this.SelStart = -1
        $this.SelEnd = -1
        return 'true'
    }

    [object] select([long] $Start, [long] $End) {
        if ($Start -lt 0 -or $End -lt 0 -or $Start -gt $End -or $End -gt $this.Buf.Length) {
            return 'invalid_request'
        }
        $this.SelStart = [int]$Start
        $this.SelEnd = [int]$End
        return 'true'
    }

    [object] cut() {
        if ($this.SelStart -lt 0 -or $this.SelStart -eq $this.SelEnd) {
            return 'invalid_request'
        }
        $text = $this.Buf.Substring($this.SelStart, $this.SelEnd - $this.SelStart)
        $this.Buf = $this.Buf.Substring(0, $this.SelStart) + $this.Buf.Substring($this.SelEnd)
        $this.Clip = $text
        $this.Pos = $this.SelStart
        $this.SelStart = -1
        $this.SelEnd = -1
        return $text
    }

    [object] copySel() {
        if ($this.SelStart -lt 0 -or $this.SelStart -eq $this.SelEnd) {
            return 'invalid_request'
        }
        $this.Clip = $this.Buf.Substring($this.SelStart, $this.SelEnd - $this.SelStart)
        return $this.Clip
    }

    [object] paste() {
        if ($this.Clip -eq '') {
            return 'invalid_request'
        }
        $at = $this.Pos
        $this.Buf = $this.Buf.Substring(0, $at) + $this.Clip + $this.Buf.Substring($at)
        $this.Pos = $at + $this.Clip.Length
        return [string]$this.Buf.Length
    }
}
