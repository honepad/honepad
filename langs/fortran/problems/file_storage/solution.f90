module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: file_t
    character(len=:), allocatable :: name
    integer(int64) :: size = 0
    character(len=:), allocatable :: owner
  end type

  type :: user_t
    character(len=:), allocatable :: user_id
    logical :: has_cap = .false.
    integer(int64) :: cap = 0
  end type

  type :: snap_file_t
    character(len=:), allocatable :: name
    integer(int64) :: size = 0
  end type

  type :: backup_t
    character(len=:), allocatable :: user_id
    type(snap_file_t), allocatable :: files(:)
    integer :: file_n = 0
  end type

  type :: sim_t
    type(file_t), allocatable :: files(:)
    integer :: file_n = 0
    type(user_t), allocatable :: users(:)
    integer :: user_n = 0
    type(backup_t), allocatable :: backups(:)
    integer :: backup_n = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%files)) deallocate (sim%files)
    if (allocated(sim%users)) deallocate (sim%users)
    if (allocated(sim%backups)) deallocate (sim%backups)
    sim%file_n = 0
    sim%user_n = 0
    sim%backup_n = 0
    call grow_users()
    sim%user_n = 1
    sim%users(1)%user_id = "admin"
    sim%users(1)%has_cap = .false.
    sim%users(1)%cap = 0
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
    if (method == "add_file") then
      text = add_file(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "get_file_size") then
      text = get_file_size(arg_str(args, 0))
    else if (method == "delete_file") then
      text = delete_file(arg_str(args, 0))
    else if (method == "get_n_largest") then
      text = get_n_largest(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "add_user") then
      text = add_user(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "add_file_by") then
      text = add_file_by(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2))
    else if (method == "merge_user") then
      text = merge_user(arg_str(args, 0), arg_str(args, 1))
    else if (method == "backup_user") then
      text = backup_user(arg_str(args, 0))
    else if (method == "restore_user") then
      text = restore_user(arg_str(args, 0))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_file(name) result(idx)
    character(len=*), intent(in) :: name
    integer :: i
    idx = 0
    do i = 1, sim%file_n
      if (sim%files(i)%name == name) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_user(user_id) result(idx)
    character(len=*), intent(in) :: user_id
    integer :: i
    idx = 0
    do i = 1, sim%user_n
      if (sim%users(i)%user_id == user_id) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_backup(user_id) result(idx)
    character(len=*), intent(in) :: user_id
    integer :: i
    idx = 0
    do i = 1, sim%backup_n
      if (sim%backups(i)%user_id == user_id) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_files()
    type(file_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%files)) then
      allocate (sim%files(8))
      return
    end if
    if (sim%file_n < size(sim%files)) return
    cap = size(sim%files) * 2
    allocate (tmp(cap))
    tmp(1:sim%file_n) = sim%files(1:sim%file_n)
    call move_alloc(tmp, sim%files)
  end subroutine

  subroutine grow_users()
    type(user_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%users)) then
      allocate (sim%users(8))
      return
    end if
    if (sim%user_n < size(sim%users)) return
    cap = size(sim%users) * 2
    allocate (tmp(cap))
    tmp(1:sim%user_n) = sim%users(1:sim%user_n)
    call move_alloc(tmp, sim%users)
  end subroutine

  subroutine grow_backups()
    type(backup_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%backups)) then
      allocate (sim%backups(4))
      return
    end if
    if (sim%backup_n < size(sim%backups)) return
    cap = size(sim%backups) * 2
    allocate (tmp(cap))
    tmp(1:sim%backup_n) = sim%backups(1:sim%backup_n)
    call move_alloc(tmp, sim%backups)
  end subroutine

  integer(int64) function used_space(user_id) result(total)
    character(len=*), intent(in) :: user_id
    integer :: i
    total = 0
    do i = 1, sim%file_n
      if (sim%files(i)%owner == user_id) total = total + sim%files(i)%size
    end do
  end function

  logical function remaining(user_id, left) result(ok)
    character(len=*), intent(in) :: user_id
    integer(int64), intent(out) :: left
    integer :: idx
    idx = find_user(user_id)
    if (idx == 0 .or. .not. sim%users(idx)%has_cap) then
      ok = .false.
      left = 0
      return
    end if
    left = sim%users(idx)%cap - used_space(user_id)
    ok = .true.
  end function

  function add_file(name, size) result(out)
    character(len=*), intent(in) :: name
    integer(int64), intent(in) :: size
    character(len=:), allocatable :: out
    if (find_file(name) > 0) then
      out = "false"
      return
    end if
    call grow_files()
    sim%file_n = sim%file_n + 1
    sim%files(sim%file_n)%name = name
    sim%files(sim%file_n)%size = size
    sim%files(sim%file_n)%owner = "admin"
    out = "true"
  end function

  function get_file_size(name) result(out)
    character(len=*), intent(in) :: name
    character(len=:), allocatable :: out
    integer :: idx
    character(len=32) :: buf
    idx = find_file(name)
    if (idx == 0) then
      out = ""
      return
    end if
    write (buf, '(i0)') sim%files(idx)%size
    out = trim(buf)
  end function

  function delete_file(name) result(out)
    character(len=*), intent(in) :: name
    character(len=:), allocatable :: out
    integer :: idx, i
    integer(int64) :: size
    character(len=32) :: buf
    idx = find_file(name)
    if (idx == 0) then
      out = ""
      return
    end if
    size = sim%files(idx)%size
    do i = idx, sim%file_n - 1
      sim%files(i) = sim%files(i + 1)
    end do
    sim%file_n = sim%file_n - 1
    write (buf, '(i0)') size
    out = trim(buf)
  end function

  logical function starts_with(text, prefix) result(ok)
    character(len=*), intent(in) :: text, prefix
    integer :: n
    n = len(prefix)
    if (n == 0) then
      ok = .true.
      return
    end if
    if (len(text) < n) then
      ok = .false.
      return
    end if
    ok = text(1:n) == prefix
  end function

  function get_n_largest(prefix, n) result(out)
    character(len=*), intent(in) :: prefix
    integer(int64), intent(in) :: n
    character(len=:), allocatable :: out
    integer :: i, j, take, count
    integer, allocatable :: order(:)
    integer :: tmp
    character(len=:), allocatable :: piece
    character(len=32) :: buf
    allocate (order(sim%file_n))
    count = 0
    do i = 1, sim%file_n
      if (.not. starts_with(sim%files(i)%name, prefix)) cycle
      count = count + 1
      order(count) = i
    end do
    do i = 1, count - 1
      do j = i + 1, count
        if (sim%files(order(j))%size > sim%files(order(i))%size .or. &
            (sim%files(order(j))%size == sim%files(order(i))%size .and. &
             sim%files(order(j))%name < sim%files(order(i))%name)) then
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
      write (buf, '(i0)') sim%files(order(i))%size
      piece = sim%files(order(i))%name // "(" // trim(buf) // ")"
      if (i == 1) then
        out = piece
      else
        out = out // ", " // piece
      end if
    end do
  end function

  function add_user(user_id, cap) result(out)
    character(len=*), intent(in) :: user_id
    integer(int64), intent(in) :: cap
    character(len=:), allocatable :: out
    if (find_user(user_id) > 0) then
      out = "false"
      return
    end if
    call grow_users()
    sim%user_n = sim%user_n + 1
    sim%users(sim%user_n)%user_id = user_id
    sim%users(sim%user_n)%has_cap = .true.
    sim%users(sim%user_n)%cap = cap
    out = "true"
  end function

  function add_file_by(user_id, name, size) result(out)
    character(len=*), intent(in) :: user_id, name
    integer(int64), intent(in) :: size
    character(len=:), allocatable :: out
    integer(int64) :: left
    character(len=32) :: buf
    if (find_user(user_id) == 0 .or. find_file(name) > 0) then
      out = ""
      return
    end if
    if (remaining(user_id, left) .and. size > left) then
      out = ""
      return
    end if
    call grow_files()
    sim%file_n = sim%file_n + 1
    sim%files(sim%file_n)%name = name
    sim%files(sim%file_n)%size = size
    sim%files(sim%file_n)%owner = user_id
    if (.not. remaining(user_id, left)) then
      out = ""
      return
    end if
    write (buf, '(i0)') left
    out = trim(buf)
  end function

  subroutine drop_backup(user_id)
    character(len=*), intent(in) :: user_id
    integer :: idx, i
    idx = find_backup(user_id)
    if (idx == 0) return
    do i = idx, sim%backup_n - 1
      sim%backups(i) = sim%backups(i + 1)
    end do
    sim%backup_n = sim%backup_n - 1
  end subroutine

  function merge_user(user_id1, user_id2) result(out)
    character(len=*), intent(in) :: user_id1, user_id2
    character(len=:), allocatable :: out
    integer :: c1, c2, i
    integer(int64) :: left
    character(len=32) :: buf
    if (user_id1 == user_id2) then
      out = ""
      return
    end if
    c1 = find_user(user_id1)
    c2 = find_user(user_id2)
    if (c1 == 0 .or. c2 == 0 .or. .not. sim%users(c1)%has_cap .or. .not. sim%users(c2)%has_cap) then
      out = ""
      return
    end if
    sim%users(c1)%cap = sim%users(c1)%cap + sim%users(c2)%cap
    do i = 1, sim%file_n
      if (sim%files(i)%owner == user_id2) sim%files(i)%owner = user_id1
    end do
    do i = c2, sim%user_n - 1
      sim%users(i) = sim%users(i + 1)
    end do
    sim%user_n = sim%user_n - 1
    call drop_backup(user_id2)
    if (.not. remaining(user_id1, left)) then
      out = ""
      return
    end if
    write (buf, '(i0)') left
    out = trim(buf)
  end function

  function backup_user(user_id) result(out)
    character(len=*), intent(in) :: user_id
    character(len=:), allocatable :: out
    integer :: i, idx
    type(snap_file_t), allocatable :: snap(:)
    integer :: n
    character(len=32) :: buf
    if (find_user(user_id) == 0) then
      out = ""
      return
    end if
    call drop_backup(user_id)
    allocate (snap(sim%file_n))
    n = 0
    do i = 1, sim%file_n
      if (sim%files(i)%owner /= user_id) cycle
      n = n + 1
      snap(n)%name = sim%files(i)%name
      snap(n)%size = sim%files(i)%size
    end do
    call grow_backups()
    sim%backup_n = sim%backup_n + 1
    idx = sim%backup_n
    sim%backups(idx)%user_id = user_id
    sim%backups(idx)%file_n = n
    if (allocated(sim%backups(idx)%files)) deallocate (sim%backups(idx)%files)
    if (n > 0) then
      allocate (sim%backups(idx)%files(n))
      sim%backups(idx)%files(1:n) = snap(1:n)
    end if
    write (buf, '(i0)') n
    out = trim(buf)
  end function

  function restore_user(user_id) result(out)
    character(len=*), intent(in) :: user_id
    character(len=:), allocatable :: out
    integer :: i, bidx
    integer(int64) :: left, restored
    character(len=32) :: buf
    character(len=:), allocatable :: ignored
    if (find_user(user_id) == 0) then
      out = ""
      return
    end if
    do i = sim%file_n, 1, -1
      if (sim%files(i)%owner == user_id) ignored = delete_file(sim%files(i)%name)
    end do
    bidx = find_backup(user_id)
    if (bidx == 0) then
      out = "0"
      return
    end if
    restored = 0
    do i = 1, sim%backups(bidx)%file_n
      if (find_file(sim%backups(bidx)%files(i)%name) > 0) cycle
      if (remaining(user_id, left) .and. sim%backups(bidx)%files(i)%size > left) cycle
      call grow_files()
      sim%file_n = sim%file_n + 1
      sim%files(sim%file_n)%name = sim%backups(bidx)%files(i)%name
      sim%files(sim%file_n)%size = sim%backups(bidx)%files(i)%size
      sim%files(sim%file_n)%owner = user_id
      restored = restored + 1
    end do
    write (buf, '(i0)') restored
    out = trim(buf)
  end function
end module
