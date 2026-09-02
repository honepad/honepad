module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  integer(int64), parameter :: cashback_delay = 24_int64 * 60_int64 * 60_int64 * 1000_int64

  type :: pay_row
    character(len=:), allocatable :: id
    character(len=:), allocatable :: status
  end type

  type :: bal_row
    integer(int64) :: timestamp = 0
    integer(int64) :: balance = 0
  end type

  type :: account_t
    character(len=:), allocatable :: id
    integer(int64) :: balance = 0
    integer(int64) :: outgoing = 0
    integer(int64) :: created_at = 0
    type(pay_row), allocatable :: payments(:)
    integer :: pay_n = 0
    type(bal_row), allocatable :: history(:)
    integer :: hist_n = 0
  end type

  type :: cashback_t
    integer(int64) :: timestamp = 0
    integer(int64) :: amount = 0
    character(len=:), allocatable :: account_id
    character(len=:), allocatable :: payment_id
  end type

  type :: sim_t
    type(account_t), allocatable :: accounts(:)
    integer :: acc_n = 0
    integer(int64) :: payment_counter = 0
    type(cashback_t), allocatable :: pending(:)
    integer :: pend_n = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%accounts)) deallocate (sim%accounts)
    if (allocated(sim%pending)) deallocate (sim%pending)
    sim%acc_n = 0
    sim%payment_counter = 0
    sim%pend_n = 0
  end subroutine

  function honepad_call(method, args, ok, err) result(out)
    character(len=*), intent(in) :: method
    type(c_ptr), intent(in) :: args
    logical, intent(out) :: ok
    character(len=*), intent(out) :: err
    type(c_ptr) :: out
    integer(int64) :: value
    logical :: present
    character(len=:), allocatable :: text
    ok = .true.
    err = ""
    out = c_null_ptr
    if (method == "create_account") then
      out = json_bool_f(create_account(arg_i64(args, 0), arg_str(args, 1)))
    else if (method == "deposit") then
      present = deposit(arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2), value)
      out = opt_i64(present, value)
    else if (method == "transfer") then
      present = transfer(arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2), arg_i64(args, 3), value)
      out = opt_i64(present, value)
    else if (method == "top_spenders") then
      out = top_spenders(arg_i64(args, 0), arg_i64(args, 1))
    else if (method == "pay") then
      present = pay(arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2), text)
      out = opt_str(present, text)
    else if (method == "get_payment_status") then
      present = get_payment_status(arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2), text)
      out = opt_str(present, text)
    else if (method == "merge_accounts") then
      out = json_bool_f(merge_accounts(arg_i64(args, 0), arg_str(args, 1), arg_str(args, 2)))
    else if (method == "get_balance") then
      present = get_balance(arg_i64(args, 0), arg_str(args, 1), arg_i64(args, 2), value)
      out = opt_i64(present, value)
    else
      ok = .false.
      err = "missing method " // trim(method)
    end if
  end function

  integer function find_account(account_id) result(idx)
    character(len=*), intent(in) :: account_id
    integer :: i
    idx = 0
    do i = 1, sim%acc_n
      if (sim%accounts(i)%id == account_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_accounts()
    type(account_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%accounts)) then
      allocate (sim%accounts(8))
      return
    end if
    if (sim%acc_n < size(sim%accounts)) return
    cap = size(sim%accounts) * 2
    allocate (tmp(cap))
    tmp(1:sim%acc_n) = sim%accounts(1:sim%acc_n)
    call move_alloc(tmp, sim%accounts)
  end subroutine

  subroutine grow_pending()
    type(cashback_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%pending)) then
      allocate (sim%pending(8))
      return
    end if
    if (sim%pend_n < size(sim%pending)) return
    cap = size(sim%pending) * 2
    allocate (tmp(cap))
    tmp(1:sim%pend_n) = sim%pending(1:sim%pend_n)
    call move_alloc(tmp, sim%pending)
  end subroutine

  subroutine grow_pays(acc)
    type(account_t), intent(inout) :: acc
    type(pay_row), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(acc%payments)) then
      allocate (acc%payments(4))
      return
    end if
    if (acc%pay_n < size(acc%payments)) return
    cap = size(acc%payments) * 2
    allocate (tmp(cap))
    tmp(1:acc%pay_n) = acc%payments(1:acc%pay_n)
    call move_alloc(tmp, acc%payments)
  end subroutine

  subroutine grow_hist(acc)
    type(account_t), intent(inout) :: acc
    type(bal_row), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(acc%history)) then
      allocate (acc%history(8))
      return
    end if
    if (acc%hist_n < size(acc%history)) return
    cap = size(acc%history) * 2
    allocate (tmp(cap))
    tmp(1:acc%hist_n) = acc%history(1:acc%hist_n)
    call move_alloc(tmp, acc%history)
  end subroutine

  subroutine record_balance(acc, timestamp)
    type(account_t), intent(inout) :: acc
    integer(int64), intent(in) :: timestamp
    call grow_hist(acc)
    acc%hist_n = acc%hist_n + 1
    acc%history(acc%hist_n)%timestamp = timestamp
    acc%history(acc%hist_n)%balance = acc%balance
  end subroutine

  subroutine set_payment(acc, payment_id, status)
    type(account_t), intent(inout) :: acc
    character(len=*), intent(in) :: payment_id, status
    integer :: i
    do i = 1, acc%pay_n
      if (acc%payments(i)%id == payment_id) then
        acc%payments(i)%status = status
        return
      end if
    end do
    call grow_pays(acc)
    acc%pay_n = acc%pay_n + 1
    acc%payments(acc%pay_n)%id = payment_id
    acc%payments(acc%pay_n)%status = status
  end subroutine

  integer function find_payment(acc, payment_id) result(idx)
    type(account_t), intent(in) :: acc
    character(len=*), intent(in) :: payment_id
    integer :: i
    idx = 0
    do i = 1, acc%pay_n
      if (acc%payments(i)%id == payment_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine process_cashbacks(timestamp)
    integer(int64), intent(in) :: timestamp
    integer :: acc_idx, i
    do while (sim%pend_n > 0)
      if (sim%pending(1)%timestamp > timestamp) exit
      acc_idx = find_account(sim%pending(1)%account_id)
      if (acc_idx > 0) then
        sim%accounts(acc_idx)%balance = sim%accounts(acc_idx)%balance + sim%pending(1)%amount
        call set_payment(sim%accounts(acc_idx), sim%pending(1)%payment_id, "CASHBACK_RECEIVED")
        call record_balance(sim%accounts(acc_idx), sim%pending(1)%timestamp)
      end if
      do i = 1, sim%pend_n - 1
        sim%pending(i) = sim%pending(i + 1)
      end do
      sim%pend_n = sim%pend_n - 1
    end do
  end subroutine

  logical function create_account(timestamp, account_id) result(ok)
    integer(int64), intent(in) :: timestamp
    character(len=*), intent(in) :: account_id
    call process_cashbacks(timestamp)
    if (find_account(account_id) > 0) then
      ok = .false.
      return
    end if
    call grow_accounts()
    sim%acc_n = sim%acc_n + 1
    sim%accounts(sim%acc_n)%id = account_id
    sim%accounts(sim%acc_n)%balance = 0
    sim%accounts(sim%acc_n)%outgoing = 0
    sim%accounts(sim%acc_n)%created_at = timestamp
    sim%accounts(sim%acc_n)%pay_n = 0
    sim%accounts(sim%acc_n)%hist_n = 0
    if (allocated(sim%accounts(sim%acc_n)%payments)) deallocate (sim%accounts(sim%acc_n)%payments)
    if (allocated(sim%accounts(sim%acc_n)%history)) deallocate (sim%accounts(sim%acc_n)%history)
    call record_balance(sim%accounts(sim%acc_n), timestamp)
    ok = .true.
  end function

  logical function deposit(timestamp, account_id, amount, out) result(ok)
    integer(int64), intent(in) :: timestamp, amount
    character(len=*), intent(in) :: account_id
    integer(int64), intent(out) :: out
    integer :: idx
    call process_cashbacks(timestamp)
    idx = find_account(account_id)
    if (idx == 0) then
      ok = .false.
      out = 0
      return
    end if
    sim%accounts(idx)%balance = sim%accounts(idx)%balance + amount
    call record_balance(sim%accounts(idx), timestamp)
    out = sim%accounts(idx)%balance
    ok = .true.
  end function

  logical function withdraw(idx, amount) result(ok)
    integer, intent(in) :: idx
    integer(int64), intent(in) :: amount
    if (sim%accounts(idx)%balance < amount) then
      ok = .false.
      return
    end if
    sim%accounts(idx)%balance = sim%accounts(idx)%balance - amount
    sim%accounts(idx)%outgoing = sim%accounts(idx)%outgoing + amount
    ok = .true.
  end function

  logical function transfer(timestamp, source_id, target_id, amount, out) result(ok)
    integer(int64), intent(in) :: timestamp, amount
    character(len=*), intent(in) :: source_id, target_id
    integer(int64), intent(out) :: out
    integer :: src, dst
    call process_cashbacks(timestamp)
    src = find_account(source_id)
    dst = find_account(target_id)
    if (source_id == target_id .or. src == 0 .or. dst == 0) then
      ok = .false.
      out = 0
      return
    end if
    if (.not. withdraw(src, amount)) then
      ok = .false.
      out = 0
      return
    end if
    sim%accounts(dst)%balance = sim%accounts(dst)%balance + amount
    call record_balance(sim%accounts(src), timestamp)
    call record_balance(sim%accounts(dst), timestamp)
    out = sim%accounts(src)%balance
    ok = .true.
  end function

  function top_spenders(timestamp, n) result(out)
    integer(int64), intent(in) :: timestamp, n
    type(c_ptr) :: out
    integer :: i, j, take
    integer, allocatable :: order(:)
    integer :: tmp
    character(len=128) :: buf
    call process_cashbacks(timestamp)
    out = json_arr_f()
    if (sim%acc_n == 0) return
    allocate (order(sim%acc_n))
    do i = 1, sim%acc_n
      order(i) = i
    end do
    do i = 1, sim%acc_n - 1
      do j = i + 1, sim%acc_n
        if (sim%accounts(order(j))%outgoing > sim%accounts(order(i))%outgoing .or. &
            (sim%accounts(order(j))%outgoing == sim%accounts(order(i))%outgoing .and. &
             sim%accounts(order(j))%id < sim%accounts(order(i))%id)) then
          tmp = order(i)
          order(i) = order(j)
          order(j) = tmp
        end if
      end do
    end do
    take = sim%acc_n
    if (n >= 0 .and. n < take) take = int(n)
    do i = 1, take
      write (buf, '(a,"(",i0,")")') sim%accounts(order(i))%id, sim%accounts(order(i))%outgoing
      call json_arr_push_f(out, json_str_f(trim(buf)))
    end do
  end function

  logical function pay(timestamp, account_id, amount, payment_id) result(ok)
    integer(int64), intent(in) :: timestamp, amount
    character(len=*), intent(in) :: account_id
    character(len=:), allocatable, intent(out) :: payment_id
    integer :: idx
    character(len=32) :: num
    call process_cashbacks(timestamp)
    idx = find_account(account_id)
    if (idx == 0) then
      ok = .false.
      payment_id = ""
      return
    end if
    if (.not. withdraw(idx, amount)) then
      ok = .false.
      payment_id = ""
      return
    end if
    sim%payment_counter = sim%payment_counter + 1
    write (num, '(i0)') sim%payment_counter
    payment_id = "payment" // trim(num)
    call set_payment(sim%accounts(idx), payment_id, "IN_PROGRESS")
    call record_balance(sim%accounts(idx), timestamp)
    call grow_pending()
    sim%pend_n = sim%pend_n + 1
    sim%pending(sim%pend_n)%timestamp = timestamp + cashback_delay
    sim%pending(sim%pend_n)%account_id = account_id
    sim%pending(sim%pend_n)%amount = (amount * 2_int64) / 100_int64
    sim%pending(sim%pend_n)%payment_id = payment_id
    ok = .true.
  end function

  logical function get_payment_status(timestamp, account_id, payment, status) result(ok)
    integer(int64), intent(in) :: timestamp
    character(len=*), intent(in) :: account_id, payment
    character(len=:), allocatable, intent(out) :: status
    integer :: idx, pay_idx
    call process_cashbacks(timestamp)
    idx = find_account(account_id)
    if (idx == 0) then
      ok = .false.
      status = ""
      return
    end if
    pay_idx = find_payment(sim%accounts(idx), payment)
    if (pay_idx == 0) then
      ok = .false.
      status = ""
      return
    end if
    status = sim%accounts(idx)%payments(pay_idx)%status
    ok = .true.
  end function

  subroutine sort_hist(acc)
    type(account_t), intent(inout) :: acc
    integer :: i, j
    type(bal_row) :: tmp
    do i = 1, acc%hist_n - 1
      do j = i + 1, acc%hist_n
        if (acc%history(j)%timestamp < acc%history(i)%timestamp) then
          tmp = acc%history(i)
          acc%history(i) = acc%history(j)
          acc%history(j) = tmp
        end if
      end do
    end do
  end subroutine

  logical function merge_accounts(timestamp, keep_id, drop_id) result(ok)
    integer(int64), intent(in) :: timestamp
    character(len=*), intent(in) :: keep_id, drop_id
    integer :: keep, drop, i, j
    call process_cashbacks(timestamp)
    keep = find_account(keep_id)
    drop = find_account(drop_id)
    if (keep_id == drop_id .or. keep == 0 .or. drop == 0) then
      ok = .false.
      return
    end if
    sim%accounts(keep)%balance = sim%accounts(keep)%balance + sim%accounts(drop)%balance
    sim%accounts(keep)%outgoing = sim%accounts(keep)%outgoing + sim%accounts(drop)%outgoing
    do i = 1, sim%accounts(drop)%pay_n
      if (find_payment(sim%accounts(keep), sim%accounts(drop)%payments(i)%id) == 0) then
        call set_payment(sim%accounts(keep), sim%accounts(drop)%payments(i)%id, &
                         sim%accounts(drop)%payments(i)%status)
      end if
    end do
    do i = 1, sim%accounts(drop)%hist_n
      call grow_hist(sim%accounts(keep))
      sim%accounts(keep)%hist_n = sim%accounts(keep)%hist_n + 1
      sim%accounts(keep)%history(sim%accounts(keep)%hist_n) = sim%accounts(drop)%history(i)
    end do
    call sort_hist(sim%accounts(keep))
    if (sim%accounts(drop)%created_at < sim%accounts(keep)%created_at) then
      sim%accounts(keep)%created_at = sim%accounts(drop)%created_at
    end if
    call record_balance(sim%accounts(keep), timestamp)
    do i = 1, sim%pend_n
      if (sim%pending(i)%account_id == drop_id) then
        sim%pending(i)%account_id = keep_id
      end if
    end do
    do j = drop, sim%acc_n - 1
      sim%accounts(j) = sim%accounts(j + 1)
    end do
    sim%acc_n = sim%acc_n - 1
    ok = .true.
  end function

  logical function get_balance(timestamp, account_id, time_at, out) result(ok)
    integer(int64), intent(in) :: timestamp, time_at
    character(len=*), intent(in) :: account_id
    integer(int64), intent(out) :: out
    integer :: idx, i
    call process_cashbacks(timestamp)
    idx = find_account(account_id)
    if (idx == 0) then
      ok = .false.
      out = 0
      return
    end if
    if (time_at < sim%accounts(idx)%created_at) then
      ok = .false.
      out = 0
      return
    end if
    ok = .false.
    out = 0
    do i = 1, sim%accounts(idx)%hist_n
      if (sim%accounts(idx)%history(i)%timestamp <= time_at) then
        out = sim%accounts(idx)%history(i)%balance
        ok = .true.
      else
        exit
      end if
    end do
  end function
end module
