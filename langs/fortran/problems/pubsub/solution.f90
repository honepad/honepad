module solution
  use iso_c_binding
  use iso_fortran_env, only: int64
  use honepad_json
  implicit none

  type :: topic_t
    character(len=:), allocatable :: name
    character(len=:), allocatable :: clients(:)
    integer :: client_n = 0
  end type

  type :: inbox_t
    character(len=:), allocatable :: client
    character(len=:), allocatable :: msgs(:)
    integer :: msg_n = 0
  end type

  type :: retain_t
    character(len=:), allocatable :: topic
    character(len=:), allocatable :: message
  end type

  type :: sim_t
    type(topic_t), allocatable :: topics(:)
    integer :: topic_n = 0
    type(inbox_t), allocatable :: inboxes(:)
    integer :: inbox_n = 0
    type(retain_t), allocatable :: retained(:)
    integer :: retain_n = 0
  end type

  type(sim_t), save :: sim

contains

  subroutine honepad_reset()
    if (allocated(sim%topics)) deallocate (sim%topics)
    if (allocated(sim%inboxes)) deallocate (sim%inboxes)
    if (allocated(sim%retained)) deallocate (sim%retained)
    sim%topic_n = 0
    sim%inbox_n = 0
    sim%retain_n = 0
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
    if (method == "subscribe") then
      text = subscribe(arg_str(args, 0), arg_str(args, 1))
    else if (method == "unsubscribe") then
      text = unsubscribe(arg_str(args, 0), arg_str(args, 1))
    else if (method == "publish") then
      text = publish(arg_str(args, 0), arg_str(args, 1))
    else if (method == "inbox") then
      text = inbox_of(arg_str(args, 0))
    else if (method == "list_topics") then
      text = list_topics()
    else if (method == "subscribers") then
      text = subscribers_of(arg_str(args, 0))
    else if (method == "peek") then
      text = peek(arg_str(args, 0))
    else if (method == "ack") then
      text = ack(arg_str(args, 0), arg_i64(args, 1))
    else if (method == "retain") then
      text = retain(arg_str(args, 0), arg_str(args, 1))
    else
      ok = .false.
      err = "missing method " // trim(method)
      out = c_null_ptr
      return
    end if
    out = json_str_f(text)
  end function

  integer function find_topic(topic) result(idx)
    character(len=*), intent(in) :: topic
    integer :: i
    idx = 0
    do i = 1, sim%topic_n
      if (sim%topics(i)%name == topic) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_inbox(client) result(idx)
    character(len=*), intent(in) :: client
    integer :: i
    idx = 0
    do i = 1, sim%inbox_n
      if (sim%inboxes(i)%client == client) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_retained(topic) result(idx)
    character(len=*), intent(in) :: topic
    integer :: i
    idx = 0
    do i = 1, sim%retain_n
      if (sim%retained(i)%topic == topic) then
        idx = i
        return
      end if
    end do
  end function

  integer function find_client(idx, client) result(pos)
    integer, intent(in) :: idx
    character(len=*), intent(in) :: client
    integer :: i
    pos = 0
    do i = 1, sim%topics(idx)%client_n
      if (sim%topics(idx)%clients(i) == client) then
        pos = i
        return
      end if
    end do
  end function

  subroutine grow_topics()
    type(topic_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%topics)) then
      allocate (sim%topics(8))
      return
    end if
    if (sim%topic_n < size(sim%topics)) return
    cap = size(sim%topics) * 2
    allocate (tmp(cap))
    tmp(1:sim%topic_n) = sim%topics(1:sim%topic_n)
    call move_alloc(tmp, sim%topics)
  end subroutine

  subroutine grow_inboxes()
    type(inbox_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%inboxes)) then
      allocate (sim%inboxes(8))
      return
    end if
    if (sim%inbox_n < size(sim%inboxes)) return
    cap = size(sim%inboxes) * 2
    allocate (tmp(cap))
    tmp(1:sim%inbox_n) = sim%inboxes(1:sim%inbox_n)
    call move_alloc(tmp, sim%inboxes)
  end subroutine

  subroutine grow_retained()
    type(retain_t), allocatable :: tmp(:)
    integer :: cap
    if (.not. allocated(sim%retained)) then
      allocate (sim%retained(8))
      return
    end if
    if (sim%retain_n < size(sim%retained)) return
    cap = size(sim%retained) * 2
    allocate (tmp(cap))
    tmp(1:sim%retain_n) = sim%retained(1:sim%retain_n)
    call move_alloc(tmp, sim%retained)
  end subroutine

  subroutine grow_clients(idx)
    integer, intent(in) :: idx
    character(len=:), allocatable :: tmp(:)
    integer :: cap, width
    width = 1
    if (allocated(sim%topics(idx)%clients)) width = len(sim%topics(idx)%clients)
    if (.not. allocated(sim%topics(idx)%clients)) then
      allocate (character(len=64) :: sim%topics(idx)%clients(8))
      return
    end if
    if (sim%topics(idx)%client_n < size(sim%topics(idx)%clients)) return
    cap = size(sim%topics(idx)%clients) * 2
    allocate (character(len=width) :: tmp(cap))
    tmp(1:sim%topics(idx)%client_n) = sim%topics(idx)%clients(1:sim%topics(idx)%client_n)
    call move_alloc(tmp, sim%topics(idx)%clients)
  end subroutine

  subroutine grow_msgs(idx)
    integer, intent(in) :: idx
    character(len=:), allocatable :: tmp(:)
    integer :: cap, width
    width = 1
    if (allocated(sim%inboxes(idx)%msgs)) width = len(sim%inboxes(idx)%msgs)
    if (.not. allocated(sim%inboxes(idx)%msgs)) then
      allocate (character(len=256) :: sim%inboxes(idx)%msgs(8))
      return
    end if
    if (sim%inboxes(idx)%msg_n < size(sim%inboxes(idx)%msgs)) return
    cap = size(sim%inboxes(idx)%msgs) * 2
    allocate (character(len=width) :: tmp(cap))
    tmp(1:sim%inboxes(idx)%msg_n) = sim%inboxes(idx)%msgs(1:sim%inboxes(idx)%msg_n)
    call move_alloc(tmp, sim%inboxes(idx)%msgs)
  end subroutine

  integer function ensure_inbox(client) result(idx)
    character(len=*), intent(in) :: client
    idx = find_inbox(client)
    if (idx > 0) return
    call grow_inboxes()
    sim%inbox_n = sim%inbox_n + 1
    idx = sim%inbox_n
    sim%inboxes(idx)%client = client
    sim%inboxes(idx)%msg_n = 0
  end function

  subroutine add_msg(client, payload)
    character(len=*), intent(in) :: client, payload
    integer :: idx
    idx = ensure_inbox(client)
    call grow_msgs(idx)
    sim%inboxes(idx)%msg_n = sim%inboxes(idx)%msg_n + 1
    sim%inboxes(idx)%msgs(sim%inboxes(idx)%msg_n) = payload
  end subroutine

  function subscribe(topic, client) result(out)
    character(len=*), intent(in) :: topic, client
    character(len=:), allocatable :: out
    integer :: idx, ridx
    idx = find_topic(topic)
    if (idx > 0) then
      if (find_client(idx, client) > 0) then
        out = "false"
        return
      end if
    else
      call grow_topics()
      sim%topic_n = sim%topic_n + 1
      idx = sim%topic_n
      sim%topics(idx)%name = topic
      sim%topics(idx)%client_n = 0
    end if
    call grow_clients(idx)
    sim%topics(idx)%client_n = sim%topics(idx)%client_n + 1
    sim%topics(idx)%clients(sim%topics(idx)%client_n) = client
    ridx = find_retained(topic)
    if (ridx > 0) then
      call add_msg(client, topic // ":" // sim%retained(ridx)%message)
    end if
    out = "true"
  end function

  function unsubscribe(topic, client) result(out)
    character(len=*), intent(in) :: topic, client
    character(len=:), allocatable :: out
    integer :: idx, pos, i
    idx = find_topic(topic)
    if (idx == 0) then
      out = "false"
      return
    end if
    pos = find_client(idx, client)
    if (pos == 0) then
      out = "false"
      return
    end if
    do i = pos, sim%topics(idx)%client_n - 1
      sim%topics(idx)%clients(i) = sim%topics(idx)%clients(i + 1)
    end do
    sim%topics(idx)%client_n = sim%topics(idx)%client_n - 1
    if (sim%topics(idx)%client_n == 0) then
      do i = idx, sim%topic_n - 1
        sim%topics(i) = sim%topics(i + 1)
      end do
      sim%topic_n = sim%topic_n - 1
    end if
    out = "true"
  end function

  function publish(topic, message) result(out)
    character(len=*), intent(in) :: topic, message
    character(len=:), allocatable :: out
    integer :: idx, i
    character(len=32) :: buf
    idx = find_topic(topic)
    if (idx == 0) then
      out = "0"
      return
    end if
    do i = 1, sim%topics(idx)%client_n
      call add_msg(trim(sim%topics(idx)%clients(i)), topic // ":" // message)
    end do
    write (buf, '(i0)') sim%topics(idx)%client_n
    out = trim(buf)
  end function

  function join_n(parts, n) result(out)
    character(len=*), intent(in) :: parts(:)
    integer, intent(in) :: n
    character(len=:), allocatable :: out
    integer :: i
    out = ""
    do i = 1, n
      if (i == 1) then
        out = trim(parts(i))
      else
        out = out // ", " // trim(parts(i))
      end if
    end do
  end function

  function inbox_of(client) result(out)
    character(len=*), intent(in) :: client
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_inbox(client)
    if (idx == 0) then
      out = ""
      return
    end if
    out = join_n(sim%inboxes(idx)%msgs, sim%inboxes(idx)%msg_n)
  end function

  function list_topics() result(out)
    character(len=:), allocatable :: out
    integer :: i, j
    character(len=:), allocatable :: tmp
    integer, allocatable :: order(:)
    allocate (order(sim%topic_n))
    do i = 1, sim%topic_n
      order(i) = i
    end do
    do i = 1, sim%topic_n - 1
      do j = i + 1, sim%topic_n
        if (sim%topics(order(j))%name < sim%topics(order(i))%name) then
          order(i) = order(i) + order(j)
          order(j) = order(i) - order(j)
          order(i) = order(i) - order(j)
        end if
      end do
    end do
    out = ""
    do i = 1, sim%topic_n
      tmp = sim%topics(order(i))%name
      if (i == 1) then
        out = tmp
      else
        out = out // ", " // tmp
      end if
    end do
  end function

  function subscribers_of(topic) result(out)
    character(len=*), intent(in) :: topic
    character(len=:), allocatable :: out
    integer :: idx, i, j
    character(len=:), allocatable :: names(:)
    character(len=:), allocatable :: tmp
    integer :: n, width
    idx = find_topic(topic)
    if (idx == 0) then
      out = ""
      return
    end if
    n = sim%topics(idx)%client_n
    if (n == 0) then
      out = ""
      return
    end if
    width = len(sim%topics(idx)%clients)
    allocate (character(len=width) :: names(n))
    names(1:n) = sim%topics(idx)%clients(1:n)
    do i = 1, n - 1
      do j = i + 1, n
        if (trim(names(j)) < trim(names(i))) then
          tmp = names(i)
          names(i) = names(j)
          names(j) = tmp
        end if
      end do
    end do
    out = join_n(names, n)
  end function

  function peek(client) result(out)
    character(len=*), intent(in) :: client
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_inbox(client)
    if (idx == 0 .or. sim%inboxes(idx)%msg_n == 0) then
      out = ""
      return
    end if
    out = trim(sim%inboxes(idx)%msgs(1))
  end function

  function ack(client, n) result(out)
    character(len=*), intent(in) :: client
    integer(int64), intent(in) :: n
    character(len=:), allocatable :: out
    integer :: idx, i, dropn
    character(len=32) :: buf
    idx = find_inbox(client)
    if (n <= 0 .or. idx == 0) then
      out = "invalid_request"
      return
    end if
    if (n > sim%inboxes(idx)%msg_n) then
      out = "invalid_request"
      return
    end if
    dropn = int(n)
    do i = 1, sim%inboxes(idx)%msg_n - dropn
      sim%inboxes(idx)%msgs(i) = sim%inboxes(idx)%msgs(i + dropn)
    end do
    sim%inboxes(idx)%msg_n = sim%inboxes(idx)%msg_n - dropn
    write (buf, '(i0)') sim%inboxes(idx)%msg_n
    out = trim(buf)
  end function

  function retain(topic, message) result(out)
    character(len=*), intent(in) :: topic, message
    character(len=:), allocatable :: out
    integer :: idx
    idx = find_retained(topic)
    if (idx == 0) then
      call grow_retained()
      sim%retain_n = sim%retain_n + 1
      idx = sim%retain_n
      sim%retained(idx)%topic = topic
    end if
    sim%retained(idx)%message = message
    out = ""
  end function
end module
