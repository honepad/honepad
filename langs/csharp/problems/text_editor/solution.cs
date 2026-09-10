class EditorSnap
{
    public string Buf;
    public int Pos;

    public EditorSnap(string buf, int pos)
    {
        Buf = buf;
        Pos = pos;
    }
}

public class Simulation
{
    string buf = "";
    int pos;
    readonly List<EditorSnap> undoStack = new();
    readonly List<EditorSnap> redoStack = new();
    int selStart = -1;
    int selEnd = -1;
    string clip = "";

    public Simulation() { }

    void Push()
    {
        undoStack.Add(new EditorSnap(buf, pos));
        redoStack.Clear();
        selStart = -1;
        selEnd = -1;
    }

    public string Insert(int at, string text)
    {
        if (at < 0 || at > buf.Length)
        {
            return "invalid_request";
        }
        Push();
        buf = buf.Substring(0, at) + text + buf.Substring(at);
        return buf.Length.ToString();
    }

    public string Erase(int at, int n)
    {
        if (n <= 0 || at < 0 || at + n > buf.Length)
        {
            return "invalid_request";
        }
        Push();
        string deleted = buf.Substring(at, n);
        buf = buf.Substring(0, at) + buf.Substring(at + n);
        if (pos > buf.Length)
        {
            pos = buf.Length;
        }
        return deleted;
    }

    public string GetText()
    {
        return buf;
    }

    public string Length()
    {
        return buf.Length.ToString();
    }

    public string Move(int at)
    {
        if (at < 0 || at > buf.Length)
        {
            return "invalid_request";
        }
        pos = at;
        return "true";
    }

    public string TypeText(string text)
    {
        Push();
        int at = pos;
        buf = buf.Substring(0, at) + text + buf.Substring(at);
        pos = at + text.Length;
        return buf.Length.ToString();
    }

    public string Cursor()
    {
        return pos.ToString();
    }

    public string Undo()
    {
        if (undoStack.Count == 0)
        {
            return "false";
        }
        redoStack.Add(new EditorSnap(buf, pos));
        EditorSnap snap = undoStack[undoStack.Count - 1];
        undoStack.RemoveAt(undoStack.Count - 1);
        buf = snap.Buf;
        pos = snap.Pos;
        selStart = -1;
        selEnd = -1;
        return "true";
    }

    public string Redo()
    {
        if (redoStack.Count == 0)
        {
            return "false";
        }
        undoStack.Add(new EditorSnap(buf, pos));
        EditorSnap snap = redoStack[redoStack.Count - 1];
        redoStack.RemoveAt(redoStack.Count - 1);
        buf = snap.Buf;
        pos = snap.Pos;
        selStart = -1;
        selEnd = -1;
        return "true";
    }

    public string Select(int start, int end)
    {
        if (start < 0 || end < 0 || start > end || end > buf.Length)
        {
            return "invalid_request";
        }
        selStart = start;
        selEnd = end;
        return "true";
    }

    public string Cut()
    {
        if (selStart < 0 || selStart == selEnd)
        {
            return "invalid_request";
        }
        string text = buf.Substring(selStart, selEnd - selStart);
        buf = buf.Substring(0, selStart) + buf.Substring(selEnd);
        clip = text;
        pos = selStart;
        selStart = -1;
        selEnd = -1;
        return text;
    }

    public string CopySel()
    {
        if (selStart < 0 || selStart == selEnd)
        {
            return "invalid_request";
        }
        clip = buf.Substring(selStart, selEnd - selStart);
        return clip;
    }

    public string Paste()
    {
        if (clip.Length == 0)
        {
            return "invalid_request";
        }
        int at = pos;
        buf = buf.Substring(0, at) + clip + buf.Substring(at);
        pos = at + clip.Length;
        return buf.Length.ToString();
    }
}
