{   User events handling.
}
module idisp_event;
define event_pan;
define event_inquire;
%include 'idisp.ins.pas';

type
  inqrect_t = record                   {describes bounds of inquire rectangle}
    xmin, xmax: sys_int_machine_t;     {min/max X coordinates, inclusive}
    ymin, ymax: sys_int_machine_t;     {min/max Y coordinates, inclusive}
    end;
{
********************************************************************************
*
*   Function EVENT_PAN (EVX, EVY)
*
*   Handle event where PAN key was just pressed.  EV is the event descriptor.
*   The function returns TRUE if a redraw is required.
}
function event_pan (                   {handle user PAN event}
  in      evx, evy: sys_int_machine_t) {window coordinate of the PAN start}
  :boolean;                            {TRUE if redraw required}
  val_param;

var
  ps_x, ps_y: sys_int_machine_t;       {starting coordinates of pan operation}
  pnt_x, pnt_y: sys_int_machine_t;     {new pointer coordinates}
  ev: rend_event_t;                    {new events}

label
  wait, event_unexpected;

begin
  event_pan := false;                  {init to no redraw is required}
  ps_x := evx;                         {save original pointer coordinates}
  ps_y := evy;
  pnt_x := ps_x;                       {init current rubber band end point}
  pnt_y := ps_y;
  rend_set.enter_level^ (1);           {enter graphics mode}
  drag_on;                             {set up state for dragging with pointer}
  drag_draw;                           {set up for drawing dragged object}
  rend_set.cpnt_2dim^ (ps_x + 0.5, ps_y + 0.5); {go to start of vector}
  rend_prim.vect_2dimcl^ (pnt_x + 0.5, pnt_y + 0.5); {draw original rubber band}
  rend_prim.flush_all^;                {make sure line is drawn now}

wait:                                  {back here to wait for new event}
  rend_set.enter_level^ (0);           {leave graphics mode before event wait}
  rend_event_get (ev);                 {get the next event}
  case ev.ev_type of                   {what kind of event is this ?}

rend_ev_key_k: begin                   {user hit or released a key}
      if ev.key.key_p^.id_user <> key_pan_k {this is not our key ?}
        then goto event_unexpected;
      anch_img.x :=                    {update anchor point on image}
        (ps_x - uli_x + 0.5) / (img.x_size * zoom);
      anch_img.y :=
        (ps_y - uli_y + 0.5) / (img.y_size * zoom);
      anch_dev.x :=                    {update anchor point on drawing device}
        (ev.key.x + 0.5) / image_width;
      anch_dev.y :=
        (ev.key.y + 0.5) / image_height;
      rend_set.enter_rend^;            {enter graphics mode}
      if (ev.key.x = ps_x) and (ev.key.y = ps_y)
        then begin                     {no net pan was performed}
          rend_set.cpnt_2dim^ (        {go to start of old rubber band}
           ps_x + 0.5, ps_y + 0.5);
          rend_prim.vect_2dimcl^ (pnt_x + 0.5, pnt_y + 0.5); {erase old rubber band}
          rend_prim.flush_all^;        {make sure line is drawn now}
          drag_off;                    {restore from dragging state}
          end
        else begin                     {the picture was panned}
          drag_off;                    {restore from dragging state}
          event_pan := true;           {the picture will need to be redrawn}
          end
        ;
      end;                             {end of key event in pan operation}

rend_ev_pnt_move_k: begin
      rend_set.enter_rend^;            {enter graphics mode}

      drag_undraw;                     {set up for undrawing dragged object}
      rend_set.cpnt_2dim^ (            {go to start of old rubber band}
        ps_x + 0.5, ps_y + 0.5);
      rend_prim.vect_2dimcl^ (pnt_x + 0.5, pnt_y + 0.5); {erase old rubber band}

      drag_draw;                       {set of for drawing dragged object}
      rend_set.cpnt_2dim^ (            {go to start of new rubber band}
        ps_x + 0.5, ps_y + 0.5);
      rend_prim.vect_2dimcl^ (         {redraw rubber band in new position}
        ev.pnt_move.x + 0.5,
        ev.pnt_move.y + 0.5);
      rend_prim.flush_all^;            {make sure rubber band is drawn now}
      pnt_x := ev.pnt_move.x;          {save rubber band end coordinates}
      pnt_y := ev.pnt_move.y;
      goto wait;                       {back and wait for more events within PAN}
      end;

otherwise
event_unexpected:                      {jump here if got unexpected event}
    rend_event_push (ev);              {put the event back}
    end;                               {end of event cases within pan operation}

  end;
{
********************************************************************************
*
*   Local subroutine CLIP_RECT (RECT)
*
*   Clip the inquire rectangle to the visible portion of the image in the
*   current window.  The inquire rectangle is in image coordinates.
}
procedure clip_rect (
  in out  rect: inqrect_t);            {rectangle to adjust if neccessary}
  val_param; internal;

var
  x, y: sys_int_machine_t;             {scratch coordinates}

begin
{
*   Clip upper left corner to window.
}
  xform_image_wind (rect.xmin, rect.ymin, x, y);
  x := max(0, min(image_width - 1, x));
  y := max(0, min(image_height - 1, y));
  xform_wind_image (x, y, rect.xmin, rect.ymin);
{
*   Clip lower right corner to window.
}
  xform_image_wind (rect.xmax, rect.ymax, x, y);
  x := max(0, min(image_width - 1, x));
  y := max(0, min(image_height - 1, y));
  xform_wind_image (x, y, rect.xmax, rect.ymax);
{
*   Clip upper left corner to image.
}
  rect.xmin := max(0, min(img.x_size - 1, rect.xmin));
  rect.ymin := max(0, min(img.y_size - 1, rect.ymin));
{
*   Clip lower right corner to image.
}
  rect.xmax := max(0, min(img.x_size - 1, rect.xmax));
  rect.ymax := max(0, min(img.y_size - 1, rect.ymax));
  end;
{
********************************************************************************
*
*   Local subroutine DRAW_INQRECT (RECT)
*
*   Draw the outine of the inquire rectangle.
}
procedure draw_inqrect (
  in      rect: inqrect_t);            {inquire rectangle bounds}
  val_param; internal;

var
  x1, x2: sys_int_machine_t;           {left/right edges of rect in wind coord}
  y1, y2: sys_int_machine_t;           {top/bottom edges of rect in wind coord}

begin
  xform_image_wind (rect.xmin, rect.ymin, x1, y1); {convert rect to window coordinates}
  xform_image_wind (rect.xmax, rect.ymax, x2, y2);

  x2 := x2 + zoom - 1;                 {go to farthest edge of pixels}
  y2 := y2 + zoom - 1;

  x1 := max(0, min(image_width-1, x1)); {clip to actual window area}
  y1 := max(0, min(image_height-1, y1));
  x2 := max(0, min(image_width-1, x2));
  y2 := max(0, min(image_height-1, y2));

  rend_set.cpnt_2dimi^ (x1, y1);       {move to top left corner of rectangle}

  if (x2 = x1) or (y2 = y1) then begin {rectangle is collapsed to a line ?}
    rend_prim.vect_2dimi^ (x2, y2);
    return;
    end;

  rend_prim.vect_2dimi^ (x1, y2 - 1);  {draw left edge of rectangle}
  rend_set.cpnt_2dimi^ (x1, y2);       {go to start of bottom edge}
  rend_prim.vect_2dimi^ (x2 - 1, y2);  {draw bottom edge}
  rend_set.cpnt_2dimi^ (x2, y2);       {go to start of right edge}
  rend_prim.vect_2dimi^ (x2, y1 + 1);  {draw right edge}
  rend_set.cpnt_2dimi^ (x2, y1);       {go to start of top edge}
  rend_prim.vect_2dimi^ (x1 + 1, y1);  {draw top edge}
  end;
{
********************************************************************************
*
*   Subroutine EVENT_INQUIRE (EVX, EVY)
*
*   Handle event where INQUIRE key was just pressed.  The event occurred at the
*   window coordinate EVX,EVY.
}
procedure event_inquire (              {handle ENQUIRE key event}
  in      evx, evy: sys_int_machine_t); {window coordinate of the enquire event}
  val_param;

const
  max_msg_parms = 8;                   {max parameters we can pass to a message}

var
  inqx, inqy: sys_int_machine_t;       {pixel that is always within inquire rect}
  rect: inqrect_t;                     {current inquire rectangle}
  acc_red, acc_grn, acc_blu, acc_alpha: {average color value accumulators}
    sys_int_conv32_t;
  av_red, av_grn, av_blu, av_alpha:    {average 0.0 to 1.0 color values}
    real;
  av_ir, av_ig, av_ib, av_ia:          {average 0-255 color values}
    real;
  n: sys_int_conv24_t;                 {number of pixels in inquire rectangle}
  ix, iy: sys_int_machine_t;           {scratch pixel coordinate}
  dx, dy: sys_int_machine_t;           {size of inquire rectangle}
  event: rend_event_t;                 {one graphics event}
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

label
  wait, event_unexpected;

begin
  xform_wind_image (                   {find image pixel where event was}
    evx, evy,                          {input window coordinate}
    inqx, inqy);                       {output image coordinate}
  rect.xmin := inqx;                   {init rectangle to original pixel}
  rect.xmax := inqx;
  rect.ymin := inqy;
  rect.ymax := inqy;
  clip_rect (rect);                    {clip rectangle to image and window}
  inqx := rect.xmin;                   {save clipped inquire starting point}
  inqy := rect.ymin;
  rend_set.enter_level^ (1);           {enter graphics mode}
  drag_on;                             {set up state for dragging with pointer}
  drag_draw;                           {set of for drawing dragged object}
  draw_inqrect (rect);                 {show the inquire rectangle}

wait:                                  {back here to wait for new event}
  rend_set.enter_level^ (0);           {leave graphics mode before event wait}
  rend_event_get (event);              {get the next event}
  case event.ev_type of                {what kind of event is this ?}

rend_ev_key_k: begin                   {user hit or released a key}
      if event.key.key_p^.id_user <> key_inquire_k {this is not our key ?}
        then goto event_unexpected;
      end;                             {end of key event in pan operation}

rend_ev_pnt_move_k: begin              {the pointer was moved}
      xform_wind_image (               {find image pixel where pointer is now}
        event.pnt_move.x, event.pnt_move.y, {input window coordinate}
        ix, iy);                       {output image coordinate}
      rend_set.enter_rend^;            {enter graphics mode}
      drag_undraw;                     {set up for undrawing dragged object}
      draw_inqrect (rect);             {undraw old inquire rectangle}
      drag_draw;                       {set up for drawing dragged object}
      rect.xmin := min(inqx, ix);      {make new inquire rectangle}
      rect.xmax := max(inqx, ix);
      rect.ymin := min(inqy, iy);
      rect.ymax := max(inqy, iy);
      clip_rect (rect);                {clip new rectangle to image and window}
      draw_inqrect (rect);             {draw new inquire rectangle}
      goto wait;                       {back and wait for more events within PAN}
      end;

otherwise
event_unexpected:                      {jump here if got unexpected event}
    rend_event_push (event);           {put the event back}
    end;                               {end of event cases within pan operation}
{
*   The final inquire rectangle is all set.  Now undraw it and actually do the
*   inquire.
}
  rend_set.enter_rend^;                {enter graphics mode}
  drag_undraw;                         {set up for undrawing rectangle}
  draw_inqrect (rect);                 {undraw the inquire rectangle}
  drag_off;                            {all done dragging}
  rend_set.exit_rend^;                 {don't need to draw anything more}

  acc_red := 0;                        {init average value accumulators}
  acc_grn := 0;
  acc_blu := 0;
  acc_alpha := 0;

  if img.next_y <> 0 then begin        {image file not at start of image ?}
    img_rewind (img, stat);            {rewind image file to first scan line}
    rend_error_abort (stat, 'img', 'rewind', nil, 0);
    end;

  while img.next_y <= rect.ymax do begin {still above or within the rectangle ?}
    img_read_scan1 (img, scan_img_p^, stat); {read this scan line from image file}
    rend_error_abort (stat, 'img', 'read_scan_line', nil, 0);
    if img.next_y <= rect.ymin         {still above the inquire rectangle ?}
      then next;
    for ix := rect.xmin to rect.xmax do begin {once for each inq pixel this scan}
      with scan_img_p^[ix]: p do begin {P is this input scan line pixel}
        acc_red := acc_red + p.red;    {accumulate values for this pixel}
        acc_grn := acc_grn + p.grn;
        acc_blu := acc_blu + p.blu;
        acc_alpha := acc_alpha + p.alpha;
        end;                           {done with P abbreviation}
      end;                             {back and do next pixel accross within rect}
    end;                               {back and do next scan line down}

  dx := rect.xmax - rect.xmin + 1;     {make size of inquire rectangle}
  dy := rect.ymax - rect.ymin + 1;
  n := dx * dy;                        {number of pixels in rectangle}

  av_ir := acc_red / n;                {make average 0 to 255 color values}
  av_ig := acc_grn / n;
  av_ib := acc_blu / n;
  av_ia := acc_alpha / n;

  av_red := av_ir / 255.0;             {make average 0.0 to 1.0 color values}
  av_grn := av_ig / 255.0;
  av_blu := av_ib / 255.0;
  av_alpha := av_ia / 255.0;

  writeln;                             {leave blank line before writing values}
  if n = 1
    then begin                         {inquire area is just one pixel}
      sys_msg_parm_int (msg_parm[1], rect.xmin);
      sys_msg_parm_int (msg_parm[2], rect.ymin);
      sys_message_parms ('rend', 'image_disp_pix_coor', msg_parm, 2);
      end
    else begin                         {inquire area is a real rectangle}
      sys_msg_parm_int (msg_parm[1], dx);
      sys_msg_parm_int (msg_parm[2], dy);
      sys_msg_parm_int (msg_parm[3], rect.xmin);
      sys_msg_parm_int (msg_parm[4], rect.ymin);
      sys_msg_parm_int (msg_parm[5], rect.xmax);
      sys_msg_parm_int (msg_parm[6], rect.ymax);
      sys_message_parms ('rend', 'image_disp_rect_coor', msg_parm, 6);
      end
    ;

  sys_msg_parm_real (msg_parm[1], av_red);
  sys_msg_parm_real (msg_parm[2], av_grn);
  sys_msg_parm_real (msg_parm[3], av_blu);
  sys_msg_parm_real (msg_parm[4], av_alpha);
  sys_msg_parm_real (msg_parm[5], av_ir);
  sys_msg_parm_real (msg_parm[6], av_ig);
  sys_msg_parm_real (msg_parm[7], av_ib);
  sys_msg_parm_real (msg_parm[8], av_ia);
  sys_message_parms ('rend', 'image_disp_values', msg_parm, 8);
  end;
