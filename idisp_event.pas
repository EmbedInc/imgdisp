{   User events handling.
}
module idisp_event;
define event_setup;
define event_pointer_down;
define event_pointer_up;
define event_pointer_move;
define event_point_dblclick;
%include 'idisp.ins.pas';

var
  pntdown: boolean;                    {main pointer button is down}
{
********************************************************************************
*
*   Subroutine EVENT_SETUP
*
*   Set up the RENDlib event state for our use.
}
procedure event_setup;                 {set up RENDlib events for our use}
  val_param;

begin
  rend_set.event_req_close^ (true);    {enable events we care about}
  rend_set.event_req_wiped_resize^ (true);
  rend_set.event_req_wiped_rect^ (true);
  rend_set.event_req_pnt^ (true);      {enable pointer motion events}

  rend_set.event_req_key_on^ (         {ignore ENTER key}
    rend_get.key_sp^ (rend_key_sp_enter_k, 0),
    key_unused_k);
  rend_event_req_stdin_line (true);

  rend_set.event_req_key_on^ (         {keys for advancing to next image}
    rend_get.key_sp^ (rend_key_sp_arrow_right_k, 0),
    key_next_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_pagedn_k, 0),
    key_next_k);

  rend_set.event_req_key_on^ (         {keys for back to previous image}
    rend_get.key_sp^ (rend_key_sp_arrow_left_k, 0),
    key_prev_k);
  rend_set.event_req_key_on^ (
    rend_get.key_sp^ (rend_key_sp_pageup_k, 0),
    key_prev_k);

  rend_set.event_req_key_on^ (         {main pointer key, usually left mouse button}
    rend_get.key_sp^ (rend_key_sp_pointer_k, 1),
    key_point_k);

  pntdown := false;                    {init to main pointer buttton not dow}
  end;
{
********************************************************************************
*
*   Subroutine EVENT_POINTER_DOWN (EVX, EVY, MODK)
*
*   Process the main pointer key pressed event.  EVX,EVY is the drawing device
*   pixel coordinate of the pointer at the time of the event.  MODK is the set
*   of active modifiers active at the time of the event.
}
procedure event_pointer_down (         {handle main pointer key pressed event}
  in      evx, evy: sys_int_machine_t; {draw device coor of event}
  in      modk: rend_key_mod_t);       {modifiers active at time of event}
  val_param;

var
  p2d: vect_2d_t;                      {pointer location in 2D space}

begin
  if pntdown then return;              {key already pressed, this is not new ?}
  pntdown := true;

  xform_dpix_2d (evx, evy, p2d);       {transform dev pix coor to 2D space}
  ovl_vects_start (p2d.x, p2d.y);      {start vectors chain}

  rend_set.enter_rend^;
  rend_set.cpnt_2d^ (p2d.x, p2d.y);    {go to vectors chain start}
  rend_set.exit_rend^;
  end;
{
********************************************************************************
*
*   Subroutine EVENT_POINTER_UP (EVX, EVY, MODK)
*
*   Process the main pointer key released event.  EVX,EVY is the drawing device
*   pixel coordinate of the pointer at the time of the event.  MODK is the set
*   of active modifiers active at the time of the event.
}
procedure event_pointer_up (           {handle main pointer key released event}
  in      evx, evy: sys_int_machine_t; {draw device coor of event}
  in      modk: rend_key_mod_t);       {modifiers active at time of event}
  val_param;

begin
  if not pntdown then return;          {key already released, this is not new ?}
  pntdown := false;

  ovl_vects_end;                       {end the vectors chain}
  end;
{
********************************************************************************
*
*   Subroutine EVENT_POINTER_MOVE (EVX, EVY)
}
procedure event_pointer_move (         {handle pointer motion}
  in      evx, evy: sys_int_machine_t); {new pointer coordinate}
  val_param;

var
  p2d: vect_2d_t;                      {pointer location in 2D space}

begin
  if not pntdown then return;

  xform_dpix_2d (evx, evy, p2d);       {transform dev pix coor to 2D space}
  ovl_vects_add (p2d.x, p2d.y);        {add this coordinate to vectors chain}

  rend_set.enter_rend^;
  rend_prim.vect_2d^ (p2d.x, p2d.y);   {draw the vector to this point}
  rend_set.exit_rend^;
  end;
{
********************************************************************************
*
*   Subroutine EVENT_POINTER_DBLCLICK (EVX, EVY, MODK)
*
*   Process a double-click of the main pointer key.
}
procedure event_pointer_dblclick (     {process main pointer key double click}
  in      evx, evy: sys_int_machine_t); {draw device coor of event}
  val_param;

begin
  if pntdown then begin                {started vectors chain on first click ?}
    ovl_vects_cancel;                  {cancel it}
    end;
  pntdown := false;

  writeln ('Dbl-click');
  end;
