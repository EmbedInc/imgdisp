{   Routines related to drawing.
}
module idisp_draw;
define draw_setup;
define draw_resize;
define draw_image;
%include 'idisp.ins.pas';
{
********************************************************************************
*
*   Subroutine DRAW_SETUP
*
*   Do the one-time setup of RENDlib for our drawing.
}
procedure draw_setup;                  {one-time drawing setup, into graphics mode}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  rend_start;                          {init RENDlib}
  rend_open (                          {open our graphics device}
    dev_name,                          {name of RENDlib device to use}
    rend_dev,                          {returned RENDlib device ID}
    stat);                             {error status}
  sys_error_abort (stat, 'rend', 'rend_open', nil, 0);
  rend_set.enter_rend^;                {get into graphics mode}

  rend_set.alloc_bitmap_handle^ (      {create handle to bitmap of RGB values}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    image_bitmap);                     {returned bitmap handle}
  bitmap_alloc := false;               {no bitmap pixels have been allocated}

  rend_get.clip_2dim_handle^ (clip_handle); {create handle to a 2DIM clip window}

  rend_set.iterp_on^ (rend_iterp_red_k, true); {turn on RGB interpolants}
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_on^ (rend_iterp_red_k, true); {enable for SPAN primitive}
  rend_set.iterp_span_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_span_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_ofs^ (           {set offsets of components within pixel}
    rend_iterp_red_k, offset(img_pixel1_t.red));
  rend_set.iterp_span_ofs^ (
    rend_iterp_grn_k, offset(img_pixel1_t.grn));
  rend_set.iterp_span_ofs^ (
    rend_iterp_blu_k, offset(img_pixel1_t.blu));
  rend_set.span_config^ (sizeof(img_pixel1_t)); {offset for one pixel to the right}
  end;
{
********************************************************************************
*
*   Subroutine DRAW_RESIZE
*
*   Update our internal state to the RENDlib device dimensions.
}
procedure draw_resize;                 {update to RENDlib drawing device size}
  val_param;

begin
  rend_set.enter_rend^;                {get into graphics mode}
  rend_get.image_size^ (               {find out what size window we have}
    dev_dx, dev_dy, dev_aspect);

  if bitmap_alloc then begin           {bitmap and other state previously allocated ?}
    rend_set.dealloc_bitmap^ (image_bitmap); {deallocate old pixel memory}
    rend_mem_dealloc (scan_dev_p, rend_scope_dev_k); {dealloc old scan line buffer}
    end;

  rend_mem_alloc (                     {alloc mem for one RENDlib scan line}
    dev_dx * sizeof(img_pixel1_t),     {amount of memory to allocate}
    rend_scope_dev_k,                  {memory belongs to the RENDlib device}
    true,                              {we will need to individually deallcate this}
    scan_dev_p);                       {returned pointer to the new memory}
  rend_set.alloc_bitmap^ (             {allocate the RGB pixels for this image}
    image_bitmap,                      {handle to this bitmap}
    dev_dx, dev_dy,                    {size of image in pixels}
    3,                                 {number of bytes to allocate for each pixel}
    rend_scope_dev_k);                 {bitmap belongs to RENDlib device}
  bitmap_alloc := true;                {a bitmap is currently allocated}

  rend_set.iterp_bitmap^ (             {connect bitmap to red interpolant}
    rend_iterp_red_k,                  {interpolant ID to connect bitmap to}
    image_bitmap,                      {handle to the bitmap}
    0);                                {byte index into pixel for this interpolant}
  rend_set.iterp_bitmap^ (             {connect bitmap to green interpolant}
    rend_iterp_grn_k,
    image_bitmap,
    1);
  rend_set.iterp_bitmap^ (             {connect bitmap to blue interpolant}
    rend_iterp_blu_k,
    image_bitmap,
    2);

  rend_set.update_mode^ (rend_updmode_buffall_k); {may buffer pixel writes}

  rend_set.clip_2dim^ (                {init clip window to whole device}
    clip_handle,                       {handle to the clip window}
    0, dev_dx,                         {X coordinate limits}
    0, dev_dy,                         {Y coordinate limits}
    true);                             {draw inside, clip outside}

  rend_set.exit_rend^;

  xform_make;                          {update transforms to new draw area size}
  end;
{
********************************************************************************
*
*   Subroutine DRAW_IMAGE (STX, STY, SZX, SZY)
*
*   Draw a rectangle of the currently loaded image onto the drawing device.  The
*   top left pixel of the rectangle is at STX,STY and the size of the drawing
*   region is SZX,SZY.  All call parameters are in the drawing device pixel
*   coordinate space.
*
*   It is allowed to specify pixels outside the drawing device area, although
*   these will not be drawn.  Nothing is done if no drawable pixels result from
*   the call arguments.
*
*   The top left pixel of the drawing device is 0,0, with positive X extending
*   to the right, and positive Y down.
}
procedure draw_image (                 {draw rectangle onto drawing device}
  in      stx, sty: sys_int_machine_t; {top left pixel to draw, drawing device coor}
  in      szx, szy: sys_int_machine_t); {pixel width and height of rectangle}
  val_param;

var
  lft, rit, top, bot: sys_int_machine_t; {draw region clipped to draw device}
  dx, dy: sys_int_machine_t;           {size of clipped draw region}
  ix, iy: sys_int_machine_t;           {drawing device pixel coordinate}
  x, y: real;                          {floating point pixel coordinate}

begin
  lft := max(0, stx);                  {make actual draw region bounds}
  rit := min(dev_dx - 1, stx + szx - 1);
  top := max(0, sty);
  bot := min(dev_dy - 1, sty + szy - 1);
  dx := rit - lft + 1;                 {make resulting draw region size}
  dy := bot - top + 1;
  if (dx <= 0) or (dy <= 0) then return; {nothing left to draw ?}
{
*   LFT, RIT, TOP, and BOT are the limits of the region to draw, and DX and DY
*   its size.  This region is guaranteed to be wholly on the drawing device, and
*   there is at least 1 pixel to draw.
}
  rend_set.enter_rend^;                {into graphics mode}

  rend_set.clip_2dim^ (                {set the clip window to this draw area}
    clip_handle,                       {handle to the clip window}
    lft, rit + 1.0,                    {left/right edges of clip window}
    top, bot + 1.0,                    {top/bottom edges of clip window}
    true);                             {draw inside, clip outside}

  rend_set.min_bits_vis^ (24.0);       {try for full color resolution}
  rend_set.cpnt_2dimi^ (lft, top);     {set top left corner of spans rectangle}
  rend_prim.rect_px_2dimcl^ (dx, dy);  {set size of spans rectangle}

  for iy := top to bot do begin        {down the drawing area scan lines}
    for ix := lft to rit do begin      {across this scan line}
      xform_dpix_ipix (                {find image coordinate}
        ix + 0.5, iy + 0.5,            {input center of this drawing pixel}
        x, y);                         {returned corresponding image coordinate}
      discard( image_sample (          {get the image value here}
        x, y,                          {point to sample the image at}
        scan_dev_p^[ix]) );            {returned image value}
      end;                             {back to get next pixel across}
    rend_prim.span_2dimcl^ (           {write this scan to the device}
      dx,                              {number of pixels in this span}
      scan_dev_p^[lft]);               {first source pixel of span}
    end;                               {back to do next scan line}

  ovl_draw;                            {draw the overlay graphics}

  rend_set.exit_rend^;                 {back out of graphics mode}
  end;
