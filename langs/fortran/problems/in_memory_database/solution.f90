module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: field_t
    character(len=:), allocatable :: name
    character(len=:), allocatable :: value
    logical :: has_expiry = .false.
    integer(int64) :: expiry = 0
  end type

  type :: key_t
    character(len=:), allocatable :: key
    type(field_t), allocatable :: fields(:)
    integer :: field_n = 0
  end type

  type :: backup_field_t
    character(len=:), allocatable :: key
    character(len=:), allocatable :: name
    character(len=:), allocatable :: value
    logical :: has_expiry = .false.
    integer(int64) :: expiry_delta = 0
  end type

  type :: backup_t
    integer(int64) :: timestamp = 0
    type(backup_field_t), allocatable :: fields(:)
    integer :: field_n = 0
  end type

  type :: db_t
    type(key_t), allocatable :: keys(:)
    integer :: key_n = 0
    type(backup_t), allocatable :: backups(:)
    integer :: backup_n = 0
  end type

  type(db_t), save :: db

contains

  subroutine honepad_reset()
    if (allocated(db%keys)) deallocate (db%keys)
    if (allocated(db%backups)) deallocate (db%backups)
    db%key_n = 0
    db%backup_n = 0
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
    if (method == "set") then
      call set_internal(arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), .false., 0_int64)
      text = ""
    else if (method == "get") then
      text = get_value(arg_str(args, 0), arg_str(args, 1))
    else if (method == "delete") then
      if (delete_field(arg_str(args, 0), arg_str(args, 1))) then
        text = "true"
      else
        text = "false"
      end if
    else if (method == "scan") then
      text = scan_key(arg_str(args, 0), "", .false., 0_int64)
    else if (method == "scan_by_prefix") then
      text = scan_key(arg_str(args, 0), arg_str(args, 1), .false., 0_int64)
    else if (method == "set_at") then
      call set_internal(arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), .false., 0_int64)
      text = ""
    else if (method == "set_at_with_ttl") then
      call set_internal(arg_str(args, 0), arg_str(args, 1), arg_str(args, 2), .true., &
                        arg_i64(args, 3) + arg_i64(args, 4))
      text = ""
    else if (method == "delete_at") then
      if (.not. is_alive(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2))) then
        text = "false"
      else
        call delete_field_ignore(arg_str(args, 0), arg_str(args, 1))
        text = "true"
      end if
    else if (method == "get_at") then
      if (.not. is_alive(arg_str(args, 0), arg_str(args, 1), arg_i64(args, 2))) then
        text = ""
      else
        text = get_value(arg_str(args, 0), arg_str(args, 1))
      end if
    else if (method == "scan_at") then
      text = scan_key(arg_str(args, 0), "", .true., arg_i64(args, 1))
    else if (method == "scan_by_prefix_at") then
      text = scan_key(arg_str(args, 0), arg_str(args, 1), .true., arg_i64(args, 2))
    else if (method == "backup") then
      text = do_backup(arg_i64(args, 0))
    else if (method == "restore") then
      text = do_restore(arg_i64(args, 0), arg_i64(args, 1))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_key(key) result(idx)
    character(len=*), intent(in) :: key
    integer :: i
    idx = 0
    do i = 1, db%key_n
      if (db%keys(i)%key == key) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_field(key_idx, name) result(idx)
    integer, intent(in) :: key_idx
    character(len=*), intent(in) :: name
    integer :: i
    idx = 0
    do i = 1, db%keys(key_idx)%field_n
      if (db%keys(key_idx)%fields(i)%name == name) then
        idx = i
        return
      end if
    end do
  end function

  subroutine grow_keys()
    type(key_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(db%keys)) then
      allocate (db%keys(8))
      return
    end if
    if (db%key_n < size(db%keys)) return
    cap = size(db%keys) * 2
    allocate (tmp(cap))
    tmp(1:db%key_n) = db%keys(1:db%key_n)
    call move_alloc(tmp, db%keys)
  end subroutine

  subroutine grow_fields(row)
    type(key_t), intent(inout) :: row
    type(field_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(row%fields)) then
      allocate (row%fields(4))
      return
    end if
    if (row%field_n < size(row%fields)) return
    cap = size(row%fields) * 2
    allocate (tmp(cap))
    tmp(1:row%field_n) = row%fields(1:row%field_n)
    call move_alloc(tmp, row%fields)
  end subroutine

  subroutine grow_backups()
    type(backup_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(db%backups)) then
      allocate (db%backups(4))
      return
    end if
    if (db%backup_n < size(db%backups)) return
    cap = size(db%backups) * 2
    allocate (tmp(cap))
    tmp(1:db%backup_n) = db%backups(1:db%backup_n)
    call move_alloc(tmp, db%backups)
  end subroutine

  subroutine grow_bfields(backup)
    type(backup_t), intent(inout) :: backup
    type(backup_field_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(backup%fields)) then
      allocate (backup%fields(8))
      return
    end if
    if (backup%field_n < size(backup%fields)) return
    cap = size(backup%fields) * 2
    allocate (tmp(cap))
    tmp(1:backup%field_n) = backup%fields(1:backup%field_n)
    call move_alloc(tmp, backup%fields)
  end subroutine

  integer function ensure_key(key) result(idx)
    character(len=*), intent(in) :: key
    idx = find_key(key)
    if (idx > 0) return
    call grow_keys()
    db%key_n = db%key_n + 1
    idx = db%key_n
    db%keys(idx)%key = key
    db%keys(idx)%field_n = 0
    if (allocated(db%keys(idx)%fields)) deallocate (db%keys(idx)%fields)
  end function

  subroutine set_internal(key, field, value, has_expiry, expiry)
    character(len=*), intent(in) :: key, field, value
    logical, intent(in) :: has_expiry
    integer(int64), intent(in) :: expiry
    integer :: idx, fidx
    idx = ensure_key(key)
    fidx = find_field(idx, field)
    if (fidx > 0) then
      db%keys(idx)%fields(fidx)%value = value
      db%keys(idx)%fields(fidx)%has_expiry = has_expiry
      db%keys(idx)%fields(fidx)%expiry = expiry
      return
    end if
    call grow_fields(db%keys(idx))
    db%keys(idx)%field_n = db%keys(idx)%field_n + 1
    fidx = db%keys(idx)%field_n
    db%keys(idx)%fields(fidx)%name = field
    db%keys(idx)%fields(fidx)%value = value
    db%keys(idx)%fields(fidx)%has_expiry = has_expiry
    db%keys(idx)%fields(fidx)%expiry = expiry
  end subroutine

  logical function is_alive(key, field, timestamp) result(ok)
    character(len=*), intent(in) :: key, field
    integer(int64), intent(in) :: timestamp
    integer :: idx, fidx
    idx = find_key(key)
    if (idx == 0) then
      ok = .false.
      return
    end if
    fidx = find_field(idx, field)
    if (fidx == 0) then
      ok = .false.
      return
    end if
    if (.not. db%keys(idx)%fields(fidx)%has_expiry) then
      ok = .true.
      return
    end if
    ok = timestamp < db%keys(idx)%fields(fidx)%expiry
  end function

  function get_value(key, field) result(value)
    character(len=*), intent(in) :: key, field
    character(len=:), allocatable :: value
    integer :: idx, fidx
    idx = find_key(key)
    if (idx == 0) then
      value = ""
      return
    end if
    fidx = find_field(idx, field)
    if (fidx == 0) then
      value = ""
      return
    end if
    value = db%keys(idx)%fields(fidx)%value
  end function

  logical function delete_field(key, field) result(ok)
    character(len=*), intent(in) :: key, field
    integer :: idx, fidx, i
    idx = find_key(key)
    if (idx == 0) then
      ok = .false.
      return
    end if
    fidx = find_field(idx, field)
    if (fidx == 0) then
      ok = .false.
      return
    end if
    do i = fidx, db%keys(idx)%field_n - 1
      db%keys(idx)%fields(i) = db%keys(idx)%fields(i + 1)
    end do
    db%keys(idx)%field_n = db%keys(idx)%field_n - 1
    ok = .true.
  end function

  subroutine delete_field_ignore(key, field)
    character(len=*), intent(in) :: key, field
    logical :: ignored
    ignored = delete_field(key, field)
  end subroutine

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

  function scan_key(key, prefix, timed, timestamp) result(out)
    character(len=*), intent(in) :: key, prefix
    logical, intent(in) :: timed
    integer(int64), intent(in) :: timestamp
    character(len=:), allocatable :: out
    integer :: idx, i, j, n
    integer, allocatable :: order(:)
    integer :: tmp
    character(len=:), allocatable :: piece
    idx = find_key(key)
    if (idx == 0) then
      out = ""
      return
    end if
    allocate (order(db%keys(idx)%field_n))
    n = 0
    do i = 1, db%keys(idx)%field_n
      if (len(prefix) > 0 .and. .not. starts_with(db%keys(idx)%fields(i)%name, prefix)) cycle
      if (timed .and. .not. is_alive(key, db%keys(idx)%fields(i)%name, timestamp)) cycle
      n = n + 1
      order(n) = i
    end do
    do i = 1, n - 1
      do j = i + 1, n
        if (db%keys(idx)%fields(order(j))%name < db%keys(idx)%fields(order(i))%name) then
          tmp = order(i)
          order(i) = order(j)
          order(j) = tmp
        end if
      end do
    end do
    out = ""
    do i = 1, n
      piece = db%keys(idx)%fields(order(i))%name // "(" // db%keys(idx)%fields(order(i))%value // ")"
      if (i == 1) then
        out = piece
      else
        out = out // ", " // piece
      end if
    end do
  end function

  function do_backup(timestamp) result(out)
    integer(int64), intent(in) :: timestamp
    character(len=:), allocatable :: out
    integer :: i, j, key_count
    logical :: used
    character(len=32) :: buf
    call grow_backups()
    db%backup_n = db%backup_n + 1
    db%backups(db%backup_n)%timestamp = timestamp
    db%backups(db%backup_n)%field_n = 0
    if (allocated(db%backups(db%backup_n)%fields)) deallocate (db%backups(db%backup_n)%fields)
    key_count = 0
    do i = 1, db%key_n
      used = .false.
      do j = 1, db%keys(i)%field_n
        if (.not. is_alive(db%keys(i)%key, db%keys(i)%fields(j)%name, timestamp)) cycle
        call grow_bfields(db%backups(db%backup_n))
        db%backups(db%backup_n)%field_n = db%backups(db%backup_n)%field_n + 1
        db%backups(db%backup_n)%fields(db%backups(db%backup_n)%field_n)%key = db%keys(i)%key
        db%backups(db%backup_n)%fields(db%backups(db%backup_n)%field_n)%name = db%keys(i)%fields(j)%name
        db%backups(db%backup_n)%fields(db%backups(db%backup_n)%field_n)%value = db%keys(i)%fields(j)%value
        db%backups(db%backup_n)%fields(db%backups(db%backup_n)%field_n)%has_expiry = &
          db%keys(i)%fields(j)%has_expiry
        if (db%keys(i)%fields(j)%has_expiry) then
          db%backups(db%backup_n)%fields(db%backups(db%backup_n)%field_n)%expiry_delta = &
            db%keys(i)%fields(j)%expiry - timestamp
        else
          db%backups(db%backup_n)%fields(db%backups(db%backup_n)%field_n)%expiry_delta = 0
        end if
        used = .true.
      end do
      if (used) key_count = key_count + 1
    end do
    write (buf, '(i0)') key_count
    out = trim(buf)
  end function

  subroutine clear_db()
    if (allocated(db%keys)) deallocate (db%keys)
    db%key_n = 0
  end subroutine

  function do_restore(timestamp, timestamp_to_restore) result(out)
    integer(int64), intent(in) :: timestamp, timestamp_to_restore
    character(len=:), allocatable :: out
    integer :: i, idx
    integer(int64) :: expiry
    idx = 0
    do i = 1, db%backup_n
      if (db%backups(i)%timestamp <= timestamp_to_restore) idx = i
    end do
    call clear_db()
    if (idx <= 0) then
      out = ""
      return
    end if
    do i = 1, db%backups(idx)%field_n
      expiry = 0
      if (db%backups(idx)%fields(i)%has_expiry) then
        expiry = timestamp + db%backups(idx)%fields(i)%expiry_delta
      end if
      call set_internal(db%backups(idx)%fields(i)%key, db%backups(idx)%fields(i)%name, &
                        db%backups(idx)%fields(i)%value, db%backups(idx)%fields(i)%has_expiry, expiry)
    end do
    out = ""
  end function
end module
