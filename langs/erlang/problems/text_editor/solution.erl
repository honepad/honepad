-module('Simulation').

-export([
    new/0,
    insert/3,
    erase/3,
    get_text/1,
    length/1,
    move/2,
    type_text/2,
    cursor/1,
    undo/1,
    redo/1,
    select/3,
    cut/1,
    copy_sel/1,
    paste/1
]).

new() ->
    #{
        buf => <<>>,
        pos => 0,
        undo_stack => [],
        redo_stack => [],
        sel => undefined,
        clip => <<>>
    }.

push(Sim) ->
    Snap = {maps:get(buf, Sim), maps:get(pos, Sim)},
    Sim#{
        undo_stack := [Snap | maps:get(undo_stack, Sim)],
        redo_stack := [],
        sel := undefined
    }.

insert(Sim, Pos, Text) ->
    Buf = maps:get(buf, Sim),
    Len = byte_size(Buf),
    if
        Pos < 0; Pos > Len ->
            {<<"invalid_request">>, Sim};
        true ->
            Sim1 = push(Sim),
            TextBin = to_bin(Text),
            <<Left:Pos/binary, Right/binary>> = maps:get(buf, Sim1),
            Buf1 = <<Left/binary, TextBin/binary, Right/binary>>,
            {integer_to_binary(byte_size(Buf1)), Sim1#{buf := Buf1}}
    end.

erase(Sim, Pos, N) ->
    Buf = maps:get(buf, Sim),
    Len = byte_size(Buf),
    if
        N =< 0; Pos < 0; Pos + N > Len ->
            {<<"invalid_request">>, Sim};
        true ->
            Sim1 = push(Sim),
            <<Left:Pos/binary, Rest/binary>> = maps:get(buf, Sim1),
            <<Deleted:N/binary, Right/binary>> = Rest,
            Buf1 = <<Left/binary, Right/binary>>,
            Pos1 =
                case maps:get(pos, Sim1) > byte_size(Buf1) of
                    true -> byte_size(Buf1);
                    false -> maps:get(pos, Sim1)
                end,
            {Deleted, Sim1#{buf := Buf1, pos := Pos1}}
    end.

get_text(Sim) ->
    {maps:get(buf, Sim), Sim}.

length(Sim) ->
    {integer_to_binary(byte_size(maps:get(buf, Sim))), Sim}.

move(Sim, Pos) ->
    Len = byte_size(maps:get(buf, Sim)),
    if
        Pos < 0; Pos > Len -> {<<"invalid_request">>, Sim};
        true -> {<<"true">>, Sim#{pos := Pos}}
    end.

type_text(Sim, Text) ->
    Sim1 = push(Sim),
    At = maps:get(pos, Sim1),
    TextBin = to_bin(Text),
    <<Left:At/binary, Right/binary>> = maps:get(buf, Sim1),
    Buf1 = <<Left/binary, TextBin/binary, Right/binary>>,
    {integer_to_binary(byte_size(Buf1)), Sim1#{buf := Buf1, pos := At + byte_size(TextBin)}}.

cursor(Sim) ->
    {integer_to_binary(maps:get(pos, Sim)), Sim}.

undo(Sim) ->
    case maps:get(undo_stack, Sim) of
        [] ->
            {<<"false">>, Sim};
        [{Buf, Pos} | Rest] ->
            Redo = [{maps:get(buf, Sim), maps:get(pos, Sim)} | maps:get(redo_stack, Sim)],
            {<<"true">>, Sim#{
                undo_stack := Rest,
                redo_stack := Redo,
                buf := Buf,
                pos := Pos,
                sel := undefined
            }}
    end.

redo(Sim) ->
    case maps:get(redo_stack, Sim) of
        [] ->
            {<<"false">>, Sim};
        [{Buf, Pos} | Rest] ->
            Undo = [{maps:get(buf, Sim), maps:get(pos, Sim)} | maps:get(undo_stack, Sim)],
            {<<"true">>, Sim#{
                redo_stack := Rest,
                undo_stack := Undo,
                buf := Buf,
                pos := Pos,
                sel := undefined
            }}
    end.

select(Sim, Start, Last) ->
    Len = byte_size(maps:get(buf, Sim)),
    if
        Start < 0; Last < 0; Start > Last; Last > Len ->
            {<<"invalid_request">>, Sim};
        true ->
            {<<"true">>, Sim#{sel := {Start, Last}}}
    end.

cut(Sim) ->
    case maps:get(sel, Sim) of
        undefined ->
            {<<"invalid_request">>, Sim};
        {Start, Last} when Start =:= Last ->
            {<<"invalid_request">>, Sim};
        {Start, Last} ->
            N = Last - Start,
            <<Left:Start/binary, Rest/binary>> = maps:get(buf, Sim),
            <<Text:N/binary, Right/binary>> = Rest,
            Buf1 = <<Left/binary, Right/binary>>,
            {Text, Sim#{buf := Buf1, clip := Text, pos := Start, sel := undefined}}
    end.

copy_sel(Sim) ->
    case maps:get(sel, Sim) of
        undefined ->
            {<<"invalid_request">>, Sim};
        {Start, Last} when Start =:= Last ->
            {<<"invalid_request">>, Sim};
        {Start, Last} ->
            N = Last - Start,
            <<_:Start/binary, Rest/binary>> = maps:get(buf, Sim),
            <<Text:N/binary, _/binary>> = Rest,
            {Text, Sim#{clip := Text}}
    end.

paste(Sim) ->
    Clip = maps:get(clip, Sim),
    case Clip of
        <<>> ->
            {<<"invalid_request">>, Sim};
        _ ->
            At = maps:get(pos, Sim),
            <<Left:At/binary, Right/binary>> = maps:get(buf, Sim),
            Buf1 = <<Left/binary, Clip/binary, Right/binary>>,
            {integer_to_binary(byte_size(Buf1)), Sim#{buf := Buf1, pos := At + byte_size(Clip)}}
    end.

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> list_to_binary(L).
