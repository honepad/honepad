module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: item_t
    character(len=:), allocatable :: sku
    character(len=:), allocatable :: name
    integer(int64) :: qty = 0
    integer(int64) :: reserved = 0
  end type

  type :: sim_t
    type(item_t), allocatable :: items(:)
    integer :: item_n = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%items)) deallocate (sim%items)
    sim%item_n = 0
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
    if (method == "create_item") then
      text = create_item(arg_str(args, 0), arg_str(args, 1))
    else if (method == "stock") then
      text = stock(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "get_qty") then
      text = get_qty(arg_str(args, 0))
    else if (method == "list_low") then
      text = list_low(arg_i64(args, 0))
    else if (method == "reserve") then
      text = reserve_item(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "release") then
      text = release_item(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "ship") then
      text = ship_item(arg_str(args, 0), arg_i64(args, 1))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_item(sku) result(idx)
    character(len=*), intent(in) :: sku
    integer :: i
    idx = 0
    do i = 1, sim%item_n
      if (sim%items(i)%sku == sku) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_items()
    type(item_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%items)) then
      allocate (sim%items(8))
      return
    end if
    if (sim%item_n < size(sim%items)) return
    cap = size(sim%items) * 2
    allocate (tmp(cap))
    tmp(1:sim%item_n) = sim%items(1:sim%item_n)
    call move_alloc(tmp, sim%items)
  end subroutine

  function create_item(sku, name) result(out)
    character(len=*), intent(in) :: sku, name
    character(len=:), allocatable :: out
    if (find_item(sku) > 0) then
      out = "false"
      return
    end if
    call grow_items()
    sim%item_n = sim%item_n + 1
    sim%items(sim%item_n)%sku = sku
    sim%items(sim%item_n)%name = name
    sim%items(sim%item_n)%qty = 0
    sim%items(sim%item_n)%reserved = 0
    out = "true"
  end function

  function stock(sku, delta) result(out)
    character(len=*), intent(in) :: sku
    integer(int64), intent(in) :: delta
    character(len=:), allocatable :: out
    integer :: idx
    integer(int64) :: nxt
    character(len=32) :: buf
    idx = find_item(sku)
    if (idx == 0) then
      out = ""
      return
    end if
    nxt = sim%items(idx)%qty + delta
    if (nxt < sim%items(idx)%reserved) then
      out = "invalid_request"
      return
    end if
    sim%items(idx)%qty = nxt
    write (buf, '(i0)') nxt
    out = trim(buf)
  end function

  function get_qty(sku) result(out)
    character(len=*), intent(in) :: sku
    character(len=:), allocatable :: out
    integer :: idx
    character(len=32) :: buf
    idx = find_item(sku)
    if (idx == 0) then
      out = ""
      return
    end if
    write (buf, '(i0)') sim%items(idx)%qty
    out = trim(buf)
  end function

  function list_low(threshold) result(out)
    integer(int64), intent(in) :: threshold
    character(len=:), allocatable :: out
    integer :: i, j, count, tmp
    integer, allocatable :: order(:)
    character(len=:), allocatable :: piece
    character(len=32) :: buf
    allocate (order(sim%item_n))
    count = 0
    do i = 1, sim%item_n
      if (sim%items(i)%qty > threshold) cycle
      count = count + 1
      order(count) = i
    end do
    do i = 1, count - 1
      do j = i + 1, count
        if (sim%items(order(j))%qty < sim%items(order(i))%qty .or. &
            (sim%items(order(j))%qty == sim%items(order(i))%qty .and. &
             sim%items(order(j))%sku < sim%items(order(i))%sku)) then
          tmp = order(i)
          order(i) = order(j)
          order(j) = tmp
        end if
      end do
    end do
    out = ""
    do i = 1, count
      write (buf, '(i0)') sim%items(order(i))%qty
      piece = sim%items(order(i))%sku // "(" // trim(buf) // ")"
      if (i == 1) then
        out = piece
      else
        out = out // ", " // piece
      end if
    end do
  end function

  function reserve_item(sku, n) result(out)
    character(len=*), intent(in) :: sku
    integer(int64), intent(in) :: n
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_item(sku)
    if (idx == 0 .or. n <= 0 .or. sim%items(idx)%reserved + n > sim%items(idx)%qty) then
      out = "invalid_request"
      return
    end if
    sim%items(idx)%reserved = sim%items(idx)%reserved + n
    out = "true"
  end function

  function release_item(sku, n) result(out)
    character(len=*), intent(in) :: sku
    integer(int64), intent(in) :: n
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_item(sku)
    if (idx == 0 .or. n <= 0 .or. n > sim%items(idx)%reserved) then
      out = "invalid_request"
      return
    end if
    sim%items(idx)%reserved = sim%items(idx)%reserved - n
    out = "true"
  end function

  function ship_item(sku, n) result(out)
    character(len=*), intent(in) :: sku
    integer(int64), intent(in) :: n
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_item(sku)
    if (idx == 0 .or. n <= 0 .or. n > sim%items(idx)%reserved) then
      out = "invalid_request"
      return
    end if
    sim%items(idx)%reserved = sim%items(idx)%reserved - n
    sim%items(idx)%qty = sim%items(idx)%qty - n
    out = "true"
  end function
end module
