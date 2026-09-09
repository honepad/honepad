module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: session_t
    integer(int64) :: start = 0
    integer(int64) :: end = 0
    integer(int64) :: rate = 0
    character(len=:), allocatable :: position
  end type

  type :: window_t
    integer(int64) :: first = 0
    integer(int64) :: last = 0
  end type

  type :: worker_t
    character(len=:), allocatable :: worker_id
    character(len=:), allocatable :: position
    integer(int64) :: compensation = 0
    logical :: in_office = .false.
    integer(int64) :: entered_at = 0
    type(session_t), allocatable :: finished(:)
    integer :: fin_n = 0
    logical :: has_promo = .false.
    character(len=:), allocatable :: promo_position
    integer(int64) :: promo_compensation = 0
    integer(int64) :: promo_start = 0
    type(window_t), allocatable :: double_pay(:)
    integer :: dp_n = 0
  end type

  type :: sim_t
    type(worker_t), allocatable :: workers(:)
    integer :: worker_n = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%workers)) deallocate (sim%workers)
    sim%worker_n = 0
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
    if (method == "add_worker") then
      text = add_worker(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2))
    else if (method == "register") then
      text = register_worker(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "get") then
      text = get_worker(arg_str(args, 0))
    else if (method == "top_n_workers") then
      text = top_n_workers(arg_i64(args, 0), arg_str(args, 1))
    else if (method == "promote") then
      text = promote(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2), arg_i64(args, 3))
    else if (method == "set_double_pay") then
      text = set_double_pay(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2))
    else if (method == "calc_salary") then
      text = calc_salary(arg_str(args, 0), arg_i64(args, 1), arg_i64(args, 2))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_worker(worker_id) result(idx)
    character(len=*), intent(in) :: worker_id
    integer :: i
    idx = 0
    do i = 1, sim%worker_n
      if (sim%workers(i)%worker_id == worker_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_workers()
    type(worker_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%workers)) then
      allocate (sim%workers(8))
      return
    end if
    if (sim%worker_n < size(sim%workers)) return
    cap = size(sim%workers) * 2
    allocate (tmp(cap))
    tmp(1:sim%worker_n) = sim%workers(1:sim%worker_n)
    call move_alloc(tmp, sim%workers)
  end subroutine

  subroutine grow_finished(worker)
    type(worker_t), intent(inout) :: worker
    type(session_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(worker%finished)) then
      allocate (worker%finished(4))
      return
    end if
    if (worker%fin_n < size(worker%finished)) return
    cap = size(worker%finished) * 2
    allocate (tmp(cap))
    tmp(1:worker%fin_n) = worker%finished(1:worker%fin_n)
    call move_alloc(tmp, worker%finished)
  end subroutine

  subroutine grow_double_pay(worker)
    type(worker_t), intent(inout) :: worker
    type(window_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(worker%double_pay)) then
      allocate (worker%double_pay(4))
      return
    end if
    if (worker%dp_n < size(worker%double_pay)) return
    cap = size(worker%double_pay) * 2
    allocate (tmp(cap))
    tmp(1:worker%dp_n) = worker%double_pay(1:worker%dp_n)
    call move_alloc(tmp, worker%double_pay)
  end subroutine

  integer(int64) function total_time(worker) result(total)
    type(worker_t), intent(in) :: worker
    integer :: i
    total = 0
    do i = 1, worker%fin_n
      total = total + worker%finished(i)%end - worker%finished(i)%start
    end do
  end function

  integer(int64) function position_time(worker, position) result(total)
    type(worker_t), intent(in) :: worker
    character(len=*), intent(in) :: position
    integer :: i
    total = 0
    do i = 1, worker%fin_n
      if (worker%finished(i)%position == position) then
        total = total + worker%finished(i)%end - worker%finished(i)%start
      end if
    end do
  end function

  subroutine apply_promo_on_enter(worker, timestamp)
    type(worker_t), intent(inout) :: worker
    integer(int64), intent(in) :: timestamp
    if (.not. worker%has_promo) return
    if (timestamp >= worker%promo_start) then
      worker%position = worker%promo_position
      worker%compensation = worker%promo_compensation
      worker%has_promo = .false.
    end if
  end subroutine

  function add_worker(worker_id, position, compensation) result(out)
    character(len=*), intent(in) :: worker_id, position
    integer(int64), intent(in) :: compensation
    character(len=:), allocatable :: out
    integer :: idx
    if (find_worker(worker_id) > 0) then
      out = "false"
      return
    end if
    call grow_workers()
    sim%worker_n = sim%worker_n + 1
    idx = sim%worker_n
    sim%workers(idx)%worker_id = worker_id
    sim%workers(idx)%position = position
    sim%workers(idx)%compensation = compensation
    sim%workers(idx)%in_office = .false.
    sim%workers(idx)%entered_at = 0
    sim%workers(idx)%fin_n = 0
    sim%workers(idx)%has_promo = .false.
    sim%workers(idx)%dp_n = 0
    if (allocated(sim%workers(idx)%finished)) deallocate (sim%workers(idx)%finished)
    if (allocated(sim%workers(idx)%double_pay)) deallocate (sim%workers(idx)%double_pay)
    out = "true"
  end function

  function register_worker(worker_id, timestamp) result(out)
    character(len=*), intent(in) :: worker_id
    integer(int64), intent(in) :: timestamp
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_worker(worker_id)
    if (idx == 0) then
      out = "invalid_request"
      return
    end if
    if (sim%workers(idx)%in_office) then
      call grow_finished(sim%workers(idx))
      sim%workers(idx)%fin_n = sim%workers(idx)%fin_n + 1
      sim%workers(idx)%finished(sim%workers(idx)%fin_n)%start = sim%workers(idx)%entered_at
      sim%workers(idx)%finished(sim%workers(idx)%fin_n)%end = timestamp
      sim%workers(idx)%finished(sim%workers(idx)%fin_n)%rate = sim%workers(idx)%compensation
      sim%workers(idx)%finished(sim%workers(idx)%fin_n)%position = sim%workers(idx)%position
      sim%workers(idx)%in_office = .false.
      out = "registered"
      return
    end if
    call apply_promo_on_enter(sim%workers(idx), timestamp)
    sim%workers(idx)%in_office = .true.
    sim%workers(idx)%entered_at = timestamp
    out = "registered"
  end function

  function get_worker(worker_id) result(out)
    character(len=*), intent(in) :: worker_id
    character(len=:), allocatable :: out
    integer :: idx
    character(len=32) :: buf
    idx = find_worker(worker_id)
    if (idx == 0) then
      out = ""
      return
    end if
    write (buf, '(i0)') total_time(sim%workers(idx))
    out = trim(buf)
  end function

  function top_n_workers(n, position) result(out)
    integer(int64), intent(in) :: n
    character(len=*), intent(in) :: position
    character(len=:), allocatable :: out
    integer :: i, j, count, take
    integer, allocatable :: order(:)
    integer :: tmp
    integer(int64) :: t_i, t_j
    character(len=:), allocatable :: piece
    character(len=32) :: buf
    allocate (order(sim%worker_n))
    count = 0
    do i = 1, sim%worker_n
      if (sim%workers(i)%position /= position) cycle
      count = count + 1
      order(count) = i
    end do
    do i = 1, count - 1
      do j = i + 1, count
        t_i = position_time(sim%workers(order(i)), position)
        t_j = position_time(sim%workers(order(j)), position)
        if (t_j > t_i .or. (t_j == t_i .and. sim%workers(order(j))%worker_id < sim%workers(order(i))%worker_id)) then
          tmp = order(i)
          order(i) = order(j)
          order(j) = tmp
        end if
      end do
    end do
    take = count
    if (n >= 0 .and. n < take) take = int(n)
    out = ""
    do i = 1, take
      write (buf, '(i0)') position_time(sim%workers(order(i)), position)
      piece = sim%workers(order(i))%worker_id // "(" // trim(buf) // ")"
      if (i == 1) then
        out = piece
      else
        out = out // ", " // piece
      end if
    end do
  end function

  function promote(worker_id, new_position, new_compensation, start_timestamp) result(out)
    character(len=*), intent(in) :: worker_id, new_position
    integer(int64), intent(in) :: new_compensation, start_timestamp
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_worker(worker_id)
    if (idx == 0 .or. sim%workers(idx)%has_promo) then
      out = "invalid_request"
      return
    end if
    sim%workers(idx)%promo_position = new_position
    sim%workers(idx)%promo_compensation = new_compensation
    sim%workers(idx)%promo_start = start_timestamp
    sim%workers(idx)%has_promo = .true.
    out = "success"
  end function

  integer(int64) function bonus_overlap(lo, hi, worker) result(total)
    integer(int64), intent(in) :: lo, hi
    type(worker_t), intent(in) :: worker
    type(window_t), allocatable :: segs(:), merged(:)
    integer :: i, n, m
    integer(int64) :: start, stop
    n = 0
    allocate (segs(max(worker%dp_n, 1)))
    do i = 1, worker%dp_n
      start = max(lo, worker%double_pay(i)%first)
      stop = min(hi, worker%double_pay(i)%last)
      if (stop > start) then
        n = n + 1
        segs(n)%first = start
        segs(n)%last = stop
      end if
    end do
    do i = 1, n - 1
      do m = i + 1, n
        if (segs(m)%first < segs(i)%first) then
          start = segs(i)%first
          stop = segs(i)%last
          segs(i) = segs(m)
          segs(m)%first = start
          segs(m)%last = stop
        end if
      end do
    end do
    m = 0
    allocate (merged(max(n, 1)))
    do i = 1, n
      if (m == 0 .or. segs(i)%first >= merged(m)%last) then
        m = m + 1
        merged(m) = segs(i)
      else
        merged(m)%last = max(merged(m)%last, segs(i)%last)
      end if
    end do
    total = 0
    do i = 1, m
      total = total + merged(i)%last - merged(i)%first
    end do
  end function

  function set_double_pay(worker_id, interval_begin, interval_end) result(out)
    character(len=*), intent(in) :: worker_id
    integer(int64), intent(in) :: interval_begin, interval_end
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_worker(worker_id)
    if (idx == 0 .or. interval_end <= interval_begin) then
      out = "invalid_request"
      return
    end if
    call grow_double_pay(sim%workers(idx))
    sim%workers(idx)%dp_n = sim%workers(idx)%dp_n + 1
    sim%workers(idx)%double_pay(sim%workers(idx)%dp_n)%first = interval_begin
    sim%workers(idx)%double_pay(sim%workers(idx)%dp_n)%last = interval_end
    out = "true"
  end function

  function calc_salary(worker_id, start_timestamp, end_timestamp) result(out)
    character(len=*), intent(in) :: worker_id
    integer(int64), intent(in) :: start_timestamp, end_timestamp
    character(len=:), allocatable :: out
    integer :: idx, i
    integer(int64) :: total, lo, hi, bonus
    character(len=32) :: buf
    idx = find_worker(worker_id)
    if (idx == 0) then
      out = ""
      return
    end if
    total = 0
    do i = 1, sim%workers(idx)%fin_n
      lo = max(sim%workers(idx)%finished(i)%start, start_timestamp)
      hi = min(sim%workers(idx)%finished(i)%end, end_timestamp)
      if (hi > lo) then
        bonus = bonus_overlap(lo, hi, sim%workers(idx))
        total = total + (hi - lo - bonus) * sim%workers(idx)%finished(i)%rate + bonus * &
          sim%workers(idx)%finished(i)%rate * 2
      end if
    end do
    write (buf, '(i0)') total
    out = trim(buf)
  end function
end module
