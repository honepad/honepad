module honepad_json
  use iso_c_binding
  use iso_fortran_env, only: int64
  implicit none
  private
  public :: json_null_f, json_bool_f, json_int_f, json_str_f
  public :: json_arr_f, json_arr_push_f, json_obj_f, json_obj_put_f
  public :: json_obj_get_f, json_arr_len_f, json_arr_at_f
  public :: json_as_i64_f, json_as_str_f, json_stringify_f, json_free_f
  public :: json_clone_f, json_parse_f, read_file_f, json_free_cstr
  public :: json_is_arr, json_is_obj, json_is_str, json_is_null
  public :: arg_i64, arg_str, opt_i64, opt_str

  interface
    function hp_read_file(path) bind(C, name="hp_read_file")
      import c_ptr
      type(c_ptr), value :: path
      type(c_ptr) :: hp_read_file
    end function

    function hp_strlen(text) bind(C, name="hp_strlen")
      import c_ptr, c_size_t
      type(c_ptr), value :: text
      integer(c_size_t) :: hp_strlen
    end function

    subroutine hp_free_cstr(text) bind(C, name="hp_free_cstr")
      import c_ptr
      type(c_ptr), value :: text
    end subroutine

    function hp_parse(text, err, err_len) bind(C, name="hp_parse")
      import c_ptr, c_char, c_int
      type(c_ptr), value :: text
      character(kind=c_char) :: err(*)
      integer(c_int), value :: err_len
      type(c_ptr) :: hp_parse
    end function

    function hp_is_null(value) bind(C, name="hp_is_null")
      import c_ptr, c_int
      type(c_ptr), value :: value
      integer(c_int) :: hp_is_null
    end function

    function hp_is_arr(value) bind(C, name="hp_is_arr")
      import c_ptr, c_int
      type(c_ptr), value :: value
      integer(c_int) :: hp_is_arr
    end function

    function hp_is_obj(value) bind(C, name="hp_is_obj")
      import c_ptr, c_int
      type(c_ptr), value :: value
      integer(c_int) :: hp_is_obj
    end function

    function hp_is_str(value) bind(C, name="hp_is_str")
      import c_ptr, c_int
      type(c_ptr), value :: value
      integer(c_int) :: hp_is_str
    end function

    function hp_arr_len(value) bind(C, name="hp_arr_len")
      import c_ptr, c_int64_t
      type(c_ptr), value :: value
      integer(c_int64_t) :: hp_arr_len
    end function

    function hp_arr_at(value, index) bind(C, name="hp_arr_at")
      import c_ptr, c_int64_t
      type(c_ptr), value :: value
      integer(c_int64_t), value :: index
      type(c_ptr) :: hp_arr_at
    end function

    function hp_obj_get(value, key) bind(C, name="hp_obj_get")
      import c_ptr
      type(c_ptr), value :: value
      type(c_ptr), value :: key
      type(c_ptr) :: hp_obj_get
    end function

    function hp_as_str(value) bind(C, name="hp_as_str")
      import c_ptr
      type(c_ptr), value :: value
      type(c_ptr) :: hp_as_str
    end function

    function hp_as_i64(value) bind(C, name="hp_as_i64")
      import c_ptr, c_int64_t
      type(c_ptr), value :: value
      integer(c_int64_t) :: hp_as_i64
    end function

    function hp_null() bind(C, name="hp_null")
      import c_ptr
      type(c_ptr) :: hp_null
    end function

    function hp_bool(value) bind(C, name="hp_bool")
      import c_ptr, c_int
      integer(c_int), value :: value
      type(c_ptr) :: hp_bool
    end function

    function hp_int(value) bind(C, name="hp_int")
      import c_ptr, c_int64_t
      integer(c_int64_t), value :: value
      type(c_ptr) :: hp_int
    end function

    function hp_str(value) bind(C, name="hp_str")
      import c_ptr
      type(c_ptr), value :: value
      type(c_ptr) :: hp_str
    end function

    function hp_arr() bind(C, name="hp_arr")
      import c_ptr
      type(c_ptr) :: hp_arr
    end function

    subroutine hp_arr_push(arr, item) bind(C, name="hp_arr_push")
      import c_ptr
      type(c_ptr), value :: arr
      type(c_ptr), value :: item
    end subroutine

    function hp_obj() bind(C, name="hp_obj")
      import c_ptr
      type(c_ptr) :: hp_obj
    end function

    subroutine hp_obj_put(obj, key, val) bind(C, name="hp_obj_put")
      import c_ptr
      type(c_ptr), value :: obj
      type(c_ptr), value :: key
      type(c_ptr), value :: val
    end subroutine

    function hp_clone(value) bind(C, name="hp_clone")
      import c_ptr
      type(c_ptr), value :: value
      type(c_ptr) :: hp_clone
    end function

    function hp_stringify(value) bind(C, name="hp_stringify")
      import c_ptr
      type(c_ptr), value :: value
      type(c_ptr) :: hp_stringify
    end function

    subroutine hp_free(value) bind(C, name="hp_free")
      import c_ptr
      type(c_ptr), value :: value
    end subroutine

    function hp_arg_i64(args, index) bind(C, name="hp_arg_i64")
      import c_ptr, c_int64_t
      type(c_ptr), value :: args
      integer(c_int64_t), value :: index
      integer(c_int64_t) :: hp_arg_i64
    end function

    function hp_arg_str(args, index) bind(C, name="hp_arg_str")
      import c_ptr, c_int64_t
      type(c_ptr), value :: args
      integer(c_int64_t), value :: index
      type(c_ptr) :: hp_arg_str
    end function
  end interface

contains

  function copy_cstr(ptr) result(s)
    type(c_ptr), intent(in) :: ptr
    character(len=:), allocatable :: s
    integer(c_size_t) :: n
    character(kind=c_char), pointer :: chars(:)
    integer :: i
    if (.not. c_associated(ptr)) then
      s = ""
      return
    end if
    n = hp_strlen(ptr)
    if (n <= 0) then
      s = ""
      return
    end if
    call c_f_pointer(ptr, chars, [n])
    allocate (character(len=int(n)) :: s)
    do i = 1, int(n)
      s(i:i) = chars(i)
    end do
  end function

  subroutine fill_cstr(text, buf)
    character(len=*), intent(in) :: text
    character(kind=c_char), intent(out) :: buf(*)
    integer :: i, n
    n = len(text)
    do i = 1, n
      buf(i) = text(i:i)
    end do
    buf(n + 1) = c_null_char
  end subroutine

  function read_file_f(path) result(s)
    character(len=*), intent(in) :: path
    character(len=:), allocatable :: s
    character(kind=c_char), target :: buf(len(path) + 1)
    type(c_ptr) :: raw
    call fill_cstr(path, buf)
    raw = hp_read_file(c_loc(buf))
    if (.not. c_associated(raw)) then
      s = ""
      return
    end if
    s = copy_cstr(raw)
    call hp_free_cstr(raw)
  end function

  function json_parse_f(text) result(p)
    character(len=*), intent(in) :: text
    type(c_ptr) :: p
    character(kind=c_char), target :: buf(len(text) + 1)
    character(kind=c_char) :: err(256)
    integer :: i
    do i = 1, 256
      err(i) = c_null_char
    end do
    call fill_cstr(text, buf)
    p = hp_parse(c_loc(buf), err, 256)
  end function

  function json_null_f() result(p)
    type(c_ptr) :: p
    p = hp_null()
  end function

  function json_bool_f(value) result(p)
    logical, intent(in) :: value
    type(c_ptr) :: p
    if (value) then
      p = hp_bool(1_c_int)
    else
      p = hp_bool(0_c_int)
    end if
  end function

  function json_int_f(value) result(p)
    integer(int64), intent(in) :: value
    type(c_ptr) :: p
    p = hp_int(int(value, c_int64_t))
  end function

  function json_str_f(value) result(p)
    character(len=*), intent(in) :: value
    type(c_ptr) :: p
    character(kind=c_char), target :: buf(len(value) + 1)
    call fill_cstr(value, buf)
    p = hp_str(c_loc(buf))
  end function

  function json_arr_f() result(p)
    type(c_ptr) :: p
    p = hp_arr()
  end function

  subroutine json_arr_push_f(arr, item)
    type(c_ptr), intent(in) :: arr, item
    call hp_arr_push(arr, item)
  end subroutine

  function json_obj_f() result(p)
    type(c_ptr) :: p
    p = hp_obj()
  end function

  subroutine json_obj_put_f(obj, key, val)
    type(c_ptr), intent(in) :: obj, val
    character(len=*), intent(in) :: key
    character(kind=c_char), target :: buf(len(key) + 1)
    call fill_cstr(key, buf)
    call hp_obj_put(obj, c_loc(buf), val)
  end subroutine

  function json_obj_get_f(obj, key) result(p)
    type(c_ptr), intent(in) :: obj
    character(len=*), intent(in) :: key
    type(c_ptr) :: p
    character(kind=c_char), target :: buf(len(key) + 1)
    call fill_cstr(key, buf)
    p = hp_obj_get(obj, c_loc(buf))
  end function

  function json_arr_len_f(value) result(n)
    type(c_ptr), intent(in) :: value
    integer(int64) :: n
    n = hp_arr_len(value)
  end function

  function json_arr_at_f(value, index) result(p)
    type(c_ptr), intent(in) :: value
    integer(int64), intent(in) :: index
    type(c_ptr) :: p
    p = hp_arr_at(value, int(index, c_int64_t))
  end function

  function json_as_i64_f(value) result(n)
    type(c_ptr), intent(in) :: value
    integer(int64) :: n
    n = hp_as_i64(value)
  end function

  function json_as_str_f(value) result(s)
    type(c_ptr), intent(in) :: value
    character(len=:), allocatable :: s
    s = copy_cstr(hp_as_str(value))
  end function

  function json_stringify_f(value) result(s)
    type(c_ptr), intent(in) :: value
    character(len=:), allocatable :: s
    type(c_ptr) :: raw
    raw = hp_stringify(value)
    s = copy_cstr(raw)
    if (c_associated(raw)) then
      call hp_free_cstr(raw)
    end if
  end function

  subroutine json_free_f(value)
    type(c_ptr), intent(in) :: value
    if (c_associated(value)) then
      call hp_free(value)
    end if
  end subroutine

  subroutine json_free_cstr(value)
    type(c_ptr), intent(in) :: value
    if (c_associated(value)) then
      call hp_free_cstr(value)
    end if
  end subroutine

  function json_clone_f(value) result(p)
    type(c_ptr), intent(in) :: value
    type(c_ptr) :: p
    p = hp_clone(value)
  end function

  function json_is_arr(value) result(ok)
    type(c_ptr), intent(in) :: value
    logical :: ok
    ok = hp_is_arr(value) /= 0
  end function

  function json_is_obj(value) result(ok)
    type(c_ptr), intent(in) :: value
    logical :: ok
    ok = hp_is_obj(value) /= 0
  end function

  function json_is_str(value) result(ok)
    type(c_ptr), intent(in) :: value
    logical :: ok
    ok = hp_is_str(value) /= 0
  end function

  function json_is_null(value) result(ok)
    type(c_ptr), intent(in) :: value
    logical :: ok
    ok = hp_is_null(value) /= 0
  end function

  function arg_i64(args, index) result(n)
    type(c_ptr), intent(in) :: args
    integer, intent(in) :: index
    integer(int64) :: n
    n = hp_arg_i64(args, int(index, c_int64_t))
  end function

  function arg_str(args, index) result(s)
    type(c_ptr), intent(in) :: args
    integer, intent(in) :: index
    character(len=:), allocatable :: s
    s = copy_cstr(hp_arg_str(args, int(index, c_int64_t)))
  end function

  function opt_i64(present, value) result(p)
    logical, intent(in) :: present
    integer(int64), intent(in) :: value
    type(c_ptr) :: p
    if (present) then
      p = json_int_f(value)
    else
      p = json_null_f()
    end if
  end function

  function opt_str(present, value) result(p)
    logical, intent(in) :: present
    character(len=*), intent(in) :: value
    type(c_ptr) :: p
    if (present) then
      p = json_str_f(value)
    else
      p = json_null_f()
    end if
  end function
end module
