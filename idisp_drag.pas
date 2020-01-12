{   Routines for dragging lines or rectangles with the mouse.
}
module idisp_drag;
define drag_on;
define drag_draw;
define drag_undraw;
define drag_off;
%include 'idisp.ins.pas';

var
  dith_on: boolean;                    {TRUE if dithering is ON}
{
********************************************************************************
*
*   Subroutine DRAG_ON
*
*   Set up state for dragging with the mouse.
}
procedure drag_on;                     {start drag operation}
  val_param;

begin
  rend_get.dith_on^ (dith_on);         {save current dithering state}
  rend_set.dith_on^ (false);           {temporarily disable dithering}
  if xor_ok then begin
    rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_xor_k);
    rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_xor_k);
    rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_xor_k);
    rend_set.rgb^ (0.5, 0.5, 0.5);
    end;
  rend_set.event_req_pnt^ (true);      {enable pointer motion events}
  rend_event_req_stdin_line (false);   {disable standard input events}
  end;
{
********************************************************************************
*
*   Subroutine DRAG_DRAW
*
*   Set up state for drawing object in drag mode.
}
procedure drag_draw;                   {draw dragged object}
  val_param;

begin
  if not xor_ok then begin
    rend_set.rgb^ (1.0, 1.0, 0.5);
    end;
  end;
{
********************************************************************************
*
*   Subroutine DRAG_UNDRAW
*
*   Set up state for undrawing an object previously drawn in drag mode.
}
procedure drag_undraw;                 {undraw dragged object}
  val_param;

begin
  if not xor_ok then begin
    rend_set.rgb^ (0.0, 0.0, 0.0);
    end;
  end;
{
********************************************************************************
*
*   Subroutine DRAG_OFF
*
*   Restore state to normal from dragging with the mouse.
}
procedure drag_off;                    {end drag operation}
  val_param;

begin
  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_insert_k);
  rend_set.dith_on^ (dith_on);         {restore old dithering state}
  rend_set.event_req_pnt^ (false);     {disable pointer motion events}
  rend_event_req_stdin_line (true);    {re-enable standard input events}
  end;
