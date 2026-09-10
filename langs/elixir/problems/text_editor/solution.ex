defmodule Simulation do
  defstruct buf: "", pos: 0, undo_stack: [], redo_stack: [], sel: nil, clip: ""

  def new, do: %__MODULE__{}

  defp push(sim) do
    %{sim | undo_stack: [{sim.buf, sim.pos} | sim.undo_stack], redo_stack: [], sel: nil}
  end

  def insert(sim, pos, text) do
    if pos < 0 or pos > String.length(sim.buf) do
      {"invalid_request", sim}
    else
      sim = push(sim)
      {left, right} = String.split_at(sim.buf, pos)
      buf = left <> text <> right
      {Integer.to_string(String.length(buf)), %{sim | buf: buf}}
    end
  end

  def erase(sim, pos, n) do
    if n <= 0 or pos < 0 or pos + n > String.length(sim.buf) do
      {"invalid_request", sim}
    else
      sim = push(sim)
      {left, rest} = String.split_at(sim.buf, pos)
      {deleted, right} = String.split_at(rest, n)
      buf = left <> right
      pos = if sim.pos > String.length(buf), do: String.length(buf), else: sim.pos
      {deleted, %{sim | buf: buf, pos: pos}}
    end
  end

  def get_text(sim), do: {sim.buf, sim}

  def length(sim), do: {Integer.to_string(String.length(sim.buf)), sim}

  def move(sim, pos) do
    if pos < 0 or pos > String.length(sim.buf) do
      {"invalid_request", sim}
    else
      {"true", %{sim | pos: pos}}
    end
  end

  def type_text(sim, text) do
    sim = push(sim)
    at = sim.pos
    {left, right} = String.split_at(sim.buf, at)
    buf = left <> text <> right
    pos = at + String.length(text)
    {Integer.to_string(String.length(buf)), %{sim | buf: buf, pos: pos}}
  end

  def cursor(sim), do: {Integer.to_string(sim.pos), sim}

  def undo(sim) do
    case sim.undo_stack do
      [] ->
        {"false", sim}

      [{buf, pos} | rest] ->
        {"true",
         %{
           sim
           | undo_stack: rest,
             redo_stack: [{sim.buf, sim.pos} | sim.redo_stack],
             buf: buf,
             pos: pos,
             sel: nil
         }}
    end
  end

  def redo(sim) do
    case sim.redo_stack do
      [] ->
        {"false", sim}

      [{buf, pos} | rest] ->
        {"true",
         %{
           sim
           | redo_stack: rest,
             undo_stack: [{sim.buf, sim.pos} | sim.undo_stack],
             buf: buf,
             pos: pos,
             sel: nil
         }}
    end
  end

  def select(sim, start, last) do
    if start < 0 or last < 0 or start > last or last > String.length(sim.buf) do
      {"invalid_request", sim}
    else
      {"true", %{sim | sel: {start, last}}}
    end
  end

  def cut(sim) do
    case sim.sel do
      nil ->
        {"invalid_request", sim}

      {start, last} when start == last ->
        {"invalid_request", sim}

      {start, last} ->
        {left, rest} = String.split_at(sim.buf, start)
        {text, right} = String.split_at(rest, last - start)
        buf = left <> right
        {text, %{sim | buf: buf, clip: text, pos: start, sel: nil}}
    end
  end

  def copy_sel(sim) do
    case sim.sel do
      nil ->
        {"invalid_request", sim}

      {start, last} when start == last ->
        {"invalid_request", sim}

      {start, last} ->
        {_left, rest} = String.split_at(sim.buf, start)
        {text, _right} = String.split_at(rest, last - start)
        {text, %{sim | clip: text}}
    end
  end

  def paste(sim) do
    if sim.clip == "" do
      {"invalid_request", sim}
    else
      at = sim.pos
      {left, right} = String.split_at(sim.buf, at)
      buf = left <> sim.clip <> right
      pos = at + String.length(sim.clip)
      {Integer.to_string(String.length(buf)), %{sim | buf: buf, pos: pos}}
    end
  end
end
