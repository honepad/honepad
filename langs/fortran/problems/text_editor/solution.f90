module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: snap_t
    character(len=:), allocatable :: buf
    integer(int64) :: pos = 0
  end type

  type :: sim_t
    character(len=:), allocatable :: buf
    integer(int64) :: pos = 0
    type(snap_t), allocatable :: undo(:)
    integer :: undo_n = 0
    type(snap_t), allocatable :: redo(:)
    integer :: redo_n = 0
    integer(int64) :: sel_start = -1
    integer(int64) :: sel_end = -1
    character(len=:), allocatable :: clip
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%buf)) deallocate (sim%buf)
    if (allocated(sim%undo)) deallocate (sim%undo)
    if (allocated(sim%redo)) deallocate (sim%redo)
    if (allocated(sim%clip)) deallocate (sim%clip)
    sim%buf = ""
    sim%clip = ""
    sim%pos = 0
    sim%undo_n = 0
    sim%redo_n = 0
    sim%sel_start = -1
    sim%sel_end = -1
  end subroutine

  function honepad_call(method, args, ok, err) result(out)
    character(len=*), intent(in) :: method
    type(c_ptr), intent(in) :: args
    logical, intent(out) :: ok
    character(len=*), intent(out) :: err
    type(c_ptr) :: out
    character(len=:), allocatable :: text
    ok = .true.
    err = ""
    if (.not. allocated(sim%buf)) sim%buf = ""
    if (.not. allocated(sim%clip)) sim%clip = ""
    if (method == "insert") then
      text = insert_at(arg_i64(args, 0), arg_str(args, 1))
    else if (method == "erase") then
      text = erase_at(arg_i64(args, 0), arg_i64(args, 1))
    else if (method == "get_text") then
      text = sim%buf
    else if (method == "length") then
      text = i64_text(int(len(sim%buf), int64))
    else if (method == "move") then
      text = move_to(arg_i64(args, 0))
    else if (method == "type_text") then
      text = type_text(arg_str(args, 0))
    else if (method == "cursor") then
      text = i64_text(sim%pos)
    else if (method == "undo") then
      text = undo_op()
    else if (method == "redo") then
      text = redo_op()
    else if (method == "select") then
      text = select_span(arg_i64(args, 0), arg_i64(args, 1))
    else if (method == "cut") then
      text = cut_sel()
    else if (method == "copy_sel") then
      text = copy_sel()
    else if (method == "paste") then
      text = paste_clip()
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  function i64_text(n) result(out)
    integer(int64), intent(in) :: n
    character(len=:), allocatable :: out
    character(len=32) :: buf
    write (buf, '(i0)') n
    out = trim(buf)
  end function

  integer function buf_len() result(n)
    n = 0
    if (allocated(sim%buf)) n = len(sim%buf)
  end function

  function slice(s, start0, n) result(out)
    character(len=*), intent(in) :: s
    integer(int64), intent(in) :: start0, n
    character(len=:), allocatable :: out
    integer :: a, b
    a = int(start0) + 1
    b = int(start0 + n)
    if (n <= 0 .or. a > len(s)) then
      out = ""
    else
      out = s(a:b)
    end if
  end function

  function splice(s, start0, n, extra) result(out)
    character(len=*), intent(in) :: s, extra
    integer(int64), intent(in) :: start0, n
    character(len=:), allocatable :: out
    integer :: a, b
    a = int(start0)
    b = int(start0 + n)
    if (a <= 0) then
      out = extra // s(b + 1:)
    else if (b >= len(s)) then
      out = s(1:a) // extra
    else
      out = s(1:a) // extra // s(b + 1:)
    end if
  end function

  subroutine grow_undo()
    type(snap_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%undo)) then
      allocate (sim%undo(8))
      return
    end if
    if (sim%undo_n < size(sim%undo)) return
    cap = size(sim%undo) * 2
    allocate (tmp(cap))
    tmp(1:sim%undo_n) = sim%undo(1:sim%undo_n)
    call move_alloc(tmp, sim%undo)
  end subroutine

  subroutine grow_redo()
    type(snap_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%redo)) then
      allocate (sim%redo(8))
      return
    end if
    if (sim%redo_n < size(sim%redo)) return
    cap = size(sim%redo) * 2
    allocate (tmp(cap))
    tmp(1:sim%redo_n) = sim%redo(1:sim%redo_n)
    call move_alloc(tmp, sim%redo)
  end subroutine

  subroutine push()
    call grow_undo()
    sim%undo_n = sim%undo_n + 1
    sim%undo(sim%undo_n)%buf = sim%buf
    sim%undo(sim%undo_n)%pos = sim%pos
    sim%redo_n = 0
    sim%sel_start = -1
    sim%sel_end = -1
  end subroutine

  function insert_at(at, text) result(out)
    integer(int64), intent(in) :: at
    character(len=*), intent(in) :: text
    character(len=:), allocatable :: out
    if (at < 0 .or. at > buf_len()) then
      out = "invalid_request"
      return
    end if
    call push()
    sim%buf = splice(sim%buf, at, 0_int64, text)
    out = i64_text(int(len(sim%buf), int64))
  end function

  function erase_at(at, n) result(out)
    integer(int64), intent(in) :: at, n
    character(len=:), allocatable :: out
    if (n <= 0 .or. at < 0 .or. at + n > buf_len()) then
      out = "invalid_request"
      return
    end if
    call push()
    out = slice(sim%buf, at, n)
    sim%buf = splice(sim%buf, at, n, "")
    if (sim%pos > buf_len()) sim%pos = int(buf_len(), int64)
  end function

  function move_to(at) result(out)
    integer(int64), intent(in) :: at
    character(len=:), allocatable :: out
    if (at < 0 .or. at > buf_len()) then
      out = "invalid_request"
      return
    end if
    sim%pos = at
    out = "true"
  end function

  function type_text(text) result(out)
    character(len=*), intent(in) :: text
    character(len=:), allocatable :: out
    integer(int64) :: at
    call push()
    at = sim%pos
    sim%buf = splice(sim%buf, at, 0_int64, text)
    sim%pos = at + len(text)
    out = i64_text(int(len(sim%buf), int64))
  end function

  function undo_op() result(out)
    character(len=:), allocatable :: out
    if (sim%undo_n == 0) then
      out = "false"
      return
    end if
    call grow_redo()
    sim%redo_n = sim%redo_n + 1
    sim%redo(sim%redo_n)%buf = sim%buf
    sim%redo(sim%redo_n)%pos = sim%pos
    sim%buf = sim%undo(sim%undo_n)%buf
    sim%pos = sim%undo(sim%undo_n)%pos
    sim%undo_n = sim%undo_n - 1
    sim%sel_start = -1
    sim%sel_end = -1
    out = "true"
  end function

  function redo_op() result(out)
    character(len=:), allocatable :: out
    if (sim%redo_n == 0) then
      out = "false"
      return
    end if
    call grow_undo()
    sim%undo_n = sim%undo_n + 1
    sim%undo(sim%undo_n)%buf = sim%buf
    sim%undo(sim%undo_n)%pos = sim%pos
    sim%buf = sim%redo(sim%redo_n)%buf
    sim%pos = sim%redo(sim%redo_n)%pos
    sim%redo_n = sim%redo_n - 1
    sim%sel_start = -1
    sim%sel_end = -1
    out = "true"
  end function

  function select_span(start, end_pos) result(out)
    integer(int64), intent(in) :: start, end_pos
    character(len=:), allocatable :: out
    if (start < 0 .or. end_pos < 0 .or. start > end_pos .or. end_pos > buf_len()) then
      out = "invalid_request"
      return
    end if
    sim%sel_start = start
    sim%sel_end = end_pos
    out = "true"
  end function

  function cut_sel() result(out)
    character(len=:), allocatable :: out
    integer(int64) :: n
    if (sim%sel_start < 0 .or. sim%sel_start == sim%sel_end) then
      out = "invalid_request"
      return
    end if
    n = sim%sel_end - sim%sel_start
    out = slice(sim%buf, sim%sel_start, n)
    sim%buf = splice(sim%buf, sim%sel_start, n, "")
    sim%clip = out
    sim%pos = sim%sel_start
    sim%sel_start = -1
    sim%sel_end = -1
  end function

  function copy_sel() result(out)
    character(len=:), allocatable :: out
    if (sim%sel_start < 0 .or. sim%sel_start == sim%sel_end) then
      out = "invalid_request"
      return
    end if
    sim%clip = slice(sim%buf, sim%sel_start, sim%sel_end - sim%sel_start)
    out = sim%clip
  end function

  function paste_clip() result(out)
    character(len=:), allocatable :: out
    integer(int64) :: at
    if (.not. allocated(sim%clip) .or. len(sim%clip) == 0) then
      out = "invalid_request"
      return
    end if
    at = sim%pos
    sim%buf = splice(sim%buf, at, 0_int64, sim%clip)
    sim%pos = at + len(sim%clip)
    out = i64_text(int(len(sim%buf), int64))
  end function
end module
