import std.conv : to;

class EditorSnap
{
    string buf;
    long pos;

    this(string buf, long pos)
    {
        this.buf = buf;
        this.pos = pos;
    }
}

class Simulation
{
    string buf = "";
    long pos = 0;
    EditorSnap[] undoStack;
    EditorSnap[] redoStack;
    long selStart = -1;
    long selEnd = -1;
    string clip = "";

    private void push()
    {
        undoStack ~= new EditorSnap(buf, pos);
        redoStack.length = 0;
        selStart = -1;
        selEnd = -1;
    }

    string insert(long at, string text)
    {
        if (at < 0 || at > buf.length)
        {
            return "invalid_request";
        }
        push();
        buf = buf[0 .. at] ~ text ~ buf[at .. $];
        return buf.length.to!string;
    }

    string erase(long at, long n)
    {
        if (n <= 0 || at < 0 || at + n > buf.length)
        {
            return "invalid_request";
        }
        push();
        auto deleted = buf[at .. at + n];
        buf = buf[0 .. at] ~ buf[at + n .. $];
        if (pos > buf.length)
        {
            pos = buf.length;
        }
        return deleted;
    }

    string getText()
    {
        return buf;
    }

    string length()
    {
        return buf.length.to!string;
    }

    string move(long at)
    {
        if (at < 0 || at > buf.length)
        {
            return "invalid_request";
        }
        pos = at;
        return "true";
    }

    string typeText(string text)
    {
        push();
        auto at = pos;
        buf = buf[0 .. at] ~ text ~ buf[at .. $];
        pos = at + text.length;
        return buf.length.to!string;
    }

    string cursor()
    {
        return pos.to!string;
    }

    string undo()
    {
        if (undoStack.length == 0)
        {
            return "false";
        }
        redoStack ~= new EditorSnap(buf, pos);
        auto snap = undoStack[$ - 1];
        undoStack = undoStack[0 .. $ - 1];
        buf = snap.buf;
        pos = snap.pos;
        selStart = -1;
        selEnd = -1;
        return "true";
    }

    string redo()
    {
        if (redoStack.length == 0)
        {
            return "false";
        }
        undoStack ~= new EditorSnap(buf, pos);
        auto snap = redoStack[$ - 1];
        redoStack = redoStack[0 .. $ - 1];
        buf = snap.buf;
        pos = snap.pos;
        selStart = -1;
        selEnd = -1;
        return "true";
    }

    string select(long start, long end)
    {
        if (start < 0 || end < 0 || start > end || end > buf.length)
        {
            return "invalid_request";
        }
        selStart = start;
        selEnd = end;
        return "true";
    }

    string cut()
    {
        if (selStart < 0 || selStart == selEnd)
        {
            return "invalid_request";
        }
        auto text = buf[selStart .. selEnd];
        buf = buf[0 .. selStart] ~ buf[selEnd .. $];
        clip = text;
        pos = selStart;
        selStart = -1;
        selEnd = -1;
        return text;
    }

    string copySel()
    {
        if (selStart < 0 || selStart == selEnd)
        {
            return "invalid_request";
        }
        clip = buf[selStart .. selEnd];
        return clip;
    }

    string paste()
    {
        if (clip.length == 0)
        {
            return "invalid_request";
        }
        auto at = pos;
        buf = buf[0 .. at] ~ clip ~ buf[at .. $];
        pos = at + clip.length;
        return buf.length.to!string;
    }
}
