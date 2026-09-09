module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: key_t
    character(len=:), allocatable :: name
    integer(int64) :: limit = 3
    integer(int64) :: window = 10
    integer(int64) :: window_id = 0
    logical :: has_window = .false.
    integer(int64) :: used = 0
  end type

  type :: sim_t
    type(key_t), allocatable :: keys(:)
    integer :: key_n = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%keys)) deallocate (sim%keys)
    sim%key_n = 0
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
    if (method == "allow") then
      text = allow(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "configure") then
      text = configure(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2))
    else if (method == "remaining") then
      text = remaining(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "allow_weighted") then
      text = allow_weighted(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_key(name) result(idx)
    character(len=*), intent(in) :: name
    integer :: i
    idx = 0
    do i = 1, sim%key_n
      if (sim%keys(i)%name == name) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_keys()
    type(key_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%keys)) then
      allocate (sim%keys(8))
      return
    end if
    if (sim%key_n < size(sim%keys)) return
    cap = size(sim%keys) * 2
    allocate (tmp(cap))
    tmp(1:sim%key_n) = sim%keys(1:sim%key_n)
    call move_alloc(tmp, sim%keys)
  end subroutine

  integer function ensure_key(name) result(idx)
    character(len=*), intent(in) :: name
    idx = find_key(name)
    if (idx > 0) return
    call grow_keys()
    sim%key_n = sim%key_n + 1
    idx = sim%key_n
    sim%keys(idx)%name = name
    sim%keys(idx)%limit = 3
    sim%keys(idx)%window = 10
    sim%keys(idx)%window_id = 0
    sim%keys(idx)%has_window = .false.
    sim%keys(idx)%used = 0
  end function

  function used_at(idx, timestamp, persist) result(used)
    integer, intent(in) :: idx
    integer(int64), intent(in) :: timestamp
    logical, intent(in) :: persist
    integer(int64) :: used
    integer(int64) :: window_id
    window_id = timestamp / sim%keys(idx)%window
    if (.not. sim%keys(idx)%has_window .or. window_id /= sim%keys(idx)%window_id) then
      if (persist) then
        sim%keys(idx)%window_id = window_id
        sim%keys(idx)%has_window = .true.
        sim%keys(idx)%used = 0
      end if
      used = 0
      return
    end if
    used = sim%keys(idx)%used
  end function

  function allow(key, timestamp) result(out)
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: timestamp
    character(len=:), allocatable :: out
    out = allow_weighted(key, 1_int64, timestamp)
  end function

  function configure(key, limit, window) result(out)
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: limit, window
    character(len=:), allocatable :: out
    integer :: idx
    if (limit <= 0 .or. window <= 0) then
      out = "invalid_request"
      return
    end if
    idx = ensure_key(key)
    sim%keys(idx)%limit = limit
    sim%keys(idx)%window = window
    sim%keys(idx)%has_window = .false.
    sim%keys(idx)%used = 0
    out = "true"
  end function

  function remaining(key, timestamp) result(out)
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: timestamp
    character(len=:), allocatable :: out
    integer :: idx
    integer(int64) :: used
    character(len=32) :: buf
    idx = ensure_key(key)
    used = used_at(idx, timestamp, .false.)
    write (buf, '(i0)') sim%keys(idx)%limit - used
    out = trim(buf)
  end function

  function allow_weighted(key, cost, timestamp) result(out)
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: cost, timestamp
    character(len=:), allocatable :: out
    integer :: idx
    integer(int64) :: ignored
    if (cost <= 0) then
      out = "invalid_request"
      return
    end if
    idx = ensure_key(key)
    ignored = used_at(idx, timestamp, .true.)
    if (sim%keys(idx)%used + cost > sim%keys(idx)%limit) then
      out = "false"
      return
    end if
    sim%keys(idx)%used = sim%keys(idx)%used + cost
    out = "true"
  end function
end module
