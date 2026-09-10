module Solution

type EditorSnap = { Buf: string; Pos: int }

type Simulation() =
    let mutable buf = ""
    let mutable pos = 0
    let undoStack = ResizeArray<EditorSnap>()
    let redoStack = ResizeArray<EditorSnap>()
    let mutable selStart = -1
    let mutable selEnd = -1
    let mutable clip = ""

    let push () =
        undoStack.Add({ Buf = buf; Pos = pos })
        redoStack.Clear()
        selStart <- -1
        selEnd <- -1

    member this.insert(at: int, text: string) : string =
        if at < 0 || at > buf.Length then
            "invalid_request"
        else
            push ()
            buf <- buf.Substring(0, at) + text + buf.Substring(at)
            string buf.Length

    member this.erase(at: int, n: int) : string =
        if n <= 0 || at < 0 || at + n > buf.Length then
            "invalid_request"
        else
            push ()
            let deleted = buf.Substring(at, n)
            buf <- buf.Substring(0, at) + buf.Substring(at + n)

            if pos > buf.Length then
                pos <- buf.Length

            deleted

    member this.getText() : string = buf

    member this.length() : string = string buf.Length

    member this.move(at: int) : string =
        if at < 0 || at > buf.Length then
            "invalid_request"
        else
            pos <- at
            "true"

    member this.typeText(text: string) : string =
        push ()
        let at = pos
        buf <- buf.Substring(0, at) + text + buf.Substring(at)
        pos <- at + text.Length
        string buf.Length

    member this.cursor() : string = string pos

    member this.undo() : string =
        if undoStack.Count = 0 then
            "false"
        else
            redoStack.Add({ Buf = buf; Pos = pos })
            let snap = undoStack[undoStack.Count - 1]
            undoStack.RemoveAt(undoStack.Count - 1)
            buf <- snap.Buf
            pos <- snap.Pos
            selStart <- -1
            selEnd <- -1
            "true"

    member this.redo() : string =
        if redoStack.Count = 0 then
            "false"
        else
            undoStack.Add({ Buf = buf; Pos = pos })
            let snap = redoStack[redoStack.Count - 1]
            redoStack.RemoveAt(redoStack.Count - 1)
            buf <- snap.Buf
            pos <- snap.Pos
            selStart <- -1
            selEnd <- -1
            "true"

    member this.select(start: int, endPos: int) : string =
        if start < 0 || endPos < 0 || start > endPos || endPos > buf.Length then
            "invalid_request"
        else
            selStart <- start
            selEnd <- endPos
            "true"

    member this.cut() : string =
        if selStart < 0 || selStart = selEnd then
            "invalid_request"
        else
            let text = buf.Substring(selStart, selEnd - selStart)
            buf <- buf.Substring(0, selStart) + buf.Substring(selEnd)
            clip <- text
            pos <- selStart
            selStart <- -1
            selEnd <- -1
            text

    member this.copySel() : string =
        if selStart < 0 || selStart = selEnd then
            "invalid_request"
        else
            clip <- buf.Substring(selStart, selEnd - selStart)
            clip

    member this.paste() : string =
        if clip.Length = 0 then
            "invalid_request"
        else
            let at = pos
            buf <- buf.Substring(0, at) + clip + buf.Substring(at)
            pos <- at + clip.Length
            string buf.Length
