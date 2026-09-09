module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: backend_t
    character(len=:), allocatable :: backend_id
    logical :: health = .true.
    integer(int64) :: weight = 1
    integer(int64) :: inflight = 0
  end type

  type :: sticky_t
    character(len=:), allocatable :: client_id
    character(len=:), allocatable :: backend_id
  end type

  type :: sim_t
    type(backend_t), allocatable :: backends(:)
    integer :: backend_n = 0
    type(sticky_t), allocatable :: sticky(:)
    integer :: sticky_n = 0
    integer(int64) :: cursor = 0
    logical :: use_least = .false.
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%backends)) deallocate (sim%backends)
    if (allocated(sim%sticky)) deallocate (sim%sticky)
    sim%backend_n = 0
    sim%sticky_n = 0
    sim%cursor = 0
    sim%use_least = .false.
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
    if (method == "add_backend") then
      text = add_backend(arg_str(args, 0))
    else if (method == "route") then
      text = route()
    else if (method == "set_health") then
      text = set_health(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "set_weight") then
      text = set_weight(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "sticky") then
      text = sticky(arg_str(args, 0))
    else if (method == "done") then
      text = done_backend(arg_str(args, 0))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_backend(backend_id) result(idx)
    character(len=*), intent(in) :: backend_id
    integer :: i
    idx = 0
    do i = 1, sim%backend_n
      if (sim%backends(i)%backend_id == backend_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_backends()
    type(backend_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%backends)) then
      allocate (sim%backends(8))
      return
    end if
    if (sim%backend_n < size(sim%backends)) return
    cap = size(sim%backends) * 2
    allocate (tmp(cap))
    tmp(1:sim%backend_n) = sim%backends(1:sim%backend_n)
    call move_alloc(tmp, sim%backends)
  end subroutine

  subroutine grow_sticky()
    type(sticky_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%sticky)) then
      allocate (sim%sticky(8))
      return
    end if
    if (sim%sticky_n < size(sim%sticky)) return
    cap = size(sim%sticky) * 2
    allocate (tmp(cap))
    tmp(1:sim%sticky_n) = sim%sticky(1:sim%sticky_n)
    call move_alloc(tmp, sim%sticky)
  end subroutine

  subroutine reset_cycle()
    integer :: i
    sim%cursor = 0
    sim%use_least = .false.
    do i = 1, sim%backend_n
      sim%backends(i)%inflight = 0
    end do
  end subroutine

  function add_backend(backend_id) result(out)
    character(len=*), intent(in) :: backend_id
    character(len=:), allocatable :: out
    if (find_backend(backend_id) > 0) then
      out = "false"
      return
    end if
    call grow_backends()
    sim%backend_n = sim%backend_n + 1
    sim%backends(sim%backend_n)%backend_id = backend_id
    sim%backends(sim%backend_n)%health = .true.
    sim%backends(sim%backend_n)%weight = 1
    sim%backends(sim%backend_n)%inflight = 0
    out = "true"
  end function

  function set_health(backend_id, flag) result(out)
    character(len=*), intent(in) :: backend_id
    integer(int64), intent(in) :: flag
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_backend(backend_id)
    if (idx == 0 .or. (flag /= 0 .and. flag /= 1)) then
      out = "invalid_request"
      return
    end if
    sim%backends(idx)%health = flag == 1
    call reset_cycle()
    out = "true"
  end function

  function set_weight(backend_id, weight) result(out)
    character(len=*), intent(in) :: backend_id
    integer(int64), intent(in) :: weight
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_backend(backend_id)
    if (idx == 0 .or. weight <= 0) then
      out = "invalid_request"
      return
    end if
    sim%backends(idx)%weight = weight
    call reset_cycle()
    out = "true"
  end function

  integer function pick_idx() result(chosen)
    integer :: healthy(256)
    integer :: pool(256)
    integer :: tickets(1024)
    integer :: hn, pn, tn, i, n
    integer(int64) :: least
    hn = 0
    do i = 1, sim%backend_n
      if (sim%backends(i)%health) then
        hn = hn + 1
        healthy(hn) = i
      end if
    end do
    chosen = 0
    if (hn == 0) return
    pn = hn
    pool(1:hn) = healthy(1:hn)
    if (sim%use_least) then
      least = sim%backends(healthy(1))%inflight
      do i = 2, hn
        if (sim%backends(healthy(i))%inflight < least) then
          least = sim%backends(healthy(i))%inflight
        end if
      end do
      pn = 0
      do i = 1, hn
        if (sim%backends(healthy(i))%inflight == least) then
          pn = pn + 1
          pool(pn) = healthy(i)
        end if
      end do
    end if
    tn = 0
    do i = 1, pn
      do n = 1, int(sim%backends(pool(i))%weight)
        tn = tn + 1
        tickets(tn) = pool(i)
      end do
    end do
    if (tn == 0) return
    chosen = tickets(modulo(int(sim%cursor), tn) + 1)
    sim%cursor = sim%cursor + 1
  end function

  function take() result(out)
    character(len=:), allocatable :: out
    integer :: idx
    idx = pick_idx()
    if (idx == 0) then
      out = ""
      return
    end if
    sim%backends(idx)%inflight = sim%backends(idx)%inflight + 1
    out = sim%backends(idx)%backend_id
  end function

  function route() result(out)
    character(len=:), allocatable :: out
    out = take()
  end function

  integer function find_sticky(client_id) result(idx)
    character(len=*), intent(in) :: client_id
    integer :: i
    idx = 0
    do i = 1, sim%sticky_n
      if (sim%sticky(i)%client_id == client_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine sticky_set(client_id, backend_id)
    character(len=*), intent(in) :: client_id, backend_id
    integer :: idx
    idx = find_sticky(client_id)
    if (idx > 0) then
      sim%sticky(idx)%backend_id = backend_id
      return
    end if
    call grow_sticky()
    sim%sticky_n = sim%sticky_n + 1
    sim%sticky(sim%sticky_n)%client_id = client_id
    sim%sticky(sim%sticky_n)%backend_id = backend_id
  end subroutine

  function sticky(client_id) result(out)
    character(len=*), intent(in) :: client_id
    character(len=:), allocatable :: out
    integer :: sidx, bidx
    sidx = find_sticky(client_id)
    if (sidx > 0) then
      bidx = find_backend(sim%sticky(sidx)%backend_id)
      if (bidx > 0) then
        if (sim%backends(bidx)%health) then
          sim%backends(bidx)%inflight = sim%backends(bidx)%inflight + 1
          out = sim%backends(bidx)%backend_id
          return
        end if
      end if
    end if
    out = take()
    if (len(out) > 0) then
      call sticky_set(client_id, out)
    end if
  end function

  function done_backend(backend_id) result(out)
    character(len=*), intent(in) :: backend_id
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_backend(backend_id)
    if (idx == 0 .or. sim%backends(idx)%inflight <= 0) then
      out = "invalid_request"
      return
    end if
    sim%backends(idx)%inflight = sim%backends(idx)%inflight - 1
    sim%use_least = .true.
    out = "true"
  end function
end module
