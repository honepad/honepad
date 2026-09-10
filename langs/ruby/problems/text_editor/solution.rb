# frozen_string_literal: true

class Simulation
  def initialize
    @buf = ''
    @pos = 0
    @undo_stack = []
    @redo_stack = []
    @sel = nil
    @clip = ''
  end

  def insert(pos, text)
    return 'invalid_request' if pos < 0 || pos > @buf.length

    push
    @buf = @buf[0...pos] + text + @buf[pos..]
    @buf.length.to_s
  end

  def erase(pos, n)
    return 'invalid_request' if n <= 0 || pos < 0 || pos + n > @buf.length

    push
    deleted = @buf[pos, n]
    @buf = @buf[0...pos] + @buf[(pos + n)..]
    @pos = @buf.length if @pos > @buf.length
    deleted
  end

  def get_text
    @buf
  end

  def length
    @buf.length.to_s
  end

  def move(pos)
    return 'invalid_request' if pos < 0 || pos > @buf.length

    @pos = pos
    'true'
  end

  def type_text(text)
    push
    at = @pos
    @buf = @buf[0...at] + text + @buf[at..]
    @pos = at + text.length
    @buf.length.to_s
  end

  def cursor
    @pos.to_s
  end

  def undo
    return 'false' if @undo_stack.empty?

    @redo_stack << [@buf, @pos]
    @buf, @pos = @undo_stack.pop
    @sel = nil
    'true'
  end

  def redo
    return 'false' if @redo_stack.empty?

    @undo_stack << [@buf, @pos]
    @buf, @pos = @redo_stack.pop
    @sel = nil
    'true'
  end

  def select(start, end_)
    return 'invalid_request' if start < 0 || end_ < 0 || start > end_ || end_ > @buf.length

    @sel = [start, end_]
    'true'
  end

  def cut
    return 'invalid_request' if @sel.nil? || @sel[0] == @sel[1]

    start, end_ = @sel
    text = @buf[start...end_]
    @buf = @buf[0...start] + @buf[end_..]
    @clip = text
    @pos = start
    @sel = nil
    text
  end

  def copy_sel
    return 'invalid_request' if @sel.nil? || @sel[0] == @sel[1]

    start, end_ = @sel
    @clip = @buf[start...end_]
    @clip
  end

  def paste
    return 'invalid_request' if @clip == ''

    at = @pos
    @buf = @buf[0...at] + @clip + @buf[at..]
    @pos = at + @clip.length
    @buf.length.to_s
  end

  private

  def push
    @undo_stack << [@buf, @pos]
    @redo_stack.clear
    @sel = nil
  end
end
